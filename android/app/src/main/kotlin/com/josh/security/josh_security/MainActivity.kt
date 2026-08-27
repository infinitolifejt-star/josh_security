package com.josh.security.josh_security

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity: FlutterActivity() {

    companion object {
        private const val APK_CHANNEL = "josh_security/apk_centinel"
        private const val PHONE_CHANNEL = "josh_security/phone_calls"
        private const val REQUEST_CALL_SCREENING_ROLE = 4102
        private const val PREFS_NAME = "josh_security_pending_apks"
        private const val KEY_PENDING_LIST = "pending_apks_json"
    }

    private var apkChannel: MethodChannel? = null
    private var phoneChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal de APK Centinel
        apkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL)
        ApkInstallReceiver.methodChannel = apkChannel
        apkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingApks" -> {
                    try {
                        result.success(checkAndFlushPendingApks(applicationContext))
                    } catch (e: Exception) {
                        result.error("PENDING_APKS_ERROR", "Error al recuperar APKs.", e.message)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Canal unificado de llamadas (Consulta SQLite + Gestión de Rol)
        phoneChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHONE_CHANNEL)
        phoneChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getNativeCallHistory" -> {
                    try {
                        val repository = JoshCallRepository(applicationContext)
                        val calls = repository.getAllCalls()
                        result.success(calls)
                    } catch (e: Exception) {
                        result.error("SQLITE_ERROR", "Error consultando DB nativa: ${e.message}", null)
                    }
                }
                "isCallScreeningRoleAvailable" -> result.success(isCallScreeningRoleAvailable())
                "isCallScreeningRoleHeld" -> result.success(isCallScreeningRoleHeld())
                "requestCallScreeningRole" -> {
                    result.success(requestCallScreeningRole())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isCallScreeningRoleAvailable(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)
        } else false
    }

    private fun isCallScreeningRoleHeld(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        } else false
    }

    private fun requestCallScreeningRole(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) &&
                !roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                startActivityForResult(intent, REQUEST_CALL_SCREENING_ROLE)
                return true
            }
        }
        return false
    }

    private fun checkAndFlushPendingApks(context: Context): List<Map<String, String>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val jsonString = prefs.getString(KEY_PENDING_LIST, "[]") ?: "[]"
        val resultList = mutableListOf<Map<String, String>>()
        try {
            val jsonArray = JSONArray(jsonString)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.optJSONObject(i) ?: continue
                resultList.add(
                    mapOf(
                        "packageName" to obj.optString("packageName", ""),
                        "appName" to obj.optString("appName", ""),
                        "apkPath" to obj.optString("apkPath", "")
                    )
                )
            }
            prefs.edit().remove(KEY_PENDING_LIST).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return resultList
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (ApkInstallReceiver.methodChannel === apkChannel) ApkInstallReceiver.methodChannel = null
        apkChannel = null
        phoneChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
