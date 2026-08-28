package com.josh.security.josh_security

import android.app.Activity
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageButton
import android.widget.TextView

class CallerIdActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Configuración para forzar encendido de pantalla y desplegar sobre pantalla bloqueada
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        )

        setContentView(R.layout.activity_caller_id)

        // Ajustar ancho como diálogo flotante nativo
        window.setLayout(
            (resources.displayMetrics.widthPixels * 0.90).toInt(),
            android.view.ViewGroup.LayoutParams.WRAP_CONTENT
        )

        // LEER CON LAS MISMAS LLAVES QUE ENVÍA JOSH_CALL_SCREENING
        val number = intent.getStringExtra("PHONE_NUMBER")
            ?: intent.getStringExtra("EXTRA_PHONE_NUMBER")
            ?: "Desconocido"

        val name = intent.getStringExtra("CONTACT_NAME")
            ?: intent.getStringExtra("EXTRA_NAME")
            ?: "Desconocido"

        val status = intent.getStringExtra("CALL_STATUS")
            ?: intent.getStringExtra("EXTRA_STATUS")
            ?: "SEGURO"

        val riskScore = intent.getDoubleExtra("RISK_SCORE", intent.getDoubleExtra("EXTRA_RISK_SCORE", 0.0))

        val tvPhoneNumber = findViewById<TextView>(R.id.tvPhoneNumber)
        val tvCallStatus = findViewById<TextView>(R.id.tvCallStatus)
        val btnEntendido = findViewById<Button>(R.id.btnEntendido)
        val btnClose = findViewById<ImageButton>(R.id.btnClose)

        // Desplegar nombre y número
        if (tvPhoneNumber != null) {
            tvPhoneNumber.text = if (name != "Desconocido" && name.isNotBlank()) "$name\n($number)" else number
        }

        if (tvCallStatus != null) {
            if (status == "SOSPECHOSO" || riskScore > 50.0) {
                tvCallStatus.text = "⚠️ AMENAZA DETECTADA (${riskScore.toInt()}%)"
                tvCallStatus.setTextColor(Color.parseColor("#FF5252"))
            } else {
                tvCallStatus.text = "🛡️ LLAMADA SEGURA (JOSH SHIELD)"
                tvCallStatus.setTextColor(Color.parseColor("#00F2FE"))
            }
        }

        val dismissAction = { finish() }
        btnEntendido?.setOnClickListener { dismissAction() }
        btnClose?.setOnClickListener { dismissAction() }
    }
}
