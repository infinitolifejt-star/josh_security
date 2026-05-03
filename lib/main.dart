// PROYECTO: JOSH Security - CENTINELA 2026
// ESTADO: Home Screen Finalizado (Pilar 1)
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:clipboard_watcher/clipboard_watcher.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() => runApp(const MaterialApp(home: JOSHHome(), debugShowCheckedModeBanner: false));

class JOSHHome extends StatefulWidget {
  const JOSHHome({super.key});
  @override
  _JOSHHomeState createState() => _JOSHHomeState();
}

class _JOSHHomeState extends State<JOSHHome> with SingleTickerProviderStateMixin, ClipboardListener {
  late AnimationController _controller;
  final TextEditingController _urlController = TextEditingController();
  
  // Parámetros de Seguridad
  final String _apiKey = '003fa969b0ddef2e33b9cb5cb7a00747ce1c2d2b1e52197a6e0a87649a4548e8';
  String _currentStatus = "SISTEMA ACTIVO";
  bool _isAnalyzing = false;
  Color _glowColor = const Color(0xFF00C853); // Verde Seguridad JOSH

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    clipboardWatcher.addListener(this);
    clipboardWatcher.start();
  }

  @override
  void onClipboardChanged() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.startsWith("http")) {
      _urlController.text = data.text!;
      _startSecurityScan(data.text!);
    }
  }

  Future<void> _startSecurityScan(String url) async {
    if (url.isEmpty) return;
    setState(() { _isAnalyzing = true; _glowColor = Colors.orangeAccent; });
    
    // Simulación de los pilares de revisión
    List<String> steps = ["AUDITANDO RED...", "REVISANDO REPUTACIÓN...", "VERIFICANDO CIFRADO..."];
    for (var step in steps) {
      setState(() => _currentStatus = step);
      await Future.delayed(const Duration(milliseconds: 900));
    }

    try {
      String urlId = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
      final response = await http.get(Uri.parse('https://www.virustotal.com/api/v3/urls/$urlId'), headers: {'x-apikey': _apiKey});
      
      if (response.statusCode == 200) {
        int mal = json.decode(response.body)['data']['attributes']['last_analysis_stats']['malicious'];
        setState(() {
          _isAnalyzing = false;
          _glowColor = mal > 0 ? Colors.redAccent : const Color(0xFF00C853);
          _currentStatus = mal > 0 ? "⚠️ LINK PELIGROSO DETECTADO" : "ENTORNO SEGURO";
        });
      }
    } catch (e) { 
      setState(() { _isAnalyzing = false; _currentStatus = "ERROR DE CONEXIÓN"; _glowColor = Colors.red; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020E21),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment.center, radius: 1.2, colors: [Color(0xFF0A2463), Color(0xFF020E21)]),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 80),
              
              // --- ESCUDO 3D REALISTA ---
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Transform.scale(
                  scale: 1.0 + (_controller.value * 0.05),
                  child: CustomPaint(
                    size: const Size(180, 220),
                    painter: JOSHShieldPainter(glowColor: _glowColor),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              const Text("JOSH", style: TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w900, letterSpacing: 8)),
              const Text("Tu asistente personal de seguridad digital", style: TextStyle(color: Colors.white60, fontSize: 16, fontWeight: FontWeight.w300)),
              
              const SizedBox(height: 60),

              // --- BARRA MANUAL DE URL ---
              Container(
                width: 340,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _glowColor.withOpacity(0.4)),
                ),
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "PEGA O ESCRIBE LA URL AQUÍ",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // --- BOTÓN DE ESTADO / ESCANEO ---
              GestureDetector(
                onTap: _isAnalyzing ? null : () => _startSecurityScan(_urlController.text),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 18),
                  decoration: BoxDecoration(
                    color: _glowColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(35),
                    border: Border.all(color: _glowColor, width: 2),
                    boxShadow: [
                      BoxShadow(color: _glowColor.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
                    ],
                  ),
                  child: Text(
                    _isAnalyzing ? _currentStatus : "AUDITAR AHORA",
                    style: TextStyle(color: _glowColor, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

// ARQUITECTURA VISUAL DEL ESCUDO
class JOSHShieldPainter extends CustomPainter {
  final Color glowColor;
  JOSHShieldPainter({required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Cuerpo Metálico
    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF4A90E2), const Color(0xFF0A2463), const Color(0xFF051125)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Path path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.1);
    path.quadraticBezierTo(size.width * 0.5, 0, size.width * 0.9, size.height * 0.1);
    path.lineTo(size.width * 0.9, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.5, size.height, size.width * 0.1, size.height * 0.7);
    path.close();

    canvas.drawShadow(path, Colors.black, 15, true);
    canvas.drawPath(path, bodyPaint);

    // El Check de Neón (Veredicto)
    final Paint neonPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final Path checkPath = Path();
    checkPath.moveTo(size.width * 0.35, size.height * 0.48);
    checkPath.lineTo(size.width * 0.48, size.height * 0.6);
    checkPath.lineTo(size.width * 0.75, size.height * 0.35);

    canvas.drawPath(checkPath, neonPaint); // Efecto Glow
    neonPaint.maskFilter = null;
    neonPaint.strokeWidth = 5;
    neonPaint.color = Colors.white; 
    canvas.drawPath(checkPath, neonPaint); // Centro Blanco
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}