package com.josh.security.josh_security

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "josh_security/phone_calls"
        private const val REQUEST_CODE_SET_DEFAULT_CALL_SCREENING = 1002
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestCallScreeningRole" -> {
                    requestCallScreeningRole(result)
                }
                "isCallScreeningActive", "isCallScreeningRoleHeld" -> {
                    result.success(isCallScreeningRoleHeld())
                }
                "getNativeCallHistory" -> {
                    try {
                        val repository = JoshCallRepository(applicationContext)
                        val calls = repository.getAllCalls()

                        Log.d("JOSH_DB", "getNativeCallHistory() -> Registros devueltos: ${calls.size}")
                        result.success(calls)
                    } catch (e: Exception) {
                        Log.e("JOSH_DB", "Error en getNativeCallHistory: ${e.message}", e)
                        result.error(
                            "SQLITE_ERROR",
                            "Error consultando DB nativa: ${e.message ?: "excepción sin mensaje"}",
                            e.stackTraceToString()
                        )
                    }
                }
                "clearNativeCallHistory" -> {
                    try {
                        val repository = JoshCallRepository(applicationContext)
                        val deletedRows = repository.clearAllCalls()

                        Log.d("JOSH_DB", "clearNativeCallHistory() -> Registros eliminados: $deletedRows")
                        result.success(deletedRows)
                    } catch (e: Exception) {
                        Log.e("JOSH_DB", "Error en clearNativeCallHistory: ${e.message}", e)
                        result.error(
                            "SQLITE_ERROR",
                            "Error limpiando DB nativa: ${e.message ?: "excepción sin mensaje"}",
                            e.stackTraceToString()
                        )
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun requestCallScreeningRole(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            val isHeld = roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)

            if (isHeld) {
                result.success(true)
            } else {
                pendingResult = result
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                startActivityForResult(intent, REQUEST_CODE_SET_DEFAULT_CALL_SCREENING)
            }
        } else {
            result.success(true)
        }
    }

    private fun isCallScreeningRoleHeld(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        } else {
            true
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_SET_DEFAULT_CALL_SCREENING) {
            val isHeld = isCallScreeningRoleHeld()
            pendingResult?.success(isHeld)
            pendingResult = null
        }
    }
}
