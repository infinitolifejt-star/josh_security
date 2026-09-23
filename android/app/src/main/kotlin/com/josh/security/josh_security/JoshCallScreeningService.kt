package com.josh.security.josh_security

import android.content.Intent
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

class JoshCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "JOSH_CALL_SERVICE"
        private const val BASE_SERVER_URL = "https://josh-security-backend.onrender.com"
        private const val EVALUATE_URL = "$BASE_SERVER_URL/api/v1/evaluate_phone"
        private const val PING_URL = "$BASE_SERVER_URL/ping"
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val rawNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            callDetails.handle?.schemeSpecificPart ?: ""
        } else {
            ""
        }

        val phoneNumber = if (rawNumber.isBlank()) "Desconocido" else rawNumber
        Log.d(TAG, "Llamada entrante detectada: $phoneNumber")

        // 1. Responder de inmediato al SO dentro del tiempo de gracia (Evita descarte del sistema)
        val response = CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()

        respondToCall(callDetails, response)

        // 2. Disparar Ping Ultraligero asíncrono para despertar Render INMEDIATAMENTE
        CoroutineScope(Dispatchers.IO).launch {
            wakeUpBackend()
        }

        // 3. Guardar registro inicial en SQLite con estado EVALUANDO
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

        // 4. Lanzar overlay emergente de Caller ID en estado EVALUANDO
        launchCallerIdOverlay(phoneNumber, "EVALUANDO", -1.0)

        // 5. Evaluar reputación con lógica de reintentos
        if (phoneNumber != "Desconocido" && insertedId != -1L) {
            CoroutineScope(Dispatchers.IO).launch {
                fetchBackendWithRetry(phoneNumber, insertedId)
            }
        }
    }

    private fun wakeUpBackend() {
        try {
            val url = URL(PING_URL)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 3000
            conn.readTimeout = 3000
            val code = conn.responseCode
            Log.d(TAG, "Ping preventivo a Render enviado. Respuesta: $code")
            conn.disconnect()
        } catch (e: Exception) {
            Log.w(TAG, "Ping preventivo no completado (esperado si está dormido): ${e.message}")
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

    private suspend fun fetchBackendWithRetry(phoneNumber: String, recordId: Long) {
        var finalStatus = "ERROR_EVALUACION"
        var fraudScore = -1.0
        val maxRetries = 3
        var success = false

        val cleanNum = phoneNumber.replace("+", "").replace(" ", "").trim()

        for (attempt in 1..maxRetries) {
            try {
                Log.d(TAG, "Intento $attempt de $maxRetries consultando backend...")
                val url = URL("$EVALUATE_URL?number=$cleanNum")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "GET"
                // Tiempos de espera incrementales para tolerar el cold start
                conn.connectTimeout = 10000 + (attempt * 2000)
                conn.readTimeout = 10000 + (attempt * 2000)

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

                    Log.d(TAG, "Backend evaluado con éxito en intento $attempt: RiskScore=$fraudScore, Status=$finalStatus")
                    conn.disconnect()
                    success = true
                    break
                } else {
                    Log.w(TAG, "Intento $attempt falló con HTTP Code: ${conn.responseCode}")
                    conn.disconnect()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Excepción en intento $attempt: ${e.message}")
            }

            if (attempt < maxRetries) {
                delay((attempt * 1500).toLong()) // Espera progresiva entre reintentos
            }
        }

        if (!success) {
            Log.e(TAG, "No se pudo obtener respuesta del backend tras $maxRetries intentos.")
        }

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
