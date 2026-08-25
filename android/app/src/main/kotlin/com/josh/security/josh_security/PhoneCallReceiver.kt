package com.josh.security.josh_security

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class PhoneCallReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PhoneCallReceiver"
        private const val PREFS_NAME = "josh_security_phone_calls"
        private const val KEY_PENDING_NUMBER = "pending_number"
        private const val KEY_PENDING_TIMESTAMP = "pending_timestamp"
        private const val KEY_PENDING_ACTIVE = "pending_active"
        private const val DUPLICATE_WINDOW_MS = 3000L

        @Volatile private var flutterMethodChannel: MethodChannel? = null
        @Volatile private var lastScreenedNumber: String? = null
        @Volatile private var lastScreenedTimestamp: Long = 0L

        fun setMethodChannel(channel: MethodChannel?) {
            flutterMethodChannel = channel
            Log.d(TAG, "MethodChannel actualizado: ${channel != null}")
        }

        fun getPendingCall(context: Context): Map<String, Any?>? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(KEY_PENDING_ACTIVE, false)) return null
            return mapOf(
                "phoneNumber" to (prefs.getString(KEY_PENDING_NUMBER, null) ?: "Número Oculto"),
                "timestamp" to prefs.getLong(KEY_PENDING_TIMESTAMP, 0L)
            )
        }

        fun clearPendingCall(context: Context) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().clear().apply()
            Log.d(TAG, "Llamada pendiente eliminada.")
        }

        fun handleScreenedIncomingCall(context: Context, phoneNumber: String?) {
            val normalizedNumber = normalizePhoneNumber(phoneNumber)
            val timestamp = System.currentTimeMillis()

            if (normalizedNumber != null && normalizedNumber == lastScreenedNumber &&
                timestamp - lastScreenedTimestamp < DUPLICATE_WINDOW_MS) {
                Log.d(TAG, "Llamada duplicada ignorada: $normalizedNumber")
                return
            }

            lastScreenedNumber = normalizedNumber
            lastScreenedTimestamp = timestamp
            val displayNumber = normalizedNumber ?: "Número Oculto"

            Log.d(TAG, "LLAMADA ENTRANTE CAPTURADA -> Número: $displayNumber")

            savePendingCall(context, displayNumber, timestamp)
            notifyFlutterIncomingCall(displayNumber, timestamp)
        }

        private fun normalizePhoneNumber(phoneNumber: String?): String? {
            if (phoneNumber.isNullOrBlank()) return null
            val clean = phoneNumber.trim().lowercase()
            val invalidList = setOf("unknown", "desconocido", "private", "privado", "restricted", "restringido", "null", "número oculto", "numero oculto")
            if (clean in invalidList) return null
            val digits = clean.filter { it.isDigit() }
            return if (digits.length < 7) null else phoneNumber.trim()
        }

        private fun savePendingCall(context: Context, phoneNumber: String, timestamp: Long) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
                .putBoolean(KEY_PENDING_ACTIVE, true)
                .putString(KEY_PENDING_NUMBER, phoneNumber)
                .putLong(KEY_PENDING_TIMESTAMP, timestamp)
                .apply()
        }

        private fun notifyFlutterIncomingCall(phoneNumber: String, timestamp: Long) {
            val channel = flutterMethodChannel ?: return
            val payload = mapOf("phoneNumber" to phoneNumber, "timestamp" to timestamp)
            Handler(Looper.getMainLooper()).post {
                runCatching {
                    channel.invokeMethod("onIncomingCall", payload)
                    Log.d(TAG, "Evento onIncomingCall enviado a Flutter.")
                }.onFailure { Log.e(TAG, "Error enviando llamada a Flutter", it) }
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            if (state == TelephonyManager.EXTRA_STATE_RINGING) {
                val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
                handleScreenedIncomingCall(context, incomingNumber)
            }
        }
    }
}
