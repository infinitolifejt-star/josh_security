package com.josh.security.josh_security

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.provider.CallLog
import android.os.Handler
import android.os.Looper
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

class PhoneCallReceiver : BroadcastReceiver() {

    companion object {

        private const val TAG = "PhoneCallReceiver"

        private const val PREFS_NAME =
            "josh_security_phone_calls"

        private const val KEY_PENDING_NUMBER =
            "pending_number"

        private const val KEY_PENDING_TIMESTAMP =
            "pending_timestamp"

        private const val KEY_PENDING_ACTIVE =
            "pending_active"

        @Volatile
        private var flutterMethodChannel: MethodChannel? = null

        private var isIncoming = false

        private var activeNumber: String? = null

        private var ringingStartedAt = 0L

        private var callGeneration = 0L

        // ==========================================================================================
        // PUBLICACIÓN DEL CANAL
        // ==========================================================================================

        fun setMethodChannel(
            channel: MethodChannel?
        ) {
            flutterMethodChannel = channel

            Log.d(
                TAG,
                "MethodChannel actualizado: ${channel != null}"
            )
        }

        // ==========================================================================================
        // EVENTO PENDIENTE
        // ==========================================================================================

        fun getPendingCall(
            context: Context
        ): Map<String, Any?>? {

            val prefs =
                context.getSharedPreferences(
                    PREFS_NAME,
                    Context.MODE_PRIVATE
                )

            val active =
                prefs.getBoolean(
                    KEY_PENDING_ACTIVE,
                    false
                )

            if (!active) {
                return null
            }

            val number =
                prefs.getString(
                    KEY_PENDING_NUMBER,
                    null
                )

            val timestamp =
                prefs.getLong(
                    KEY_PENDING_TIMESTAMP,
                    0L
                )

            return mapOf(
                "phoneNumber" to (
                    number ?: "Número Oculto"
                ),
                "timestamp" to timestamp
            )
        }

        // ==========================================================================================
        // LIMPIAR EVENTO PENDIENTE
        // ==========================================================================================

        fun clearPendingCall(
            context: Context
        ) {

            context
                .getSharedPreferences(
                    PREFS_NAME,
                    Context.MODE_PRIVATE
                )
                .edit()
                .clear()
                .apply()

            Log.d(
                TAG,
                "Evento de llamada pendiente eliminado."
            )
        }
    }

    // ==============================================================================================
    // BROADCAST
    // ==============================================================================================

