package com.josh.security.josh_security

import android.Manifest
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

        private const val APK_CHANNEL =
            "josh_security/apk_centinel"

        private const val PHONE_CHANNEL =
            "josh_security/phone_calls"

        private const val PREFS_NAME =
            "josh_security_pending_apks"

        private const val KEY_PENDING_LIST =
            "pending_apks_json"

        private const val REQUEST_PHONE_PERMISSIONS =
            4100

        private const val REQUEST_CALL_LOG =
            4101
    }

    private var apkChannel: MethodChannel? = null

    private var phoneChannel: MethodChannel? = null

    override fun onCreate(
        savedInstanceState: Bundle?
    ) {
        super.onCreate(savedInstanceState)

        requestRequiredPhonePermissions()
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        // ==========================================================================================
        // APK CHANNEL
        // ==========================================================================================

        apkChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                APK_CHANNEL
            )

        ApkInstallReceiver.methodChannel =
            apkChannel

        apkChannel?.setMethodCallHandler { call, result ->

            when (call.method) {

                "getPendingApks" -> {

                    try {

                        val pendingList =
                            checkAndFlushPendingApks(
                                applicationContext
                            )

                        result.success(
                            pendingList
                        )

                    } catch (e: Exception) {

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

        // ==========================================================================================
        // PHONE CHANNEL
        // ==========================================================================================

        phoneChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                PHONE_CHANNEL
            )

        PhoneCallReceiver.setMethodChannel(
            phoneChannel
        )

        phoneChannel?.setMethodCallHandler { call, result ->

            when (call.method) {

                // ----------------------------------------------------------------------------------
                // LLAMADA PENDIENTE
                // ----------------------------------------------------------------------------------

                "getPendingCall" -> {

                    try {

                        val pendingCall =
                            PhoneCallReceiver.getPendingCall(
                                applicationContext
                            )

                        result.success(
                            pendingCall
                        )

                    } catch (e: Exception) {

                        result.error(
                            "PENDING_CALL_ERROR",
                            "No fue posible recuperar la llamada pendiente.",
                            e.message
                        )
                    }
                }

                // ----------------------------------------------------------------------------------
                // LIMPIAR LLAMADA PENDIENTE
                // ----------------------------------------------------------------------------------

                "clearPendingCall" -> {

                    try {

                        PhoneCallReceiver.clearPendingCall(
                            applicationContext
                        )

                        result.success(true)

                    } catch (e: Exception) {

                        result.error(
                            "CLEAR_CALL_ERROR",
                            "No fue posible limpiar la llamada pendiente.",
                            e.message
                        )
                    }
                }

                // ----------------------------------------------------------------------------------
                // PERMISO CALL LOG
                // ----------------------------------------------------------------------------------

                "requestCallLogPermission" -> {

                    requestCallLogPermission()

                    result.success(true)
                }

                "isCallLogPermissionGranted" -> {

                    result.success(
                        isCallLogPermissionGranted()
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ==============================================================================================
    // PERMISOS TELEFÓNICOS
    // ==============================================================================================

    private fun requestRequiredPhonePermissions() {

        val permissions =
            mutableListOf<String>()

        if (
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_PHONE_STATE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            permissions.add(
                Manifest.permission.READ_PHONE_STATE
            )
        }

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_PHONE_NUMBERS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            permissions.add(
                Manifest.permission.READ_PHONE_NUMBERS
            )
        }

        if (permissions.isNotEmpty()) {

            ActivityCompat.requestPermissions(
                this,
                permissions.toTypedArray(),
                REQUEST_PHONE_PERMISSIONS
            )
        }
    }

    // ==============================================================================================
    // READ CALL LOG
    // ==============================================================================================

    private fun requestCallLogPermission() {

        if (
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_CALL_LOG
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.READ_CALL_LOG
            ),
            REQUEST_CALL_LOG
        )
    }

    private fun isCallLogPermissionGranted(): Boolean {

        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_CALL_LOG
        ) == PackageManager.PERMISSION_GRANTED
    }

    // ==============================================================================================
    // APK PENDIENTES
    // ==============================================================================================

    private fun checkAndFlushPendingApks(
        context: android.content.Context
    ): List<Map<String, String>> {

        val prefs =
            context.getSharedPreferences(
                PREFS_NAME,
                android.content.Context.MODE_PRIVATE
            )

        val jsonString =
            prefs.getString(
                KEY_PENDING_LIST,
                "[]"
            ) ?: "[]"

        val resultList =
            mutableListOf<Map<String, String>>()

        try {

            val jsonArray =
                JSONArray(jsonString)

            for (
                i in 0 until jsonArray.length()
            ) {

                val obj =
                    jsonArray.optJSONObject(i)
                        ?: continue

                val packageName =
                    obj.optString(
                        "packageName",
                        ""
                    )

                val appName =
                    obj.optString(
                        "appName",
                        ""
                    )

                val apkPath =
                    obj.optString(
                        "apkPath",
                        ""
                    )

                resultList.add(
                    mapOf(
                        "packageName" to packageName,
                        "appName" to appName,
                        "apkPath" to apkPath
                    )
                )
            }

            prefs.edit()
                .remove(KEY_PENDING_LIST)
                .apply()

        } catch (e: Exception) {

            e.printStackTrace()
        }

        return resultList
    }

    // ==============================================================================================
    // CLEANUP
    // ==============================================================================================

    override fun cleanUpFlutterEngine(
        flutterEngine: FlutterEngine
    ) {

        if (
            ApkInstallReceiver.methodChannel ===
            apkChannel
        ) {
            ApkInstallReceiver.methodChannel = null
        }

        PhoneCallReceiver.setMethodChannel(null)

        apkChannel = null

        phoneChannel = null

        super.cleanUpFlutterEngine(
            flutterEngine
        )
    }
}
