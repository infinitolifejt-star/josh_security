package com.josh.security.josh_security

import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log

class CallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "JoshCallScreening"
    }

    override fun onScreenCall(callDetails: Call.Details) {

        Log.d(TAG, "==========================================")
        Log.d(TAG, "JOSH CALL SCREENING ACTIVADO")
        Log.d(TAG, "==========================================")

        Log.d(
            TAG,
            "Dirección: ${callDetails.callDirection}"
        )

        /*
         * Solo nos interesan llamadas entrantes.
         */
        if (
            callDetails.callDirection ==
            Call.Details.DIRECTION_INCOMING
        ) {

            val handle = callDetails.handle

            val phoneNumber =
                handle?.schemeSpecificPart
                    ?: "Número Oculto"

            Log.d(
                TAG,
                "Número: $phoneNumber"
            )

            /*
             * Guardamos y notificamos la llamada
             * directamente desde el servicio.
             */
            PhoneCallReceiver.handleScreenedIncomingCall(
                applicationContext,
                phoneNumber
            )
        }

        /*
         * IMPORTANTE:
         *
         * Respondemos inmediatamente.
         *
         * La documentación de Android exige que
         * respondToCall() se ejecute dentro de 5 segundos.
         */
        val response =
            CallResponse.Builder()
                .setDisallowCall(false)
                .setRejectCall(false)
                .setSilenceCall(false)
                .setSkipNotification(false)
                .build()

        respondToCall(
            callDetails,
            response
        )

        Log.d(
            TAG,
            "Respuesta de screening enviada."
        )
    }

    override fun onDestroy() {

        Log.d(
            TAG,
            "CallScreeningService destruido."
        )

        super.onDestroy()
    }
}
