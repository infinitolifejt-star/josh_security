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

        private const val CHANNEL_NAME =
            "josh_security/phone_interceptor"

        var methodChannel: MethodChannel? = null

        private var isIncoming = false
        private var activeNumber: String? = null
        private var ringingStartedAt = 0L
        private var callGeneration = 0L
    }

    // =============================================================================================
    // RECEIVE
    // =============================================================================================

    override fun onReceive(
        context: Context,
        intent: Intent
    ) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            return
        }

        val state = intent.getStringExtra(
            TelephonyManager.EXTRA_STATE
        ) ?: return

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

    // =============================================================================================
    // RINGING
    // =============================================================================================

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

        /*
         * Android puede enviar dos broadcasts RINGING cuando la aplicación
         * posee READ_CALL_LOG + READ_PHONE_STATE:
         *
         * 1. Uno con EXTRA_INCOMING_NUMBER.
         * 2. Otro sin número.
         *
         * Por eso NO debemos utilizar un "lastState == RINGING"
         * para descartar el segundo broadcast.
         */

        @Suppress("DEPRECATION")
        val directNumber = intent.getStringExtra(
            TelephonyManager.EXTRA_INCOMING_NUMBER
        )

        if (isUsablePhoneNumber(directNumber)) {

            Log.d(
                TAG,
                "Número entrante capturado directamente: $directNumber"
            )

            publishIncomingNumber(
                directNumber!!
            )

            return
        }

        /*
         * No declaramos inmediatamente "Número Oculto".
         *
         * Primero intentamos recuperar el número desde CallLog.
         */

        scheduleCallLogFallback(
            context = context.applicationContext,
            generation = generation
        )
    }

    // =============================================================================================
    // OFFHOOK
    // =============================================================================================

    private fun handleOffHook() {

        if (!isIncoming) {
            return
        }

        Log.d(
            TAG,
            "Llamada entrante en curso: ${activeNumber ?: "Número desconocido"}"
        )
    }

    // =============================================================================================
    // IDLE
    // =============================================================================================

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

    // =============================================================================================
    // CALL LOG FALLBACK
    // =============================================================================================

    private fun scheduleCallLogFallback(
        context: Context,
        generation: Long
    ) {

        val handler = Handler(
            Looper.getMainLooper()
        )

        val delays = longArrayOf(
            400L,
            1000L,
            1800L,
            2600L
        )

        for (delay in delays) {

            handler.postDelayed({

                /*
                 * La llamada ya terminó.
                 */
                if (!isIncoming) {
                    return@postDelayed
                }

                /*
                 * Ya comenzó otra llamada.
                 */
                if (generation != callGeneration) {
                    return@postDelayed
                }

                /*
                 * Ya tenemos número.
                 */
                if (isUsablePhoneNumber(activeNumber)) {
                    return@postDelayed
                }

                val number = getRecentIncomingNumber(
                    context
                )

                if (isUsablePhoneNumber(number)) {

                    Log.d(
                        TAG,
                        "Número recuperado desde CallLog: $number"
                    )

                    publishIncomingNumber(
                        number!!
                    )
                }

            }, delay)
        }

        /*
         * Último intento.
         *
         * Si Android nunca proporciona el número,
         * notificamos explícitamente que no está disponible.
         */

        handler.postDelayed({

            if (!isIncoming) {
                return@postDelayed
            }

            if (generation != callGeneration) {
                return@postDelayed
            }

            if (isUsablePhoneNumber(activeNumber)) {
                return@postDelayed
            }

            Log.w(
                TAG,
                "No fue posible obtener el número entrante."
            )

            publishIncomingNumber(
                "Número Oculto"
            )

        }, 3200L)
    }

    // =============================================================================================
    // CALL LOG
    // =============================================================================================

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

        val now = System.currentTimeMillis()

        /*
         * Permitimos un pequeño margen antes del inicio
         * del ringing para tolerar diferencias de timestamps.
         */

        val minimumDate =
            ringingStartedAt - 1500L

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
                "AND ${CallLog.Calls.DATE} >= ? " +
                "AND ${CallLog.Calls.DATE} <= ?"

            val selectionArgs = arrayOf(
                CallLog.Calls.INCOMING_TYPE.toString(),
                CallLog.Calls.MISSED_TYPE.toString(),
                CallLog.Calls.REJECTED_TYPE.toString(),
                minimumDate.toString(),
                now.toString()
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

                    if (
                        isUsablePhoneNumber(candidate)
                    ) {
                        return candidate
                    }
                }
            }

        } catch (e: SecurityException) {

            Log.e(
                TAG,
                "Sin permiso para leer CallLog: ${e.message}"
            )

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

    // =============================================================================================
    // NUMBER VALIDATION
    // =============================================================================================

    private fun isUsablePhoneNumber(
        number: String?
    ): Boolean {

        if (number.isNullOrBlank()) {
            return false
        }

        val clean = number.trim()

        val lower = clean.lowercase()

        when (lower) {

            "unknown",
            "desconocido",
            "private",
            "privado",
            "restricted",
            "restringido",
            "null" -> {
                return false
            }
        }

        val digits = clean.filter {
            it.isDigit()
        }

        return digits.length >= 7
    }

    // =============================================================================================
    // PUBLISH NUMBER
    // =============================================================================================

    private fun publishIncomingNumber(
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

        /*
         * Evitar duplicados.
         */

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

    // =============================================================================================
    // FLUTTER - CALL INTERCEPTED
    // =============================================================================================

    private fun notifyFlutterCallIntercepted(
        phoneNumber: String
    ) {

        val channel = methodChannel

        if (channel == null) {

            /*
             * IMPORTANTE:
             *
             * El BroadcastReceiver puede ejecutarse cuando Flutter
             * todavía no ha creado MainActivity/MethodChannel.
             *
             * Por ahora no intentamos invocar un canal inexistente.
             *
             * El siguiente paso de la arquitectura será persistir
             * este evento para recuperarlo cuando Flutter arranque.
             */

            Log.w(
                TAG,
                "MethodChannel no disponible. " +
                    "Evento de llamada no enviado todavía: $phoneNumber"
            )

            return
        }

        val payload = mapOf(
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

                Log.d(
                    TAG,
                    "Evento enviado correctamente a Flutter."
                )

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Error enviando evento a Flutter: ${e.message}"
                )
            }
        }
    }

    // =============================================================================================
    // FLUTTER - CALL ENDED
    // =============================================================================================

    private fun notifyFlutterCallEnded() {

        val channel = methodChannel
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
                    "Error notificando fin de llamada: ${e.message}"
                )
            }
        }
    }
}
