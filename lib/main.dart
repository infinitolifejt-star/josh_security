import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

void main() {
  runApp(const MaterialApp(
    home: MainControlPanel(),
    debugShowCheckedModeBanner: false,
  ));
}

class MainControlPanel extends StatefulWidget {
  const MainControlPanel({super.key});

  @override
  _MainControlPanelState createState() => _MainControlPanelState();
}

class _MainControlPanelState extends State<MainControlPanel> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _linkController = TextEditingController();
  
  String _statusMessage = "SISTEMA LISTO";
  bool _isAnalyzing = false;
  Color _shieldColor = Colors.cyanAccent;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  // ANALIZAR ARCHIVO
  Future<void> _handleFileAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage = "Abriendo selector...";
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        String fileName = result.files.single.name;
        setState(() {
          _statusMessage = "ANALIZANDO ARCHIVO: $fileName";
          _shieldColor = Colors.orangeAccent;
        });
        
        // Simulación de escaneo
        await Future.delayed(const Duration(seconds: 3));
        
        setState(() {
          _isAnalyzing = false;
          _statusMessage = "ARCHIVO SEGURO ✅";
          _shieldColor = Colors.greenAccent;
        });
      } else {
        setState(() {
          _isAnalyzing = false;
          _statusMessage = "OPERACIÓN CANCELADA";
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusMessage = "ERROR: $e";
      });
    }
  }

  // ANALIZAR LINK
  Future<void> _handleLinkAnalysis() async {
    if (_linkController.text.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _statusMessage = "VERIFICANDO LINK...";
      _shieldColor = Colors.yellowAccent;
    });

    // Simulación de detección de phishing
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isAnalyzing = false;
      if (_linkController.text.contains("login") || _linkController.text.contains("verify")) {
        _statusMessage = "¡ALERTA! POSIBLE PHISHING DETECTADO";
        _shieldColor = Colors.redAccent;
      } else {
        _statusMessage = "LINK SIN AMENAZAS CONOCIDAS";
        _shieldColor = Colors.greenAccent;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A0E),
      body: Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "JOSH SECURITY",
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
            ),
            const Text(
              "PROYECTO CENTINELA v1.0",
              style: TextStyle(color: Colors.blueGrey, fontSize: 12, letterSpacing: 2),
            ),
            const SizedBox(height: 40),
            
            // Botón de Archivo
            ElevatedButton.icon(
              icon: const Icon(Icons.file_present),
              label: const Text("ANALIZAR DOCUMENTO"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1F2E),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isAnalyzing ? null : _handleFileAnalysis,
            ),
            
            const SizedBox(height: 15),
            
            // Campo de Link
            TextField(
              controller: _linkController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Pegue un link aquí...",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF1A1F2E),
                prefixIcon: const Icon(Icons.link, color: Colors.blueGrey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.cyanAccent),
                  onPressed: _handleLinkAnalysis,
                ),
              ),
            ),

            const SizedBox(height: 50),
            
            // Escudo Animado
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.05).animate(_pulseController),
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _shieldColor.withOpacity(0.5), width: 2),
                ),
                child: Icon(Icons.shield, size: 80, color: _shieldColor),
              ),
            ),
            
            const SizedBox(height: 30),
            
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: _shieldColor, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}