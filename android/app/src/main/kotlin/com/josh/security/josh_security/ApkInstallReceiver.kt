package com.josh.security.josh_security

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class ApkInstallReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ApkInstallReceiver"
        private const val PREFS_NAME = "josh_security_pending_apks"
        private const val KEY_PENDING_LIST = "pending_apks_json"

        var methodChannel: MethodChannel? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_PACKAGE_ADDED && action != Intent.ACTION_PACKAGE_REPLACED) {
            return
        }

        val data = intent.data ?: return
        val packageName = data.schemeSpecificPart ?: return

        // Omitir si la app instalada es la propia aplicación
        if (packageName == context.packageName) {
            return
        }

        Log.d(TAG, "Evento de instalación detectado para el paquete: $packageName")

        val appName = getAppName(context, packageName)
        val apkData = mapOf(
            "packageName" to packageName,
            "appName" to appName,
            "apkPath" to ""
        )

        val channel = methodChannel
        if (channel != null) {
            try {
                channel.invokeMethod("onApkInstalled", apkData)
                Log.d(TAG, "Notificación enviada a Flutter mediante MethodChannel.")
            } catch (e: Exception) {
                Log.e(TAG, "Error al invocar canal con Flutter: ${e.message}")
                savePendingApk(context, apkData)
            }
        } else {
            Log.d(TAG, "Engine no disponible. Almacenando APK pendiente en SharedPreferences.")
            savePendingApk(context, apkData)
        }
    }

    private fun getAppName(context: Context, packageName: String): String {
        return try {
            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    private fun savePendingApk(context: Context, apkData: Map<String, String>) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val jsonString = prefs.getString(KEY_PENDING_LIST, "[]") ?: "[]"
            val jsonArray = JSONArray(jsonString)

            val jsonObject = JSONObject().apply {
                put("packageName", apkData["packageName"])
                put("appName", apkData["appName"])
                put("apkPath", apkData["apkPath"])
            }

            jsonArray.put(jsonObject)
            prefs.edit().putString(KEY_PENDING_LIST, jsonArray.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error guardando APK pendiente: ${e.message}")
        }
    }
}
