package com.josh.security.josh_security

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

class PhoneCallReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PhoneCallReceiver"

        var methodChannel: MethodChannel? = null

        private var isIncoming = false
        private var activeNumber: String? = null
        private var ringingStartedAt = 0L
        private var callGeneration = 0L
    }

    override fun onReceive(
        context: Context,
        intent: Intent
    ) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            return
        }

        val state =
            intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                ?: return

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                handleRinging(context, intent)
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                handleOffHook()
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                handleIdle()
            }
        }
    }

    // ================================================================================================
    // RINGING
    // ================================================================================================

    private fun handleRinging(
        context: Context,
        intent: Intent
    ) {
        if (!isIncoming) {
            isIncoming = true
            activeNumber = null
            ringingStartedAt = System.currentTimeMillis()
            callGeneration++
        }

        val generation = callGeneration

        @Suppress("DEPRECATION")
        val directNumber =
            intent.getStringExtra(
                TelephonyManager.EXTRA_INCOMING_NUMBER
            )

        if (isUsablePhoneNumber(directNumber)) {
            Log.d(
                TAG,
                "Número entrante capturado directamente: $directNumber"
            )

            publishIncomingNumber(directNumber!!)
            return
        }

        val immediateNumber =
            getRecentIncomingNumber(
                context.applicationContext
            )

        if (isUsablePhoneNumber(immediateNumber)) {
            Log.d(
                TAG,
                "Número recuperado inmediatamente desde CallLog: $immediateNumber"
            )

            publishIncomingNumber(immediateNumber!!)
            return
        }

        scheduleCallLogFallback(
            context = context.applicationContext,
            generation = generation
        )
    }

    // ================================================================================================
    // OFFHOOK
    // ================================================================================================

    private fun handleOffHook() {
        if (!isIncoming) {
            return
        }

        Log.d(
            TAG,
            "Llamada entrante en curso: ${activeNumber ?: "Número desconocido"}"
        )
    }

    // ================================================================================================
    // IDLE
    // ================================================================================================

    private fun handleIdle() {
        if (!isIncoming) {
            return
        }

        Log.d(
            TAG,
            "Llamada entrante finalizada o rechazada"
        )

        isIncoming = false
        activeNumber = null
        ringingStartedAt = 0L
        callGeneration++

        notifyFlutterCallEnded()
    }

    // ================================================================================================
    // FALLBACK CALL LOG
    // ================================================================================================

    private fun scheduleCallLogFallback(
        context: Context,
        generation: Long
    ) {
        val handler = Handler(Looper.getMainLooper())

        val delays = longArrayOf(
            50L,
            200L,
            600L,
            1200L
        )

        for (delay in delays) {
            handler.postDelayed(
                {
                    if (!isIncoming ||
                        generation != callGeneration
                    ) {
                        return@postDelayed
                    }

                    if (isUsablePhoneNumber(activeNumber)) {
                        return@postDelayed
                    }

                    val number =
                        getRecentIncomingNumber(context)

                    if (isUsablePhoneNumber(number)) {
                        Log.d(
                            TAG,
                            "Número recuperado desde CallLog en reintento ($delay ms): $number"
                        )

                        publishIncomingNumber(number!!)
                    }
                },
                delay
            )
        }

        handler.postDelayed(
            {
                if (!isIncoming ||
                    generation != callGeneration
                ) {
                    return@postDelayed
                }

                if (isUsablePhoneNumber(activeNumber)) {
                    return@postDelayed
                }

                Log.w(
                    TAG,
                    "No fue posible obtener el número entrante. Se enviará como número oculto."
                )

                publishIncomingNumber("Número Oculto")
            },
            1800L
        )
    }

    // ================================================================================================
    // CALL LOG
    // ================================================================================================

    private fun getRecentIncomingNumber(
        context: Context
    ): String? {

        if (
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_CALL_LOG
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(
                TAG,
                "READ_CALL_LOG no concedido."
            )

            return null
        }

        var cursor: Cursor? = null

        try {
            val projection = arrayOf(
                CallLog.Calls.NUMBER,
                CallLog.Calls.TYPE,
                CallLog.Calls.DATE
            )

            val selection =
                "(${CallLog.Calls.TYPE} = ? " +
                "OR ${CallLog.Calls.TYPE} = ? " +
                "OR ${CallLog.Calls.TYPE} = ?) " +
                "AND ${CallLog.Calls.DATE} >= ?"

            val selectionArgs = arrayOf(
                CallLog.Calls.INCOMING_TYPE.toString(),
                CallLog.Calls.MISSED_TYPE.toString(),
                CallLog.Calls.REJECTED_TYPE.toString(),
                (ringingStartedAt - 2500L).toString()
            )

            cursor = context.contentResolver.query(
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
                        cursor.getString(numberIndex)

                    if (isUsablePhoneNumber(candidate)) {
                        return candidate
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(
                TAG,
                "Error leyendo CallLog: ${e.message}"
            )
        } finally {
            cursor?.close()
        }

        return null
    }

    // ================================================================================================
    // VALIDACIÓN BÁSICA DE CAPTURA
    // ================================================================================================

    private fun isUsablePhoneNumber(
        number: String?
    ): Boolean {
        if (number.isNullOrBlank()) {
            return false
        }

        val clean =
            number.trim().lowercase()

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
            clean.filter { it.isDigit() }

        return digits.length >= 7
    }

    // ================================================================================================
    // PUBLICAR NÚMERO
    // ================================================================================================

    private fun publishIncomingNumber(
        phoneNumber: String
    ) {
        if (!isIncoming) {
            return
        }

        val normalized =
            phoneNumber.filter { it.isDigit() }

        val previousNormalized =
            activeNumber?.filter { it.isDigit() }

        if (
            previousNormalized != null &&
            previousNormalized == normalized
        ) {
            return
        }

        activeNumber = phoneNumber

        Log.d(
            TAG,
            "Número entrante listo para Flutter: $phoneNumber"
        )

        notifyFlutterCallIntercepted(
            phoneNumber
        )
    }

    // ================================================================================================
    // FLUTTER: LLAMADA DETECTADA
    // ================================================================================================

    private fun notifyFlutterCallIntercepted(
        phoneNumber: String
    ) {
        val channel =
            methodChannel ?: run {
                Log.w(
                    TAG,
                    "MethodChannel no disponible todavía: $phoneNumber"
                )
                return
            }

        val payload =
            mapOf(
                "phoneNumber" to phoneNumber,
                "timestamp" to System.currentTimeMillis()
            )

        Handler(Looper.getMainLooper()).post {
            try {
                channel.invokeMethod(
                    "onCallIntercepted",
                    payload
                )

                Log.d(
                    TAG,
                    "Evento onCallIntercepted enviado correctamente a Flutter."
                )
            } catch (e: Exception) {
                Log.e(
                    TAG,
                    "Error enviando evento a Flutter: ${e.message}"
                )
            }
        }
    }

    // ================================================================================================
    // FLUTTER: LLAMADA FINALIZADA
    // ================================================================================================

    private fun notifyFlutterCallEnded() {
        val channel =
            methodChannel ?: return

        Handler(Looper.getMainLooper()).post {
            try {
                channel.invokeMethod(
                    "onCallEnded",
                    null
                )

                Log.d(
                    TAG,
                    "Evento onCallEnded enviado correctamente a Flutter."
                )
            } catch (e: Exception) {
                Log.e(
                    TAG,
                    "Error notificando fin de llamada: ${e.message}"
                )
            }
        }
    }
}
