import 'package:flutter/material.dart';
import 'package:josh_security/services/security_service.dart';

void main() => runApp(const MaterialApp(
      home: CentinelaV3(),
      debugShowCheckedModeBanner: false,
    ));

class CentinelaV3 extends StatefulWidget {
  const CentinelaV3({super.key});
  @override
  State<CentinelaV3> createState() => _CentinelaV3State();
}

class _CentinelaV3State extends State<CentinelaV3> {
  final TextEditingController _input = TextEditingController();
  final SecurityService _servicio = SecurityService();
  
  String _label = "SISTEMA LISTO";
  String _desc = "Escriba la URL y toque el botón para iniciar.";
  bool _buscando = false;
  
  // Colores de la identidad visual JOSH
  Color _colorEscudo = const Color(0xFF1E3C72); 
  Color _colorCheck = Colors.greenAccent; 
  Color _colorTextoPrincipal = const Color(0xFF5AB2FF); 

  void _analizar() async {
    if (_input.text.isEmpty) return;
    
    setState(() { 
      _buscando = true; 
      _label = "ESCANEANDO..."; 
      _desc = "Analizando integridad digital...";
      _colorCheck = Colors.orangeAccent;
    });

    // Proceso de 3 segundos
    await Future.delayed(const Duration(seconds: 3));

    String limpio = _input.text.replaceAll(RegExp(r'\[|\]|\(.*\)| '), '');
    final res = await _servicio.analyzeUrl(limpio);
    
    setState(() {
      _buscando = false;
      _label = res['label'];
      _desc = res['details'];

      if (_label.contains('PELIGROSA') || _label.contains('PHISHING')) {
        _colorCheck = Colors.redAccent;
        _colorEscudo = Colors.red.shade900;
      } else if (_label.contains('PRECAUCIÓN')) {
        _colorCheck = Colors.yellowAccent;
        _colorEscudo = Colors.orange.shade900;
      } else {
        _colorCheck = Colors.greenAccent;
        _colorEscudo = const Color(0xFF1E3C72);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020A1E), 
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                // --- LOGO JOSH RECONSTRUIDO CON ICONOS ---
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Brillo de fondo
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _colorCheck.withOpacity(0.2),
                            blurRadius: 40,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                    ),
                    // El Escudo Azul
                    Icon(Icons.shield_rounded, size: 140, color: _colorEscudo),
                    // El Check o el Icono de Carga
                    _buscando 
                      ? const SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            color: Colors.orangeAccent,
                            strokeWidth: 6,
                          ),
                        )
                      : Icon(
                          Icons.check_circle_outline_rounded,
                          size: 85,
                          color: _colorCheck,
                        ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  "JOSH",
                  style: TextStyle(
                    color: _colorTextoPrincipal,
                    fontSize: 65,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  "Tu asistente personal de seguridad digital",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                
                const SizedBox(height: 40),

                // --- CAMPO DE TEXTO ---
                TextField(
                  controller: _input,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Pegue la URL sospechosa",
                    labelStyle: TextStyle(color: _colorTextoPrincipal),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: _colorTextoPrincipal.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: _colorTextoPrincipal, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // --- BOTÓN AMARILLO (Como en la versión inicial) ---
                ElevatedButton(
                  onPressed: _buscando ? null : _analizar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellowAccent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 65),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: Text(
                    _buscando ? "ESCANEANDO..." : "INICIAR ESCANEO MÉTRICO",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                
                const SizedBox(height: 35),

                // --- CUADRO DE RESULTADO ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: _colorCheck.withOpacity(0.5), width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _label,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _colorCheck, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _desc,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}