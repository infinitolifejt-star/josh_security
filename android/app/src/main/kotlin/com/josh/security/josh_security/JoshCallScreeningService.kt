package com.josh.security.josh_security

import android.content.Intent
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log

class JoshCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "JOSH_CALL_SERVICE"
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val rawNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            callDetails.handle?.schemeSpecificPart ?: ""
        } else {
            ""
        }

        val phoneNumber = if (rawNumber.isBlank()) "Desconocido" else rawNumber
        Log.d(TAG, "Llamada entrante detectada: $phoneNumber")

        // 1. Respuesta inmediata al sistema Telecom para no bloquear la llamada
        val response = CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()

        respondToCall(callDetails, response)

        // 2. Persistencia síncrona en la base de datos SQLite nativa
        try {
            val repository = JoshCallRepository(applicationContext)
            val insertedId = repository.saveCall(
                number = phoneNumber,
                name = "Desconocido",
                type = "ENTRANTE",
                status = "SEGURO",
                riskScore = 0.0,
                isVerified = false
            )
            Log.d(TAG, "Llamada registrada en DB Nativa con ID: $insertedId")
        } catch (e: Exception) {
            Log.e(TAG, "Error registrando llamada en SQLite: ${e.message}", e)
        }

        // 3. Lanzar alerta emergente Overlay (si aplica)
        try {
            val intent = Intent(this, CallerIdActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("PHONE_NUMBER", phoneNumber)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error al lanzar CallerIdActivity: ${e.message}")
        }
    }
}
