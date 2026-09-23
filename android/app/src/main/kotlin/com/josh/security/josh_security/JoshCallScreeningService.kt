package com.josh.security.josh_security

import android.content.Intent
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

class JoshCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "JOSH_CALL_SERVICE"
        // Servidor Backend en producción (Render)
        private const val BACKEND_URL = "https://josh-security-backend.onrender.com/api/v1/evaluate_phone"
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val rawNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            callDetails.handle?.schemeSpecificPart ?: ""
        } else {
            ""
        }

        val phoneNumber = if (rawNumber.isBlank()) "Desconocido" else rawNumber
        Log.d(TAG, "Llamada entrante detectada: $phoneNumber")

        // 1. Responder de inmediato al SO dentro del tiempo de gracia
        val response = CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()

        respondToCall(callDetails, response)

        // 2. Guardar registro inicial en SQLite con estado EVALUANDO
        val repository = JoshCallRepository(applicationContext)
        var insertedId: Long = -1
        try {
            insertedId = repository.saveCall(
                number = phoneNumber,
                name = "Desconocido",
                type = "ENTRANTE",
                status = "EVALUANDO",
                riskScore = -1.0,
                isVerified = false
            )
            Log.d(TAG, "Llamada registrada temporalmente con ID: $insertedId")

            // Notificar de inmediato a Flutter que hay un nuevo registro en EVALUANDO
            notifyFlutterRefresh()
        } catch (e: Exception) {
            Log.e(TAG, "Error registrando llamada preliminar: ${e.message}", e)
        }

        // 3. Lanzar overlay emergente de Caller ID en estado EVALUANDO
        launchCallerIdOverlay(phoneNumber, "EVALUANDO", -1.0)

        // 4. Evaluar la reputación enviando la petición única al backend
        if (phoneNumber != "Desconocido" && insertedId != -1L) {
            CoroutineScope(Dispatchers.IO).launch {
                fetchBackendAndResult(phoneNumber, insertedId)
            }
        }
    }

    private fun launchCallerIdOverlay(number: String, status: String, riskScore: Double) {
        try {
            val intent = Intent(this, CallerIdActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                putExtra("PHONE_NUMBER", number)
                putExtra("CALL_STATUS", status)
                putExtra("RISK_SCORE", riskScore)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error al lanzar CallerIdActivity: ${e.message}", e)
        }
    }

    private fun fetchBackendAndResult(phoneNumber: String, recordId: Long) {
        var finalStatus = "ERROR_EVALUACION"
        var fraudScore = -1.0

        try {
            val cleanNum = phoneNumber.replace("+", "").replace(" ", "").trim()

            val url = URL("$BACKEND_URL?number=$cleanNum")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 8000
            conn.readTimeout = 8000

            if (conn.responseCode == 200) {
                val responseText = conn.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(responseText)

                fraudScore = json.optDouble("score", -1.0)
                val statusFromBackend = json.optString("status", "NO_VERIFICADO").uppercase()

                finalStatus = when {
                    statusFromBackend == "SOSPECHOSO" || fraudScore >= 50.0 -> "SOSPECHOSO"
                    statusFromBackend == "CRITICO" || fraudScore >= 75.0 -> "CRÍTICO"
                    statusFromBackend == "SEGURO" || (fraudScore in 0.0..29.9) -> "SEGURO"
                    else -> "NO_VERIFICADO"
                }

                Log.d(TAG, "Backend evaluado con éxito: RiskScore=$fraudScore, Status=$finalStatus")
            } else {
                Log.e(TAG, "Backend Http Error Code: ${conn.responseCode}")
                finalStatus = "ERROR_EVALUACION"
                fraudScore = -1.0
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error consultando servidor Render: ${e.message}")
            finalStatus = "ERROR_EVALUACION"
            fraudScore = -1.0
        } finally {
            // Actualizar la base de datos local única con el resultado devuelto
            try {
                val repository = JoshCallRepository(applicationContext)
                repository.updateCallRisk(recordId, finalStatus, fraudScore)
            } catch (e: Exception) {
                Log.e(TAG, "Error actualizando la base de datos final: ${e.message}")
            }

            // Actualizar el overlay de Caller ID con el resultado real
            launchCallerIdOverlay(phoneNumber, finalStatus, fraudScore)

            // Notificar a Flutter para refrescar la lista en pantalla
            notifyFlutterRefresh()
        }
    }

    private fun notifyFlutterRefresh() {
        try {
            val broadcastIntent = Intent("com.josh.security.REFRESH_CALL_LOG").apply {
                setPackage(packageName)
            }
            sendBroadcast(broadcastIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Error enviando broadcast de refresco: ${e.message}")
        }
    }
}
