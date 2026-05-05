import 'package:flutter/material.dart';
import 'package:josh_security/services/security_service.dart';

void main() => runApp(const JoshSecurityApp());

class JoshSecurityApp extends StatelessWidget {
  const JoshSecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOSH Security',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScannerScreen(),
    );
  }
}

class MainScannerScreen extends StatefulWidget {
  const MainScannerScreen({super.key});

  @override
  State<MainScannerScreen> createState() => _MainScannerScreenState();
}

class _MainScannerScreenState extends State<MainScannerScreen> {
  final SecurityService _security = SecurityService();
  final TextEditingController _urlController = TextEditingController();
  
  String _resultLabel = 'SISTEMA CENTINELA ACTIVO';
  String _resultDetails = 'Ingrese un link para iniciar el análisis.';
  bool _isLoading = false;

  void _startScan() async {
    if (_urlController.text.isEmpty) return;
    setState(() => _isLoading = true);
    final results = await _security.analyzeUrl(_urlController.text);
    setState(() {
      _resultLabel = results['label']!;
      _resultDetails = results['details']!;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Center(
                child: Container(
                  height: 160, width: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.2), // Sintaxis moderna corregida
                        blurRadius: 40,
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png', 
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(Icons.shield, size: 80, color: Colors.blue),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              const Text('JOSH Security', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('Protección Digital Inteligente', style: TextStyle(color: Colors.blueAccent)),
              const SizedBox(height: 45),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  filled: true, fillColor: const Color(0xFF161B22),
                  hintText: 'Pegue el enlace aquí...',
                  prefixIcon: const Icon(Icons.link, color: Colors.blue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('ANALIZAR ENLACE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Text(_resultLabel, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    Text(_resultDetails, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}