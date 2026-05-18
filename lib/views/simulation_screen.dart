import 'package:flutter/material.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  int _score = 0;
  int _currentIndex = 0;
  String _feedbackMessage = "ANALIZA LA SOLICITUD ASIGNADA Y ELIGE TU ACCIÓN";
  Color _feedbackColor = Colors.blueAccent;

  // Banco de Casos de Prueba Educativos de Ingeniería Social
  final List<Map<String, dynamic>> _scenarios = [
    {
      "sender": "seguridad@banc0-colombia.net",
      "subject": "ALERTA DE SEGURIDAD: Bloqueo de Cuenta Inmediato",
      "body": "Estimado usuario, detectamos un inicio de sesión inusual desde Bogotá. Para evitar la suspensión permanente de sus productos financieros, haga clic en el siguiente enlace y valide sus datos de inmediato: http://banc0-colombia.net/ingreso-seguro",
      "isPhishing": true,
      "justification": "El remitente usa un dominio falso ('banc0' con cero) y presiona con urgencia para forzar a hacer clic en un enlace HTTP inseguro."
    },
    {
      "sender": "noreply@github.com",
      "subject": "[GitHub] Security Alert: New login detected",
      "body": "A new login was detected on your account from a new IP address. If this was you, no action is needed. If this wasn't you, please review your security logs in your official dashboard setting layout.",
      "isPhishing": false,
      "justification": "Proviene de un dominio verificado oficial, informa de un evento común de seguridad sin exigir datos confidenciales de forma directa en texto plano."
    },
    {
      "sender": "soporte-netflix@verificacion-cuentas.com",
      "subject": "Su membresía ha sido suspendida - Actualice su método de pago",
      "body": "No pudimos procesar su último pago mensual. Su servicio se cancelará en 24 horas. Ingrese a nuestra plataforma de contingencia externa aquí para actualizar su tarjeta de crédito.",
      "isPhishing": true,
      "justification": "El correo amenaza con suspender el servicio de inmediato y redirige a un dominio externo sospechoso ajeno a Netflix."
    }
  ];

  void _evaluateAnswer(bool userSelection) {
    final currentCase = _scenarios[_currentIndex];
    bool isPhishingReal = currentCase["isPhishing"];

    setState(() {
      if (userSelection == isPhishingReal) {
        _score += 10;
        _feedbackMessage = "¡CORRECTO! OPERACIÓN EXITOSA\n\n${currentCase['justification']}";
        _feedbackColor = Colors.greenAccent;
      } else {
        if (_score > 0) _score -= 5;
        _feedbackMessage = "¡ALERTA DE BRECHA! DETECCIÓN ERRÓNEA\n\n${currentCase['justification']}";
        _feedbackColor = Colors.redAccent;
      }

      // Avanzar al siguiente caso o reiniciar el set
      if (_currentIndex < _scenarios.length - 1) {
        _currentIndex++;
      } else {
        _feedbackMessage += "\n\n[SIMULACIÓN COMPLETADA. BUEN TRABAJO EN EL ENTRENAMIENTO]";
        _currentIndex = 0; // Reinicia el ciclo para entrenamiento continuo
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentCase = _scenarios[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "PILAR 2: SIMULADOR DE INGENIERÍA SOCIAL", 
          style: TextStyle(fontSize: 12, letterSpacing: 1.5, fontFamily: 'monospace')
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicador de Puntuación Táctica
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("ESTADO DE CAPACITACIÓN:", style: TextStyle(color: Colors.white38, fontSize: 11)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purpleAccent),
                  ),
                  child: Text("SCORE: $_score PTS", style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            ),
            const SizedBox(height: 24),

            // Contenedor de la Simulación del Correo/Mensaje
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("DE: ", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                      Expanded(child: Text(currentCase["sender"], style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'))),
                    ],
                  ),
                  const Divider(color: Color(0xFF1E293B), height: 20),
                  Row(
                    children: [
                      const Text("ASUNTO: ", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                      Expanded(child: Text(currentCase["subject"], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const Divider(color: Color(0xFF1E293B), height: 20),
                  const SizedBox(height: 8),
                  Text(
                    currentCase["body"],
                    style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botones de Decisión Estratégica
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: () => _evaluateAnswer(true),
                    icon: const Icon(Icons.gpp_bad, color: Colors.red),
                    label: const Text("MARCAR PHISHING", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.2),
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: () => _evaluateAnswer(false),
                    icon: const Icon(Icons.gpp_good, color: Colors.green),
                    label: const Text("MARCAR SEGURO", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Consola de Feedback (Corregido con los dos puntos ":")
            const Text("SISTEMA DE RETROALIMENTACIÓN FORENSE:", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _feedbackColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _feedbackColor),
              ),
              child: Text(
                _feedbackMessage,
                style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4, fontFamily: 'monospace'),
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}