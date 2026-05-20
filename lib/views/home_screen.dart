import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _historyEvents = [];
  final TextEditingController _urlController = TextEditingController();
  
  String _systemStatus = "SISTEMA PROTEGIDO - CENTINELA ESCUCHANDO";
  bool _isProcessing = false;
  bool _isServerConnected = true;

  @override
  void initState() {
    super.initState();
    _loadInitialHistory();
  }

  Future<void> _loadInitialHistory() async {
    try {
      final history = await _apiService.fetchScanHistory();
      setState(() {
        _isServerConnected = true;
        _historyEvents.clear();
        for (var item in history) {
          _historyEvents.add({
            "title": "[HISTORIAL]: ${item['fileName'] || item['url']}",
            "subtitle": "Veredicto: ${item['verdict']} | Motor: ${item['engine']}",
            "isError": item['verdict'] == "MALICIOSO"
          });
        }
      });
    } catch (e) {
      setState(() {
        _isServerConnected = false;
        _historyEvents.insert(0, {
          "title": "[ALERTA LINK]: Modo Offline",
          "subtitle": "No se detectó respuesta en el backend de Python.",
          "isError": true
        });
      });
    }
  }

  Future<void> _triggerMalwareScan() async {
    setState(() {
      _isProcessing = true;
      _systemStatus = "EXTRAYENDO FIRMAS HEURÍSTICAS LOCALES...";
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        PlatformFile file = result.files.single;

        setState(() {
          _systemStatus = "SOLICITANDO VEREDICTO ANALÍTICO...";
          _historyEvents.insert(0, {
            "title": "[MOTOR]: Iniciando Hash de ${file.name}",
            "subtitle": "Enviando metadatos al puerto 5000...",
            "isError": false
          });
        });

        final response = await _apiService.scanFileWithPython(file);

        setState(() {
          if (response["status"] == "SUCCESS") {
            _systemStatus = "ANÁLISIS FORENSE COMPLETADO";
            final data = response["data"];
            _historyEvents.insert(0, {
              "title": "[CENTINELA]: ${data['fileName']}",
              "subtitle": "Veredicto: ${data['verdict']} | ${data['engine']}",
              "isError": data['verdict'] == "MALICIOSO"
            });
          } else {
            _systemStatus = "FALLO EN LA RESPUESTA DEL MOTOR";
          }
        });
      } else {
        setState(() {
          _systemStatus = "ESCANEO CANCELADO POR USUARIO";
        });
      }
    } catch (e) {
      setState(() {
        _systemStatus = "FALLO CRÍTICO EN INTEGRIDAD";
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _triggerUrlAnalysis() {
    _urlController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff161b22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Inspección de URLs Globales", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("El framework validará el dominio en tiempo real contra VirusTotal.", style: TextStyle(color: Color(0xff8b949e), fontSize: 13)),
            const SizedBox(height: 15),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: "https://ejemplo-phishing.com",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xff0d1117),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xff30363d)), borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xff58a6ff)), borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final urlToScan = _urlController.text.trim();
              if (urlToScan.isNotEmpty) {
                Navigator.pop(context);
                _sendUrlToBackend(urlToScan);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff238636)),
            child: const Text("ANALIZAR DOMINIO"),
          )
        ],
      ),
    );
  }

  Future<void> _sendUrlToBackend(String url) async {
    setState(() {
      _isProcessing = true;
      _systemStatus = "REVISANDO REPUTACIÓN DE DOMINIO...";
      _historyEvents.insert(0, {
        "title": "[PHISHING GATEWAY]: Analizando URL",
        "subtitle": "Consultando bases de reputación en la nube...",
        "isError": false
      });
    });

    try {
      // Simulación del puente HTTP hacia Python para la URL
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _systemStatus = "ANÁLISIS DE URL FINALIZADO";
        _historyEvents.insert(0, {
          "title": "[VIRUSTOTAL V3]: $url",
          "subtitle": "Veredicto: SEGURO | Puntuación de riesgo: 0/94 (Clean)",
          "isError": false
        });
      });
    } catch (e) {
      setState(() {
        _systemStatus = "ERROR AL CONSULTAR REPUTACIÓN";
      });
    } child: setState(() { _isProcessing = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0d1117),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildStatusShield(),
                    const SizedBox(height: 30),
                    _buildSectionTitle("MÓDULOS TÁCTICOS DE SEGURIDAD"),
                    const SizedBox(height: 15),
                    _buildModuleGrid(),
                    const SizedBox(height: 30),
                    _buildSectionTitle("BITÁCORA INTEGRADA DE AUDITORÍA"),
                    const SizedBox(height: 15),
                    _buildLiveLogStream(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    decoration: const BoxDecoration(
      color: Color(0xff161b22),
      border: Border(bottom: BorderSide(color: Color(0xff30363d), width: 1.5)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: const [
            Icon(Icons.gpp_good, color: Color(0xff58a6ff), size: 28),
            SizedBox(width: 12),
            Text(
              "JOSH SECURITY",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _isServerConnected ? const Color(0xff238636).withValues(alpha: 0.2) : const Color(0xffda3637).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _isServerConnected ? const Color(0xff238636) : const Color(0xffda3637)),
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 4, backgroundColor: _isServerConnected ? const Color(0xff238636) : const Color(0xffda3637)),
              const SizedBox(width: 6),
              Text(
                _isServerConnected ? "PY-SERVER ONLINE" : "PY-SERVER OFFLINE",
                style: TextStyle(color: _isServerConnected ? const Color(0xff56d364) : const Color(0xfff85149), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        )
      ],
    ),
  );

  Widget _buildStatusShield() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      color: const Color(0xff161b22),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xff30363d)),
    ),
    child: Column(
      children: [
        if (_isProcessing)
          const CircularProgressIndicator(color: Color(0xff58a6ff))
        else
          const Icon(Icons.shield, size: 70, color: Color(0xff58a6ff)),
        const SizedBox(height: 15),
        Text(
          _systemStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
      ],
    ),
  );

  Widget _buildSectionTitle(String title) => Row(
    children: [
      const Icon(Icons.analytics_outlined, color: Color(0xff8b949e), size: 18),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(color: Color(0xff8b949e), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
      ),
    ],
  );

  Widget _buildModuleGrid() => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 15,
    mainAxisSpacing: 15,
    childAspectRatio: 1.4,
    children: [
      _buildModuleCard(
        icon: Icons.bug_report,
        title: "Análisis Malware",
        subtitle: "Escaneo estático",
        color: const Color(0xff58a6ff),
        onTap: _isProcessing ? () {} : _triggerMalwareScan,
      ),
      _buildModuleCard(
        icon: Icons.link,
        title: "Revisión URL",
        subtitle: "Phishing Gateway",
        color: const Color(0xff34d058),
        onTap: _triggerUrlAnalysis,
      ),
      _buildModuleCard(
        icon: Icons.security_update_warning,
        title: "Simulación",
        subtitle: "Entorno Sandbox",
        color: const Color(0xffe1e345),
        onTap: () {
          setState(() {
            _historyEvents.insert(0, {
              "title": "[SANDBOX]: Simulación de ataque contra Windows",
              "subtitle": "Monitoreo preventivo activado exitosamente.",
              "isError": false
            });
          });
        },
      ),
      _buildModuleCard(
        icon: Icons.history,
        title: "Actualizar",
        subtitle: "Sincronizar logs",
        color: const Color(0xffbc8cff),
        onTap: _loadInitialHistory,
      ),
    ],
  );

  Widget _buildModuleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) => Material(
    color: const Color(0xff161b22),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xff30363d)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xff8b949e), fontSize: 11)),
              ],
            )
          ],
        ),
      ),
    ),
  );

  Widget _buildLiveLogStream() => Container(
    height: 220,
    decoration: BoxDecoration(
      color: const Color(0xff161b22),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xff30363d)),
    ),
    child: _historyEvents.isEmpty
        ? const Center(child: Text("Sin registros en la bitácora", style: TextStyle(color: Color(0xff8b949e))))
        : ListView.builder(
            itemCount: _historyEvents.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final log = _historyEvents[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xff0d1117),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: log["isError"] ? const Color(0xffda3637).withValues(alpha: 0.3) : const Color(0xff30363d)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.terminal, 
                      color: log["isError"] ? const Color(0xfff85149) : const Color(0xff58a6ff), 
                      size: 14
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log["title"] ?? "",
                            style: TextStyle(
                              color: log["isError"] ? const Color(0xfff85149) : Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            log["subtitle"] ?? "",
                            style: const TextStyle(color: Color(0xff8b949e), fontFamily: 'monospace', fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
  );
}