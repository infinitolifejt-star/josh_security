package com.josh.security.josh_security

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class PhoneCallReceiver : BroadcastReceiver() {

    companion object {

        private const val TAG =
            "PhoneCallReceiver"

        private const val PREFS_NAME =
            "josh_security_phone_calls"

        private const val KEY_PENDING_NUMBER =
            "pending_number"

        private const val KEY_PENDING_TIMESTAMP =
            "pending_timestamp"

        private const val KEY_PENDING_ACTIVE =
            "pending_active"

        @Volatile
        private var flutterMethodChannel: MethodChannel? =
            null

        @Volatile
        private var lastScreenedNumber: String? =
            null

        @Volatile
        private var lastScreenedTimestamp: Long =
            0L

        /**
         * Conecta el MethodChannel de la MainActivity
         * con este componente.
         */
        fun setMethodChannel(
            channel: MethodChannel?
        ) {
            flutterMethodChannel = channel

            Log.d(
                TAG,
                "MethodChannel actualizado: ${channel != null}"
            )
        }

        /**
         * Recupera una llamada que fue detectada
         * mientras Flutter no estaba disponible.
         */
        fun getPendingCall(
            context: Context
        ): Map<String, Any?>? {

            val prefs =
                context.getSharedPreferences(
                    PREFS_NAME,
                    Context.MODE_PRIVATE
                )

            if (
                !prefs.getBoolean(
                    KEY_PENDING_ACTIVE,
                    false
                )
            ) {
                return null
            }

            return mapOf(
                "phoneNumber" to (
                    prefs.getString(
                        KEY_PENDING_NUMBER,
                        null
                    ) ?: "Número Oculto"
                ),

                "timestamp" to
                    prefs.getLong(
                        KEY_PENDING_TIMESTAMP,
                        0L
                    )
            )
        }

        /**
         * Elimina la llamada pendiente después
         * de que Flutter la haya procesado.
         */
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

        /**
         * ÚNICO punto de entrada para una llamada
         * entrante detectada por CallScreeningService.
         *
         * Ya NO usamos:
         *
         * - PHONE_STATE
         * - EXTRA_INCOMING_NUMBER
         * - CallLog
         * - delays
         * - consultas posteriores
         */
        fun handleScreenedIncomingCall(
            context: Context,
            phoneNumber: String?
        ) {

            val normalizedNumber =
                normalizePhoneNumber(
                    phoneNumber
                )

            val timestamp =
                System.currentTimeMillis()

            /*
             * Evitamos procesar dos veces exactamente
             * la misma notificación recibida en un
             * intervalo muy corto.
             */
            if (
                normalizedNumber != null &&
                normalizedNumber == lastScreenedNumber &&
                timestamp - lastScreenedTimestamp < 3000L
            ) {

                Log.d(
                    TAG,
                    "Llamada duplicada ignorada: $normalizedNumber"
                )

                return
            }

            lastScreenedNumber =
                normalizedNumber

            lastScreenedTimestamp =
                timestamp

            val displayNumber =
                normalizedNumber
                    ?: "Número Oculto"

            Log.d(
                TAG,
                "=========================================="
            )

            Log.d(
                TAG,
                "LLAMADA ENTRANTE RECIBIDA"
            )

            Log.d(
                TAG,
                "Número: $displayNumber"
            )

            Log.d(
                TAG,
                "=========================================="
            )

            savePendingCall(
                context,
                displayNumber,
                timestamp
            )

            notifyFlutterCallIntercepted(
                displayNumber,
                timestamp
            )
        }

        /**
         * Normaliza y valida el número recibido
         * directamente desde Call.Details.handle.
         */
        private fun normalizePhoneNumber(
            phoneNumber: String?
        ): String? {

            if (phoneNumber.isNullOrBlank()) {
                return null
            }

            val clean =
                phoneNumber
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
                    return null
                }
            }

            val digits =
                clean.filter {
                    it.isDigit()
                }

            if (digits.length < 7) {
                return null
            }

            return phoneNumber.trim()
        }

        /**
         * Guarda inmediatamente la llamada.
         *
         * Esto permite que Flutter pueda recuperarla
         * aunque MainActivity todavía no esté activa.
         */
        private fun savePendingCall(
            context: Context,
            phoneNumber: String,
            timestamp: Long
        ) {

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

            Log.d(
                TAG,
                "Llamada guardada como pendiente."
            )
        }

        /**
         * Envía la llamada a Flutter si MainActivity
         * tiene actualmente un MethodChannel activo.
         *
         * Si Flutter no está disponible, NO perdemos
         * el evento porque ya fue guardado arriba.
         */
        private fun notifyFlutterCallIntercepted(
            phoneNumber: String,
            timestamp: Long
        ) {

            val channel =
                flutterMethodChannel

            if (channel == null) {

                Log.d(
                    TAG,
                    "MethodChannel no disponible."
                )

                Log.d(
                    TAG,
                    "La llamada permanece guardada como pendiente."
                )

                return
            }

            val payload =
                mapOf(
                    "phoneNumber" to phoneNumber,
                    "timestamp" to timestamp
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
                        "Evento onCallIntercepted enviado a Flutter."
                    )

                } catch (e: Exception) {

                    Log.e(
                        TAG,
                        "Error enviando llamada a Flutter.",
                        e
                    )
                }
            }
        }
    }

    /**
     * Se conserva el BroadcastReceiver porque todavía
     * está declarado en AndroidManifest.xml y porque
     * MainActivity/otros componentes pueden depender
     * de la clase.
     *
     * IMPORTANTE:
     *
     * Ya NO usamos PHONE_STATE para detectar llamadas.
     *
     * La detección real la hace CallScreeningService.
     */
    override fun onReceive(
        context: Context,
        intent: Intent
    ) {

        Log.d(
            TAG,
            "Broadcast recibido: ${intent.action}"
        )

        Log.d(
            TAG,
            "PHONE_STATE ya no se utiliza para detectar llamadas."
        )
    }
}