    override fun onReceive(
        context: Context,
        intent: Intent
    ) {

        if (
            intent.action !=
            TelephonyManager.ACTION_PHONE_STATE_CHANGED
        ) {
            return
        }

        Log.e(
            TAG,
            "=================================================="
        )

        Log.e(
            TAG,
            "PHONE STATE BROADCAST RECIBIDO"
        )

        Log.e(
            TAG,
            "ACTION = ${intent.action}"
        )

        Log.e(
            TAG,
            "=================================================="
        )

        val state =
            intent.getStringExtra(
                TelephonyManager.EXTRA_STATE
            ) ?: return

        when (state) {

            TelephonyManager.EXTRA_STATE_RINGING -> {

                Log.e(
                    TAG,
                    "PHONE STATE = RINGING"
                )

                handleRinging(
                    context.applicationContext,
                    intent
                )
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK -> {

                Log.e(
                    TAG,
                    "PHONE STATE = OFFHOOK"
                )

                handleOffHook()
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {

                Log.e(
                    TAG,
                    "PHONE STATE = IDLE"
                )

                handleIdle(
                    context.applicationContext
                )
            }
        }
    }

    // ==============================================================================================
    // RINGING
    // ==============================================================================================

    private fun handleRinging(
        context: Context,
        intent: Intent
    ) {

        if (!isIncoming) {

            isIncoming = true

            activeNumber = null

            ringingStartedAt =
                System.currentTimeMillis()

            callGeneration++
        }

        val generation =
            callGeneration

        @Suppress("DEPRECATION")
        val directNumber =
            intent.getStringExtra(
                TelephonyManager.EXTRA_INCOMING_NUMBER
            )

        Log.e(
            TAG,
            "Número recibido directamente = $directNumber"
        )

        if (
            isUsablePhoneNumber(
                directNumber
            )
        ) {

            Log.e(
                TAG,
                "Número válido recibido directamente: $directNumber"
            )

            publishIncomingNumber(
                context,
                directNumber!!
            )

            return
        }

        Log.e(
            TAG,
            "No llegó número directamente."
        )

        val immediateNumber =
            getRecentIncomingNumber(
                context
            )

        Log.e(
            TAG,
            "Número obtenido de CallLog = $immediateNumber"
        )

        if (
            isUsablePhoneNumber(
                immediateNumber
            )
        ) {

            publishIncomingNumber(
                context,
                immediateNumber!!
            )

            return
        }

        scheduleCallLogFallback(
            context,
            generation
        )
    }

    // ==============================================================================================
    // OFFHOOK
    // ==============================================================================================

    private fun handleOffHook() {

        if (!isIncoming) {
            return
        }

        Log.e(
            TAG,
            "LLAMADA ENTRANTE EN CURSO: ${
                activeNumber ?: "Número desconocido"
            }"
        )
    }

    // ==============================================================================================
    // IDLE
    // ==============================================================================================

    private fun handleIdle(
        context: Context
    ) {

        if (!isIncoming) {
            return
        }

        Log.e(
            TAG,
            "LLAMADA FINALIZADA / IDLE"
        )

        isIncoming = false

        activeNumber = null

        ringingStartedAt = 0L

        callGeneration++

        notifyFlutterCallEnded()
    }

    // ==============================================================================================
    // FALLBACK CALL LOG
    // ==============================================================================================

    private fun scheduleCallLogFallback(
        context: Context,
        generation: Long
    ) {

        val handler =
            Handler(
                Looper.getMainLooper()
            )

        val delays =
            longArrayOf(
                100L,
                300L,
                700L,
                1200L,
                1800L
            )

        for (delay in delays) {

            handler.postDelayed({

                if (
                    !isIncoming ||
                    generation != callGeneration
                ) {
                    return@postDelayed
                }

                if (
                    isUsablePhoneNumber(
                        activeNumber
                    )
                ) {
                    return@postDelayed
                }

                val number =
                    getRecentIncomingNumber(
                        context
                    )

                if (
                    isUsablePhoneNumber(
                        number
                    )
                ) {

                    Log.e(
                        TAG,
                        "Número recuperado desde CallLog en $delay ms: $number"
                    )

                    publishIncomingNumber(
                        context,
                        number!!
                    )
                }

            }, delay)
        }

        handler.postDelayed({

            if (
                !isIncoming ||
                generation != callGeneration
            ) {
                return@postDelayed
            }

            if (
                isUsablePhoneNumber(
                    activeNumber
                )
            ) {
                return@postDelayed
            }

            Log.e(
                TAG,
                "No fue posible obtener el número."
            )

            publishIncomingNumber(
                context,
                "Número Oculto"
            )

        }, 2200L)
    }

    // ==============================================================================================
    // CALL LOG
    // ==============================================================================================

    private fun getRecentIncomingNumber(
        context: Context
    ): String? {

        if (
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_CALL_LOG
            ) != PackageManager.PERMISSION_GRANTED
        ) {

            Log.e(
                TAG,
                "READ_CALL_LOG NO concedido."
            )

            return null
        }

        var cursor: Cursor? = null

        try {

            val projection =
                arrayOf(
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.TYPE,
                    CallLog.Calls.DATE
                )

            val selection =
                "(" +
                    "${CallLog.Calls.TYPE} = ? OR " +
                    "${CallLog.Calls.TYPE} = ? OR " +
                    "${CallLog.Calls.TYPE} = ?" +
                    ") AND " +
                    "${CallLog.Calls.DATE} >= ?"

            val selectionArgs =
                arrayOf(
                    CallLog.Calls.INCOMING_TYPE.toString(),
                    CallLog.Calls.MISSED_TYPE.toString(),
                    CallLog.Calls.REJECTED_TYPE.toString(),
                    (
                        ringingStartedAt - 5000L
                    ).toString()
                )

            cursor =
                context.contentResolver.query(
                    CallLog.Calls.CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    "${CallLog.Calls.DATE} DESC"
                )

            if (
                cursor != null &&
                cursor.moveToFirst()
            ) {

                val numberIndex =
                    cursor.getColumnIndex(
                        CallLog.Calls.NUMBER
                    )

                if (numberIndex != -1) {

                    val candidate =
                        cursor.getString(
                            numberIndex
                        )

                    if (
                        isUsablePhoneNumber(
                            candidate
                        )
                    ) {
                        return candidate
                    }
                }
            }

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Error leyendo CallLog: ${e.message}",
                e
            )

        } finally {

            cursor?.close()
        }

