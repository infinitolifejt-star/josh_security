package com.josh.security.josh_security

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class ApkInstallReceiver : BroadcastReceiver() {

    companion object {
        var methodChannel: MethodChannel? = null
        private const val PREFS_NAME = "josh_security_pending_apks"
        private const val KEY_PENDING_LIST = "pending_apks_json"

        // Método auxiliar para guardar eventos cuando la app está cerrada
        fun savePendingApk(context: Context, payload: Map<String, String>) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val currentJsonStr = prefs.getString(KEY_PENDING_LIST, "[]") ?: "[]"
            
            val jsonArray = JSONArray(currentJsonStr)
            val newObject = JSONObject(payload)
            jsonArray.put(newObject)

            prefs.edit().putString(KEY_PENDING_LIST, jsonArray.toString()).apply()
            Log.d("ApkInstallReceiver", "💾 Guardado en SharedPreferences Nativo para revisión posterior: ${payload["appName"]}")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        
        if (Intent.ACTION_PACKAGE_ADDED == action || Intent.ACTION_PACKAGE_REPLACED == action) {
            val packageName = intent.data?.schemeSpecificPart ?: return
            
            // Ignorar la propia app
            if (packageName == context.packageName) return

            Log.d("ApkInstallReceiver", "🚨 CENTINELA: Nueva app/APK detectada -> $packageName")

            try {
                val pm = context.packageManager
                val appInfo = pm.getApplicationInfo(packageName, 0)
                val appName = pm.getApplicationLabel(appInfo).toString()
                val apkPath = appInfo.sourceDir

                Log.d("ApkInstallReceiver", "📦 App: $appName | Ruta APK: $apkPath")

                val payload = mapOf(
                    "packageName" to packageName,
                    "appName" to appName,
                    "apkPath" to apkPath
                )

                if (methodChannel != null) {
                    // La app está abierta o en segundo plano activo
                    Handler(Looper.getMainLooper()).post {
                        methodChannel?.invokeMethod("onApkInstalled", payload)
                    }
                } else {
                    // La app está cerrada (Killed State): Guardamos localmente
                    savePendingApk(context, payload)
                }

            } catch (e: PackageManager.NameNotFoundException) {
                Log.e("ApkInstallReceiver", "Error al obtener metadata del paquete: ${e.message}")
            }
        }
    }
}