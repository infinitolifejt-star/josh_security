package com.josh.security.josh_security

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
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
            val number = intent.extras?.getString(TelephonyManager.EXTRA_INCOMING_NUMBER)

            var state = TelephonyManager.CALL_STATE_IDLE
            if (stateStr == TelephonyManager.EXTRA_STATE_RINGING) {
                state = TelephonyManager.CALL_STATE_RINGING
            } else if (stateStr == TelephonyManager.EXTRA_STATE_OFFHOOK) {
                state = TelephonyManager.CALL_STATE_OFFHOOK
            }

            onCustomCallStateChanged(context, state, number)
        }
    }

    private fun onCustomCallStateChanged(context: Context, state: Int, number: String?) {
        if (lastState == state) return

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                isIncoming = true
                savedNumber = number
                
                if (!number.isNullOrEmpty()) {
                    Log.d("PhoneCallReceiver", "🚨 LLAMADA ENTRANTE REAL: $number")
                    notifyFlutterCallIntercepted(number)
                } else {
                    Log.w("PhoneCallReceiver", "⚠️ Número nulo en tiempo real por restricciones de Android. Verifica permisos READ_CALL_LOG/READ_PHONE_NUMBERS.")
                }
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (isIncoming) {
                    Log.d("PhoneCallReceiver", "📞 LLAMADA CONTESTADA: ${savedNumber ?: "Número Desconocido"}")
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