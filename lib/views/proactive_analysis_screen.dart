import 'package:flutter/material.dart';

class ProactiveAnalysisScreen extends StatefulWidget {
  const ProactiveAnalysisScreen({super.key});

  @override
  State<ProactiveAnalysisScreen> createState() => _ProactiveAnalysisScreenState();
}

class _ProactiveAnalysisScreenState extends State<ProactiveAnalysisScreen> with TickerProviderStateMixin {
  late AnimationController _shieldController;
  Color _statusColor = Colors.blueAccent.withOpacity(0.2);
  String _statusText = "ESPERANDO URL...";
  
  // Lista para el Historial
  final List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _shieldController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shieldController.dispose();
    super.dispose();
  }

  void _updateStatus(bool isDanger) {
    setState(() {
      _statusColor = isDanger ? Colors.red.withOpacity(0.8) : Colors.green.withOpacity(0.8);
      _statusText = isDanger ? "¡AMENAZA DETECTADA!" : "URL SEGURA";
      
      // Añadir al historial al inicio de la lista
      _history.insert(0, {
        "url": "analisis_${DateTime.now().millisecondsSinceEpoch}.com",
        "result": isDanger ? "PELIGRO" : "LIMPIO",
        "color": isDanger ? "red" : "green"
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const SizedBox(height: 60),
          // ESCUDO ANIMADO
          ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.1).animate(
              CurvedAnimation(parent: _shieldController, curve: Curves.easeInOut),
            ),
            child: Image.asset(
              'assets/images/logo_escudo.png', 
              height: 150,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.shield, size: 120, color: Colors.blueAccent
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // CUADRO DE RESULTADO
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _statusColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: _statusColor, blurRadius: 15)],
            ),
            child: Center(
              child: Text(
                _statusText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 20),
          
          // BOTONES DE ACCIÓN
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _updateStatus(false),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade900),
                child: const Text("Test Limpio"),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _updateStatus(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
                child: const Text("Test Virus"),
              ),
            ],
          ),

          const SizedBox(height: 30),
          const Text("HISTORIAL DE VIGILANCIA", 
            style: TextStyle(color: Colors.blueAccent, fontSize: 12, letterSpacing: 2)),
          
          // LISTA DE HISTORIAL (OCUPA EL RESTO DE LA PANTALLA)
          Expanded(
            child: ListView.builder(
              itemCount: _history.length,
              padding: const EdgeInsets.all(20),
              itemBuilder: (context, index) {
                final item = _history[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: item["color"] == "red" ? Colors.red : Colors.green),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item["url"]!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(item["result"]!, 
                        style: TextStyle(
                          color: item["color"] == "red" ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold
                        )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}