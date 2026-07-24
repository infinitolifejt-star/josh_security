package com.josh.security.josh_security

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class ApkInstallReceiver : BroadcastReceiver() {

    companion object {
        var methodChannel: MethodChannel? = null
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

                // Enviar la metadata a Flutter para escaneo y persistencia
                val payload = mapOf(
                    "packageName" to packageName,
                    "appName" to appName,
                    "apkPath" to apkPath
                )

                Handler(Looper.getMainLooper()).post {
                    methodChannel?.invokeMethod("onApkInstalled", payload)
                }

            } catch (e: PackageManager.NameNotFoundException) {
                Log.e("ApkInstallReceiver", "Error al obtener metadata del paquete: ${e.message}")
            }
        }
    }
}