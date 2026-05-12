import 'package:flutter/material.dart';
import 'package:josh_security/services/security_service.dart';
import 'dart:math' as math;

class CentinelaDashboard extends StatefulWidget {
  const CentinelaDashboard({super.key});

  @override
  State<CentinelaDashboard> createState() => _CentinelaDashboardState();
}

class _CentinelaDashboardState extends State<CentinelaDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final TextEditingController _urlController = TextEditingController();
  Offset _mousePos = Offset.zero;
  String _statusMessage = "PROTOCOLO DE VIGILANCIA ACTIVO";
  Color _accentColor = Colors.greenAccent;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _ejecutarProtocolo() async {
    if (_urlController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _statusMessage = "ESCANEO MULTI-CAPA EN CURSO...";
      _accentColor = Colors.cyanAccent;
    });

    final resultado = await SecurityService.analizarDominio(_urlController.text);

    setState(() {
      _isLoading = false;
      if (resultado['status'] == 'success') {
        int maliciosos = resultado['malicious'];
        if (maliciosos > 0) {
          _statusMessage = "AMENAZA DETECTADA: $maliciosos MOTORES";
          _accentColor = Colors.redAccent;
        } else {
          _statusMessage = "SITIO SEGURO - PROTOCOLO LIMPIO";
          _accentColor = Colors.greenAccent;
        }
      } else {
        _statusMessage = "ERROR DE CONEXIÓN CON LA MATRIZ";
        _accentColor = Colors.orangeAccent;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF010508),
      body: MouseRegion(
        onHover: (event) {
          setState(() {
            _mousePos = Offset(
              (event.localPosition.dx - size.width / 2) / (size.width / 2),
              (event.localPosition.dy - size.height / 2) / (size.height / 2),
            );
          });
        },
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: PerspectiveGridPainter(color: _accentColor))),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // --- LOGO ESCUDO INTERACTIVO VIVO ---
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateX(_mousePos.dy * -0.3)
                            ..rotateY((_controller.value * 2 * math.pi) + (_mousePos.dx * 0.3)),
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: _accentColor.withOpacity(0.15), blurRadius: 80, spreadRadius: 10)
                              ],
                            ),
                            child: Image.asset('assets/images/logo_escudo.png'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    const Text("JOSH SECURITY", style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 10, color: Colors.white)),
                    const Text("TU SEGURIDAD IMPORTA", style: TextStyle(color: Colors.greenAccent, fontSize: 16, letterSpacing: 4, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Text(_statusMessage, style: TextStyle(color: _accentColor.withOpacity(0.8), letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 50),
                    // Input Glassmorphism
                    Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _accentColor.withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: _urlController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        decoration: InputDecoration(
                          hintText: "URL PARA ANÁLISIS TÁCTICO",
                          hintStyle: TextStyle(color: _accentColor.withOpacity(0.2)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (!_isLoading)
                      ElevatedButton(
                        onPressed: _ejecutarProtocolo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text("ANALIZAR MATRIZ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      )
                    else
                      CircularProgressIndicator(color: _accentColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PerspectiveGridPainter extends CustomPainter {
  final Color color;
  PerspectiveGridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.05)..strokeWidth = 1;
    for (double i = 0; i <= size.width; i += 50) canvas.drawLine(Offset(i, 0), Offset(i, size.height), p);
    for (double i = 0; i <= size.height; i += 50) canvas.drawLine(Offset(0, i), Offset(size.width, i), p);
  }
  @override bool shouldRepaint(CustomPainter oldDelegate) => false;
}