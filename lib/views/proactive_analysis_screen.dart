import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;

class ProactiveAnalysisScreen extends StatefulWidget {
  const ProactiveAnalysisScreen({super.key});

  @override
  State<ProactiveAnalysisScreen> createState() => _ProactiveAnalysisScreenState();
}

class _ProactiveAnalysisScreenState extends State<ProactiveAnalysisScreen> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  final TextEditingController _urlController = TextEditingController();
  
  Color _statusColor = Colors.blueAccent.withOpacity(0.2);
  String _statusText = "ESPERANDO URL...";
  bool _isAnalyzing = false;
  
  final List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    final String urlInput = _urlController.text.trim();
    if (urlInput.isEmpty) return;
    
    setState(() {
      _isAnalyzing = true;
      _statusText = "SISTEMA CENTINELA: ESCANEANDO...";
      _rotationController.duration = const Duration(seconds: 1);
      _rotationController.repeat();
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/api/v1/analyze'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'url': urlInput}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String status = data['status'];
        final String detail = data['detail'];

        setState(() {
          _isAnalyzing = false;
          _rotationController.duration = const Duration(seconds: 10);
          _rotationController.repeat();
          
          if (status == "PELIGRO") {
            _statusColor = Colors.red.withOpacity(0.8);
            _statusText = "¡ALERTA! AMENAZA DETECTADA";
          } else {
            _statusColor = Colors.green.withOpacity(0.8);
            _statusText = "URL VERIFICADA - SEGURA";
          }
          
          _history.insert(0, {
            "url": urlInput,
            "result": status,
            "detail": detail,
            "color": status == "PELIGRO" ? "red" : "green",
            "time": "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}"
          });
          _urlController.clear();
        });
      } else {
        _handleError("Error de Servidor: ${response.statusCode}");
      }
    } catch (e) {
      _handleError("Error de Conexión de Red: Encienda security_backend.py");
    }
  }

  void _handleError(String message) {
    setState(() {
      _isAnalyzing = false;
      _rotationController.duration = const Duration(seconds: 10);
      _rotationController.repeat();
      _statusColor = Colors.orange.withOpacity(0.8);
      _statusText = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_rotationController.value * 2 * math.pi),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _statusColor.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo_escudo.png', 
                      height: 160,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                        height: 160, 
                        width: 160,
                        child: Icon(Icons.shield, size: 100, color: Colors.blueAccent),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  hintText: "PEGAR URL PARA ANALIZAR CON PYTHON...",
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  prefixIcon: const Icon(Icons.link, color: Colors.blueAccent),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blueAccent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _isAnalyzing ? null : _startAnalysis,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _isAnalyzing ? Colors.grey : Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.blueAccent),
                  boxShadow: [
                    if (!_isAnalyzing) BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 10)
                  ],
                ),
                child: Center(
                  child: Text(
                    _isAnalyzing ? "PROCESANDO..." : "ESCANEAR AHORA",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _statusColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: _statusColor, blurRadius: 20)],
              ),
              child: Center(
                child: Text(
                  _statusText,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "SISTEMA LOG: HISTORIAL DE VIGILANCIA", 
              style: TextStyle(color: Colors.blueAccent, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)
            ),
            Container(
              height: 300,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ListView.builder(
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: item["color"] == "red" ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item["url"]!, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)),
                              const SizedBox(height: 4),
                              Text(item["detail"]!, style: TextStyle(color: item["color"] == "red" ? Colors.redAccent : Colors.white38, fontSize: 10)),
                              Text(item["time"]!, style: const TextStyle(color: Colors.white24, fontSize: 9)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: item["color"] == "red" ? Colors.red : Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(item["result"]!, 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}