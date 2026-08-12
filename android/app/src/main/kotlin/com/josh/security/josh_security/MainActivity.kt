package com.josh.security.josh_security

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {

    companion object {
        private const val APK_CHANNEL = "josh_security/apk_centinel"
        private const val CALL_CHANNEL = "josh_security/phone_interceptor"
        private const val PREFS_NAME = "josh_security_pending_apks"
        private const val KEY_PENDING_LIST = "pending_apks_json"
    }

    private var apkChannel: MethodChannel? = null
    private var callChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // CANAL CENTINELA APK
        apkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APK_CHANNEL
        )

        ApkInstallReceiver.methodChannel = apkChannel

        apkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingApks" -> {
                    try {
                        val pendingList = checkAndFlushPendingApks(applicationContext)
                        result.success(pendingList)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error(
                            "PENDING_APKS_ERROR",
                            "No fue posible recuperar las APK pendientes.",
                            e.message
                        )
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // CANAL INTERCEPTOR TELEFÓNICO
        callChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_CHANNEL
        )

        PhoneCallReceiver.methodChannel = callChannel
    }

    private fun checkAndFlushPendingApks(context: Context): List<Map<String, String>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val jsonString = prefs.getString(KEY_PENDING_LIST, "[]") ?: "[]"
        val resultList = mutableListOf<Map<String, String>>()

        try {
            val jsonArray = JSONArray(jsonString)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.optJSONObject(i) ?: continue
                val packageName = obj.optString("packageName", "")
                val appName = obj.optString("appName", "")
                val apkPath = obj.optString("apkPath", "")

                resultList.add(
                    mapOf(
                        "packageName" to packageName,
                        "appName" to appName,
                        "apkPath" to apkPath
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
        if (ApkInstallReceiver.methodChannel === apkChannel) {
            ApkInstallReceiver.methodChannel = null
        }
        if (PhoneCallReceiver.methodChannel === callChannel) {
            PhoneCallReceiver.methodChannel = null
        }

        apkChannel = null
        callChannel = null

        super.cleanUpFlutterEngine(flutterEngine)
    }
}
