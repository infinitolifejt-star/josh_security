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
  
  String _systemStatus = "SISTEMA PROTEGIDO - ESCUCHANDO PETICIONES";
  bool _isProcessing = false;
  bool _isServerConnected = false;

  @override
  void initState() {
    super.initState();
    _syncWithBackend();
  }

  // Sincronización en vivo con mapeo de cadenas dinámicas
  Future<void> _syncWithBackend() async {
    try {
      final history = await _apiService.fetchScanHistory();
      setState(() {
        _isServerConnected = true;
        _systemStatus = "SISTEMA PROTEGIDO - ESCUCHANDO PETICIONES";
        _historyEvents.clear();
        
        for (var item in history) {
          if (item == null || item is! Map) continue;
          
          final Map<String, dynamic> safeItem = Map<String, dynamic>.from(item);
          
          // Extracción dinámica de metadatos reales del servidor
          final String targetName = safeItem['fileName'] != null 
              ? safeItem['fileName'].toString() 
              : "Objeto Indefinido";
              
          final bool isUrl = targetName.startsWith("URL:");
          final String verdict = safeItem['verdict'] != null ? safeItem['verdict'].toString() : "SEGURO";
          final String engine = safeItem['engine'] != null ? safeItem['engine'].toString() : "Centinela Core";

          _historyEvents.add({
            "title": isUrl ? "[HISTORIAL URL]" : "[HISTORIAL FILE]",
            "subtitle": "$targetName | Veredicto: $verdict | $engine",
            "isError": verdict == "MALICIOSO"
          });
        }
      });
    } catch (e) {
      setState(() {
        _isServerConnected = false;
        _systemStatus = "MODO DE FALLO: CONTROLADOR PYTHON DESCONECTADO";
      });
    }
  }

  // Módulo de análisis estático
  Future<void> _triggerMalwareScan() async {
    setState(() {
      _isProcessing = true;
      _systemStatus = "CAPTURED: EXAMINANDO ESTRUCTURA DE ARCHIVO...";
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        PlatformFile file = result.files.single;

        setState(() {
          _systemStatus = "TRANSMITIENDO PAYLOAD A PUERTO 5000...";
        });

        await _apiService.scanFileWithPython(file);
        setState(() {
          _systemStatus = "ANÁLISIS DE MALWARE CONCLUIDO";
        });
      } else {
        setState(() {
          _systemStatus = "OPERACIÓN ABORTADA POR EL OPERADOR";
        });
      }
    } catch (e) {
      setState(() {
        _systemStatus = "EXCEPCIÓN EN EL MOTOR ANALÍTICO";
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
      _syncWithBackend();
    }
  }

  // Módulo de URLs Globales
  void _triggerUrlAnalysis() {
    _urlController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff161b22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.link, color: Color(0xff34d058)),
            SizedBox(width: 10),
            Text("Gateway Antiphishing", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ingrese el dominio sospechoso para someterlo a auditoría externa:", style: TextStyle(color: Color(0xff8b949e), fontSize: 13)),
            const SizedBox(height: 15),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: "https://secure-login-bank.com",
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
            child: const Text("ABORTAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final targetUrl = _urlController.text.trim();
              if (targetUrl.isNotEmpty) {
                Navigator.pop(context);
                _sendUrlToBackend(targetUrl);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff238636)),
            child: const Text("INSPECCIONAR"),
          )
        ],
      ),
    );
  }

  Future<void> _sendUrlToBackend(String targetUrl) async {
    setState(() {
      _isProcessing = true;
      _systemStatus = "REQUIRIENDO INTELIGENCIA DE AMENAZAS...";
    });

    try {
      await _apiService.scanUrlWithPython(targetUrl);
      setState(() {
        _systemStatus = "ANÁLISIS DE ENLACE COMPLETADO";
      });
    } catch (e) {
      setState(() {
        _systemStatus = "EXCEPCIÓN EN EL ENLACE CLOUD";
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
      _syncWithBackend();
    }
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
                    _buildSectionTitle("MÓDULOS ACTIVOS DE PROTECCIÓN"),
                    const SizedBox(height: 15),
                    _buildModuleGrid(),
                    const SizedBox(height: 30),
                    _buildSectionTitle("AUDITORÍA DE EVENTOS FORENSES (PYTHON LOGS)"),
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
        const Row(
          children: [
            Icon(Icons.security, color: Color(0xff58a6ff), size: 28),
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
            color: _isServerConnected ? const Color(0xff238636).withOpacity(0.1) : const Color(0xffda3637).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _isServerConnected ? const Color(0xff238636) : const Color(0xffda3637)),
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 4, backgroundColor: _isServerConnected ? const Color(0xff238636) : const Color(0xffda3637)),
              const SizedBox(width: 6),
              Text(
                _isServerConnected ? "PY-SERVER: CONECTADO" : "PY-SERVER: DESCONECTADO",
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
          Icon(Icons.gpp_good, size: 70, color: _isServerConnected ? const Color(0xff56d364) : const Color(0xfff85149)),
        const SizedBox(height: 15),
        Text(
          _systemStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
      ],
    ),
  );

  Widget _buildSectionTitle(String title) => Row(
    children: [
      const Icon(Icons.terminal, color: Color(0xff8b949e), size: 16),
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
        subtitle: "Estructura Estática",
        color: const Color(0xff58a6ff),
        onTap: _isProcessing || !_isServerConnected ? () {} : _triggerMalwareScan,
      ),
      _buildModuleCard(
        icon: Icons.public,
        title: "Revisión URL",
        subtitle: "Filtro Reputación",
        color: const Color(0xff34d058),
        onTap: _isProcessing || !_isServerConnected ? () {} : _triggerUrlAnalysis,
      ),
      _buildModuleCard(
        icon: Icons.biotech,
        title: "Sandbox Mode",
        subtitle: "Aislamiento Local",
        color: const Color(0xffe1e345),
        onTap: () {
          setState(() {
            _historyEvents.insert(0, {
              "title": "[SANDBOX INTERN] Activo",
              "subtitle": "Ambiente virtual de contención desplegado.",
              "isError": false
            });
          });
        },
      ),
      _buildModuleCard(
        icon: Icons.sync,
        title: "Sincronizar",
        subtitle: "Forzar Handshake",
        color: const Color(0xffbc8cff),
        onTap: _syncWithBackend,
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
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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
        ? const Center(child: Text("Esperando telemetría del servidor...", style: TextStyle(color: Color(0xff8b949e), fontFamily: 'monospace', fontSize: 12)))
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
                  border: Border.all(color: log["isError"] ? const Color(0xffda3637).withOpacity(0.3) : const Color(0xff30363d)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.output, color: log["isError"] ? const Color(0xfff85149) : const Color(0xff58a6ff), size: 13),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log["title"] ?? "",
                            style: TextStyle(color: log["isError"] ? const Color(0xfff85149) : Colors.white, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
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