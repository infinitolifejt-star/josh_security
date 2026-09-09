package com.josh.security.josh_security

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageButton
import android.widget.TextView

class CallerIdActivity : Activity() {

    private lateinit var tvPhoneNumber: TextView
    private lateinit var tvCallStatus: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

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

        window.setLayout(
            (resources.displayMetrics.widthPixels * 0.90).toInt(),
            android.view.ViewGroup.LayoutParams.WRAP_CONTENT
        )

        tvPhoneNumber = findViewById(R.id.tvPhoneNumber)
        tvCallStatus = findViewById(R.id.tvCallStatus)
        val btnEntendido = findViewById<Button>(R.id.btnEntendido)
        val btnClose = findViewById<ImageButton>(R.id.btnClose)

        updateUiFromIntent(intent)

        val dismissAction = { finish() }
        btnEntendido?.setOnClickListener { dismissAction() }
        btnClose?.setOnClickListener { dismissAction() }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        intent?.let { updateUiFromIntent(it) }
    }

    private fun updateUiFromIntent(intent: Intent) {
        val number = intent.getStringExtra("PHONE_NUMBER") ?: "Desconocido"
        val name = intent.getStringExtra("CONTACT_NAME") ?: "Desconocido"
        val status = intent.getStringExtra("CALL_STATUS") ?: "EVALUANDO"
        val riskScore = intent.getDoubleExtra("RISK_SCORE", 0.0)

        if (tvPhoneNumber != null) {
            tvPhoneNumber.text = if (name != "Desconocido" && name.isNotBlank()) "$name\n($number)" else number
        }

        if (tvCallStatus != null) {
            when {
                status == "SOSPECHOSO" || riskScore > 50.0 -> {
                    tvCallStatus.text = "⚠️ AMENAZA DETECTADA (${riskScore.toInt()}%)"
                    tvCallStatus.setTextColor(Color.parseColor("#FF5252"))
                }
                status == "EVALUANDO" -> {
                    tvCallStatus.text = "🔍 ANALIZANDO SHIELD..."
                    tvCallStatus.setTextColor(Color.parseColor("#FFC107"))
                }
                else -> {
                    tvCallStatus.text = "🛡️ LLAMADA SEGURA (JOSH SHIELD)"
                    tvCallStatus.setTextColor(Color.parseColor("#00F2FE"))
                }
            }
        }
    }
}
