package com.josh.security.josh_security
import android.Manifest
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
class MainActivity : FlutterActivity() {
    companion object {
        private const val APK_CHANNEL = "josh_security/apk_centinel"
        private const val PHONE_CHANNEL = "josh_security/phone_calls"
        private const val PREFS_NAME = "josh_security_pending_apks"
        private const val KEY_PENDING_LIST = "pending_apks_json"
        private const val REQUEST_PHONE_PERMISSIONS = 4100
        private const val REQUEST_CALL_LOG = 4101
        private const val REQUEST_CALL_SCREENING_ROLE = 4102
    }
    private var apkChannel: MethodChannel? = null
    private var phoneChannel: MethodChannel? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestRequiredPhonePermissions()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        apkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL)
        ApkInstallReceiver.methodChannel = apkChannel
        apkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingApks" -> {
                    try {
                        result.success(checkAndFlushPendingApks(applicationContext))
                    } catch (e: Exception) {
                        result.error("PENDING_APKS_ERROR", "No fue posible recuperar las APK pendientes.", e.message)
                    }
                }
                else -> result.notImplemented()
            }
        }
        phoneChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHONE_CHANNEL)
        PhoneCallReceiver.setMethodChannel(phoneChannel)
        phoneChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingCall" -> {
                    try {
                        result.success(PhoneCallReceiver.getPendingCall(applicationContext))
                    } catch (e: Exception) {
                        result.error("PENDING_CALL_ERROR", "No fue posible recuperar la llamada pendiente.", e.message)
                    }
                }
                "clearPendingCall" -> {
                    try {
                        PhoneCallReceiver.clearPendingCall(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CLEAR_CALL_ERROR", "No fue posible limpiar la llamada pendiente.", e.message)
                    }
                }
                "requestCallLogPermission" -> {
                    requestCallLogPermission()
                    result.success(true)
                }
                "isCallLogPermissionGranted" -> result.success(isCallLogPermissionGranted())
                "isCallScreeningRoleAvailable" -> result.success(isCallScreeningRoleAvailable())
                "isCallScreeningRoleHeld" -> result.success(isCallScreeningRoleHeld())
                "requestCallScreeningRole" -> result.success(requestCallScreeningRole())
                else -> result.notImplemented()
            }
        }
    }
    private fun getRoleManager(): RoleManager? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        return getSystemService(Context.ROLE_SERVICE) as? RoleManager
    }
    private fun isCallScreeningRoleAvailable(): Boolean {
        val roleManager = getRoleManager() ?: return false
        return roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)
    }
    private fun isCallScreeningRoleHeld(): Boolean {
        val roleManager = getRoleManager() ?: return false
        return roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
    }
    private fun requestCallScreeningRole(): Boolean {
        val roleManager = getRoleManager() ?: return false
        if (!roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) return false
        if (roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) return true
        val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
        startActivityForResult(intent, REQUEST_CALL_SCREENING_ROLE)
        return true
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CALL_SCREENING_ROLE) notifyFlutterCallScreeningRoleChanged()
    }
    private fun notifyFlutterCallScreeningRoleChanged() {
        val channel = phoneChannel ?: return
        val payload = mapOf("available" to isCallScreeningRoleAvailable(), "held" to isCallScreeningRoleHeld())
        runOnUiThread {
            try {
                channel.invokeMethod("onCallScreeningRoleChanged", payload)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    private fun requestRequiredPhonePermissions() {
        val permissions = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.READ_PHONE_STATE)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_NUMBERS) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.READ_PHONE_NUMBERS)
        }
        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissions.toTypedArray(), REQUEST_PHONE_PERMISSIONS)
        }
    }
    private fun requestCallLogPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED) return
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_CALL_LOG), REQUEST_CALL_LOG)
    }
    private fun isCallLogPermissionGranted(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
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
        PhoneCallReceiver.setMethodChannel(null)
        apkChannel = null
        phoneChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