        return null
    }

    // ==============================================================================================
    // VALIDACIÓN
    // ==============================================================================================

    private fun isUsablePhoneNumber(
        number: String?
    ): Boolean {

        if (number.isNullOrBlank()) {
            return false
        }

        val clean =
            number
                .trim()
                .lowercase()

        when (clean) {

            "unknown",
            "desconocido",
            "private",
            "privado",
            "restricted",
            "restringido",
            "null",
            "número oculto",
            "numero oculto" -> {
                return false
            }
        }

        val digits =
            clean.filter {
                it.isDigit()
            }

        return digits.length >= 7
    }

    // ==============================================================================================
    // PUBLICAR NÚMERO
    // ==============================================================================================

    private fun publishIncomingNumber(
        context: Context,
        phoneNumber: String
    ) {

        if (!isIncoming) {
            return
        }

        val normalized =
            phoneNumber.filter {
                it.isDigit()
            }

        val previousNormalized =
            activeNumber?.filter {
                it.isDigit()
            }

        if (
            previousNormalized != null &&
            previousNormalized == normalized
        ) {
            return
        }

        activeNumber =
            phoneNumber

        Log.e(
            TAG,
            "=================================================="
        )

        Log.e(
            TAG,
            "NÚMERO ENTRANTE DETECTADO"
        )

        Log.e(
            TAG,
            "NÚMERO = $phoneNumber"
        )

        Log.e(
            TAG,
            "=================================================="
        )

        savePendingCall(
            context,
            phoneNumber
        )

        notifyFlutterCallIntercepted(
            phoneNumber
        )
    }

    // ==============================================================================================
    // GUARDAR LLAMADA PENDIENTE
    // ==============================================================================================

    private fun savePendingCall(
        context: Context,
        phoneNumber: String
    ) {

        val timestamp =
            System.currentTimeMillis()

        context
            .getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )
            .edit()
            .putBoolean(
                KEY_PENDING_ACTIVE,
                true
            )
            .putString(
                KEY_PENDING_NUMBER,
                phoneNumber
            )
            .putLong(
                KEY_PENDING_TIMESTAMP,
                timestamp
            )
            .apply()

        Log.e(
            TAG,
            "Llamada guardada como evento pendiente."
        )
    }

    // ==============================================================================================
    // FLUTTER
    // ==============================================================================================

    private fun notifyFlutterCallIntercepted(
        phoneNumber: String
    ) {

        val channel =
            flutterMethodChannel

        if (channel == null) {

            Log.e(
                TAG,
                "=================================================="
            )

            Log.e(
                TAG,
                "MethodChannel NO DISPONIBLE."
            )

            Log.e(
                TAG,
                "La llamada quedó guardada para Flutter."
            )

            Log.e(
                TAG,
                "=================================================="

            )

            return
        }

        val payload =
            mapOf(
                "phoneNumber" to phoneNumber,
                "timestamp" to System.currentTimeMillis()
            )

        Handler(
            Looper.getMainLooper()
        ).post {

            try {

                channel.invokeMethod(
                    "onCallIntercepted",
                    payload
                )

                Log.e(
                    TAG,
                    "Evento enviado correctamente a Flutter."
                )

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Error enviando evento a Flutter: ${e.message}",
                    e
                )
            }
        }
    }

    // ==============================================================================================
    // FIN DE LLAMADA
    // ==============================================================================================

    private fun notifyFlutterCallEnded() {

        val channel =
            flutterMethodChannel
                ?: return

        Handler(
            Looper.getMainLooper()
        ).post {

            try {

                channel.invokeMethod(
                    "onCallEnded",
                    null
                )

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Error notificando fin de llamada: ${e.message}",
                    e
                )
            }
        }
    }
}
