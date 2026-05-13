import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProactiveAnalysisScreen extends StatefulWidget {
  const ProactiveAnalysisScreen({super.key});

  @override
  State<ProactiveAnalysisScreen> createState() => _ProactiveAnalysisScreenState();
}

class _ProactiveAnalysisScreenState extends State<ProactiveAnalysisScreen> {
  final TextEditingController _urlController = TextEditingController();
  final SentinelApiService _apiService = SentinelApiService();
  String _resultado = "Esperando análisis...";
  bool _isLoading = false;

  void _iniciarAnalisis() async {
    if (_urlController.text.isEmpty) return;
    setState(() { _isLoading = true; _resultado = "Escaneando con JOSH Sentinel..."; });
    final res = await _apiService.checkUrl(_urlController.text);
    setState(() { _resultado = res['status']; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- 1. EL "RESPIRO" SUPERIOR ---
            const SizedBox(height: 60), // Bajamos el logo para que no choque con la cámara del celular

            Image.asset(
              'assets/images/logo_escudo.png',
              height: 180,
              errorBuilder: (context, error, stackTrace) => 
                const Icon(Icons.shield_rounded, size: 120, color: Colors.blueAccent),
            ),
            const SizedBox(height: 20),
            const Text(
              "JOSH SECURITY",
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 40),
            
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "URL SOSPECHOSA",
                labelStyle: const TextStyle(color: Colors.blueAccent),
                filled: true,
                fillColor: Colors.blueAccent.withOpacity(0.05),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent, width: 0.5)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 1)),
              ),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: (!_isLoading) ? _iniciarAnalisis : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("ACTIVAR ESCUDO DUAL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 40),
            
            // --- 2. EL CUADRO CON EFECTO NEÓN (GLOW) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                // Aquí creamos el brillo azul alrededor del cuadro
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                _resultado,
                style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40), // Espacio final para que no quede pegado abajo
          ],
        ),
      ),
    );
  }
}