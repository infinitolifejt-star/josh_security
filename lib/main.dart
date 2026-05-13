import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:josh_security/services/api_service.dart';
import 'dart:math' as math;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('Sentinel Warning: Archivo .env no detectado.');
  }
  runApp(const JoshSecurityApp());
}

class JoshSecurityApp extends StatelessWidget {
  const JoshSecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JOSH Security 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
      ),
      home: const SentinelHome(),
    );
  }
}

class SentinelHome extends StatefulWidget {
  const SentinelHome({super.key});

  @override
  State<SentinelHome> createState() => _SentinelHomeState();
}

class _SentinelHomeState extends State<SentinelHome> {
  double _rotationX = 0;
  double _rotationY = 0;
  
  final TextEditingController _urlController = TextEditingController();
  final SentinelApiService _apiService = SentinelApiService();
  
  // Estado de Inteligencia
  String _statusMessage = 'SISTEMA LISTO PARA ESCANEO';
  Map<String, dynamic>? _lastStats;
  bool _isLoading = false;
  Color _statusColor = Colors.blueAccent;

  void _ejecutarAnalisisTactico() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() {
        _statusMessage = 'ERROR: URL INVALIDA';
        _statusColor = Colors.orangeAccent;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'ANALIZANDO MATRIZ DE AMENAZAS...';
      _statusColor = Colors.cyanAccent;
    });

    try {
      final response = await _apiService.scanUrl(url);
      setState(() {
        if (response.containsKey('error')) {
          _statusMessage = 'FALLO EN COMUNICACION';
          _statusColor = Colors.redAccent;
        } else {
          final stats = response['data']['attributes']['last_analysis_stats'];
          _lastStats = stats;
          int malicious = stats['malicious'] + stats['suspicious'];
          
          if (malicious == 0) {
            _statusMessage = 'AMENAZA NO DETECTADA: SEGURO';
            _statusColor = Colors.greenAccent;
          } else {
            _statusMessage = '¡RIESGO DETECTADO EN LA RED!';
            _statusColor = Colors.redAccent;
          }
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'ERROR CRITICO DE SISTEMA';
        _statusColor = Colors.redAccent;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(painter: GridPainter(), child: Container()),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 50),
            child: Column(
              children: [
                const Text('SENTINEL PROTOCOL 2026', 
                  style: TextStyle(fontSize: 10, letterSpacing: 5, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                
                // Escudo 3D Interactivo
                GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _rotationY += details.delta.dx * 0.01;
                      _rotationX -= details.delta.dy * 0.01;
                    });
                  },
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateX(_rotationX)..rotateY(_rotationY),
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: _statusColor.withOpacity(0.2), blurRadius: 50, spreadRadius: 5)]),
                      child: Image.asset('assets/images/logo_escudo.png', fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Barra de Estado
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(color: _statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                  child: Text(_statusMessage, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 30),

                // Input de Seguridad
                TextField(
                  controller: _urlController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Analizar enlace sospechoso...',
                    prefixIcon: Icon(Icons.shield_outlined, color: _statusColor),
                    filled: true, fillColor: const Color(0xFF13131A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const CircularProgressIndicator(strokeWidth: 2)
                else
                  ElevatedButton(
                    onPressed: _ejecutarAnalisisTactico,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('INICIAR ANALISIS PROACTIVO'),
                  ),

                const SizedBox(height: 30),

                // Panel de Inteligencia (Solo si hay datos)
                if (_lastStats != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF13131A), borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('REPORTE SENTINEL', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Icon(Icons.analytics_outlined, size: 16, color: Colors.grey),
                          ],
                        ),
                        const Divider(height: 30, color: Colors.white10),
                        _buildStatRow('Limpio', _lastStats!['harmless'], Colors.greenAccent),
                        _buildStatRow('Malicioso', _lastStats!['malicious'], Colors.redAccent),
                        _buildStatRow('Sospechoso', _lastStats!['suspicious'], Colors.orangeAccent),
                        _buildStatRow('No Analizado', _lastStats!['undetected'], Colors.grey),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          Text(value.toString(), style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blueAccent.withOpacity(0.03)..strokeWidth = 1.0;
    for (double i = 0; i <= size.width; i += 40) { canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint); }
    for (double i = 0; i <= size.height; i += 40) { canvas.drawLine(Offset(0, i), Offset(size.width, i), paint); }
  }
  @override bool shouldRepaint(CustomPainter oldDelegate) => false;
}
