package com.josh.security.josh_security

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.provider.CallLog
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.util.Date

class PhoneCallReceiver : BroadcastReceiver() {

    companion object {
        var methodChannel: MethodChannel? = null
        private var lastState = TelephonyManager.CALL_STATE_IDLE
        private var isIncoming = false
        private var savedNumber: String? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "android.intent.action.PHONE_STATE") {
            val stateStr = intent.extras?.getString(TelephonyManager.EXTRA_STATE)
            var rawNumber = intent.extras?.getString(TelephonyManager.EXTRA_INCOMING_NUMBER)

            var state = TelephonyManager.CALL_STATE_IDLE
            if (stateStr == TelephonyManager.EXTRA_STATE_RINGING) {
                state = TelephonyManager.CALL_STATE_RINGING
            } else if (stateStr == TelephonyManager.EXTRA_STATE_OFFHOOK) {
                state = TelephonyManager.CALL_STATE_OFFHOOK
            }

            // Si el intent no trae el número, realizamos una lectura asistida desde el CallLog
            if (rawNumber.isNullOrEmpty()) {
                rawNumber = getLastIncomingNumber(context)
            }

            onCustomCallStateChanged(context, state, rawNumber)
        }
    }

    private fun onCustomCallStateChanged(context: Context, state: Int, number: String?) {
        if (lastState == state) return

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                isIncoming = true
                
                // Intento secundario con delay si la llamada entró hace microsegundos
                val finalNumber = if (!number.isNullOrEmpty()) {
                    number
                } else {
                    getLastIncomingNumber(context)
                }

                savedNumber = finalNumber

                if (!finalNumber.isNullOrEmpty()) {
                    Log.d("PhoneCallReceiver", "🚨 LLAMADA ENTRANTE CAPTURADA REAL: $finalNumber")
                    notifyFlutterCallIntercepted(finalNumber)
                } else {
                    Log.w("PhoneCallReceiver", "⚠️ No se pudo obtener el número entrante ni desde extras ni desde CallLog.")
                    // Notificar con fallback para depuración o número desconocido real
                    notifyFlutterCallIntercepted("Desconocido / Oculto")
                }
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (isIncoming) {
                    Log.d("PhoneCallReceiver", "📞 LLAMADA CONTESTADA: ${savedNumber ?: "Desconocido"}")
                }
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                if (isIncoming) {
                    Log.d("PhoneCallReceiver", "🔕 LLAMADA FINALIZADA O RECHAZADA")
                    isIncoming = false
                    savedNumber = null
                }
            }
        }
        lastState = state
    }

    // Método asistido para consultar el número real entrante directamente al sistema
    private fun getLastIncomingNumber(context: Context): String? {
        var incomingNumber: String? = null
        try {
            val cursor: Cursor? = context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DATE),
                null,
                null,
                "${CallLog.Calls.DATE} DESC"
            )

            cursor?.use {
                if (it.moveToFirst()) {
                    val numberIndex = it.getColumnIndex(CallLog.Calls.NUMBER)
                    if (numberIndex != -1) {
                        incomingNumber = it.getString(numberIndex)
                    }
                }
            }
        } catch (e: SecurityException) {
            Log.e("PhoneCallReceiver", "Permiso denegado al leer CallLog: ${e.message}")
        } catch (e: Exception) {
            Log.e("PhoneCallReceiver", "Error consultando CallLog: ${e.message}")
        }
        return incomingNumber
    }

    private fun notifyFlutterCallIntercepted(phoneNumber: String) {
        methodChannel?.let { channel ->
            val payload = mapOf(
                "phoneNumber" to phoneNumber,
                "timestamp" to Date().time
            )
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                channel.invokeMethod("onCallIntercepted", payload)
            }
        }
    }
}