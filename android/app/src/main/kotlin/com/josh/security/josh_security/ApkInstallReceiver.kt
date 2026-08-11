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

        private const val TAG = "ApkInstallReceiver"

        private const val PREFS_NAME =
            "josh_security_pending_apks"

        private const val KEY_PENDING_LIST =
            "pending_apks_json"

        /**
         * Guarda un evento de instalación para procesarlo
         * posteriormente cuando Flutter vuelva a estar disponible.
         */
        fun savePendingApk(
            context: Context,
            payload: Map<String, String>
        ) {

            try {

                val prefs = context.getSharedPreferences(
                    PREFS_NAME,
                    Context.MODE_PRIVATE
                )

                val currentJson = prefs.getString(
                    KEY_PENDING_LIST,
                    "[]"
                ) ?: "[]"

                val jsonArray = try {
                    JSONArray(currentJson)
                } catch (e: Exception) {

                    Log.w(
                        TAG,
                        "JSON de eventos APK corrupto. Reiniciando cola.",
                        e
                    )

                    JSONArray()
                }

                val jsonObject = JSONObject()

                payload.forEach { (key, value) ->
                    jsonObject.put(key, value)
                }

                jsonArray.put(jsonObject)

                prefs.edit()
                    .putString(
                        KEY_PENDING_LIST,
                        jsonArray.toString()
                    )
                    .apply()

                Log.d(
                    TAG,
                    "💾 APK guardada en cola local: ${payload["appName"]}"
                )

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "❌ No fue posible guardar APK pendiente.",
                    e
                )
            }
        }
    }

    override fun onReceive(
        context: Context,
        intent: Intent
    ) {

        val action = intent.action

        // Solo nos interesan instalaciones y actualizaciones.
        if (
            action != Intent.ACTION_PACKAGE_ADDED &&
            action != Intent.ACTION_PACKAGE_REPLACED
        ) {
            return
        }

        val packageName = intent.data
            ?.schemeSpecificPart
            ?.trim()

        if (packageName.isNullOrEmpty()) {
            Log.w(
                TAG,
                "⚠️ Evento APK recibido sin packageName."
            )
            return
        }

        // Evitar registrar la propia aplicación.
        if (packageName == context.packageName) {
            Log.d(
                TAG,
                "ℹ️ Ignorando actualización/instalación de JOSH Security."
            )
            return
        }

        Log.d(
            TAG,
            "🚨 CENTINELA: evento de paquete detectado -> $packageName"
        )

        try {

            val packageManager = context.packageManager

            val applicationInfo =
                packageManager.getApplicationInfo(
                    packageName,
                    0
                )

            val appName =
                packageManager
                    .getApplicationLabel(applicationInfo)
                    .toString()
                    .trim()

            val apkPath =
                applicationInfo.sourceDir
                    ?.trim()
                    .orEmpty()

            val payload = mapOf(
                "packageName" to packageName,
                "appName" to appName,
                "apkPath" to apkPath
            )

            Log.d(
                TAG,
                "📦 Aplicación: $appName"
            )

            Log.d(
                TAG,
                "📍 APK: $apkPath"
            )

            dispatchOrQueue(
                context,
                payload
            )

        } catch (e: PackageManager.NameNotFoundException) {

            Log.e(
                TAG,
                "❌ No se encontró metadata para $packageName",
                e
            )

        } catch (e: SecurityException) {

            Log.e(
                TAG,
                "❌ Android bloqueó el acceso a metadata de $packageName",
                e
            )

        } catch (e: Exception) {

            Log.e(
                TAG,
                "❌ Error procesando instalación de $packageName",
                e
            )
        }
    }

    /**
     * Intenta entregar el evento directamente a Flutter.
     *
     * Si Flutter no tiene un MethodChannel disponible,
     * el evento se almacena localmente para recuperarlo después.
     */
    private fun dispatchOrQueue(
        context: Context,
        payload: Map<String, String>
    ) {

        val channel = methodChannel

        if (channel == null) {

            Log.d(
                TAG,
                "📥 Flutter no disponible. Guardando APK en cola."
            )

            savePendingApk(
                context,
                payload
            )

            return
        }

        try {

            Handler(Looper.getMainLooper()).post {

                try {

                    methodChannel?.invokeMethod(
                        "onApkInstalled",
                        payload,
                        object : MethodChannel.Result {

                            override fun success(result: Any?) {
                                Log.d(
                                    TAG,
                                    "✅ Evento APK enviado a Flutter."
                                )
                            }

                            override fun error(
                                errorCode: String,
                                errorMessage: String?,
                                errorDetails: Any?
                            ) {

                                Log.w(
                                    TAG,
                                    "⚠️ Flutter rechazó evento APK. Guardando.",
                                )

                                savePendingApk(
                                    context,
                                    payload
                                )
                            }

                            override fun notImplemented() {

                                Log.w(
                                    TAG,
                                    "⚠️ Flutter no implementó onApkInstalled. Guardando."
                                )

                                savePendingApk(
                                    context,
                                    payload
                                )
                            }
                        }
                    )

                } catch (e: Exception) {

                    Log.e(
                        TAG,
                        "❌ Error enviando APK a Flutter. Guardando.",
                        e
                    )

                    savePendingApk(
                        context,
                        payload
                    )
                }
            }

        } catch (e: Exception) {

            Log.e(
                TAG,
                "❌ Error programando entrega a Flutter.",
                e
            )

            savePendingApk(
                context,
                payload
            )
        }
    }
}
