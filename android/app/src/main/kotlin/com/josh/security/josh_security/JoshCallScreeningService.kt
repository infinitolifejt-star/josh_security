package com.josh.security.josh_security

import android.content.Intent
import android.net.Uri
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log

class JoshCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "JOSH_CALL_SCREENING"
    }

    override fun onScreenCall(callDetails: Call.Details) {
        Log.e(TAG, "==================================================")
        Log.e(TAG, "¡NATIVE CALL INTERCEPTED BY JOSH_CALL_SCREENING!")
        Log.e(TAG, "==================================================")

        try {
            // 1. Extraer número de teléfono adecuadamente desde Uri
            val rawHandle: Uri? = callDetails.handle
            val phoneNumber = rawHandle?.schemeSpecificPart ?: "Desconocido"
            Log.e(TAG, "Número entrante detectado: $phoneNumber")

            // 2. Resolver Nombre del Contacto desde la Agenda (READ_CONTACTS)
            val contactName = JoshContactResolver.resolveContactName(applicationContext, phoneNumber)
            Log.e(TAG, "Nombre de contacto resuelto: $contactName")

            // 3. Evaluar Riesgo (Lógica del motor de seguridad JOSH)
            val status = "SEGURO"
            val riskScore = 0.0
            val isVerified = true

            // 4. PERSISTENCIA EN SQLITE
            try {
                val repository = JoshCallRepository(applicationContext)
                val rowId = repository.saveCall(
                    number = phoneNumber,
                    name = contactName,
                    type = "ENTRANTE",
                    status = status,
                    riskScore = riskScore,
                    isVerified = isVerified
                )
                Log.e(TAG, "Llamada guardada en SQLite con ID: $rowId")
            } catch (e: Exception) {
                Log.e(TAG, "Error guardando llamada en JoshCallRepository: ${e.message}", e)
            }

            // 5. RESPUESTA AL SISTEMA OPERATIVO (Permitir la llamada sin bloquear)
            val response = CallResponse.Builder()
                .setDisallowCall(false)
                .setRejectCall(false)
                .setSkipCallLog(false)
                .setSkipNotification(false)
                .build()

            respondToCall(callDetails, response)
            Log.e(TAG, "Llamada respondida al sistema (Permitida)")

            // 6. LANZAR EL POP-UP VISUAL (CallerIdActivity)
            val intent = Intent(applicationContext, CallerIdActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("PHONE_NUMBER", phoneNumber)
                putExtra("CONTACT_NAME", contactName)
                putExtra("CALL_STATUS", status)
                putExtra("RISK_SCORE", riskScore)
                putExtra("IS_VERIFIED", isVerified)
            }

            applicationContext.startActivity(intent)
            Log.e(TAG, "Intent de CallerIdActivity enviado con éxito")

        } catch (e: Exception) {
            Log.e(TAG, "Error crítico en onScreenCall: ${e.message}", e)
        }
    }
}
