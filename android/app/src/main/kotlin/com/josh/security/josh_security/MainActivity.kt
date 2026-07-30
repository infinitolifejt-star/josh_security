package com.josh.security.josh_security

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity: FlutterActivity() {
    private val APK_CHANNEL = "josh_security/apk_centinel"
    private val CALL_CHANNEL = "josh_security/phone_interceptor"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Canal Centinela APK
        val apkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL)
        ApkInstallReceiver.methodChannel = apkChannel

        apkChannel.setMethodCallHandler { call, result ->
            if (call.method == "getPendingApks") {
                val pendingList = checkAndFlushPendingApks(applicationContext)
                result.success(pendingList)
            } else {
                result.notImplemented()
            }
        }

        // Canal Interceptor de Llamadas
        val callChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
        PhoneCallReceiver.methodChannel = callChannel
    }

    // Procesa y limpia la cola de APKs detectadas mientras la app estaba cerrada
    private fun checkAndFlushPendingApks(context: Context): List<Map<String, String>> {
        val prefs = context.getSharedPreferences("josh_security_pending_apks", Context.MODE_PRIVATE)
        val jsonStr = prefs.getString("pending_apks_json", "[]") ?: "[]"
        
        val resultList = mutableListOf<Map<String, String>>()
        
        try {
            val jsonArray = JSONArray(jsonStr)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                val map = mapOf(
                    "packageName" to obj.optString("packageName"),
                    "appName" to obj.optString("appName"),
                    "apkPath" to obj.optString("apkPath")
                )
                resultList.add(map)
            }
            // Limpiar la lista guardada tras recuperarla
            prefs.edit().remove("pending_apks_json").apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return resultList
    }
}