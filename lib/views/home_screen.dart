import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _urlController = TextEditingController();
  
  String _scanType = 'phishing';
  bool _isLoading = false;
  bool _serverOnline = false;
  bool _showRealtimeAlert = false;
  
  Map<String, dynamic>? _lastAlertData;
  List<dynamic> _auditHistory = [];

  @override
  void initState() {
    super.initState();
    _initialSync();
  }

  Future<void> _initialSync() async {
    try {
      final handshake = await _apiService.checkHandshake();
      setState(() {
        _serverOnline = handshake != null;
      });
    } catch (e) {
      setState(() {
        _serverOnline = false;
      });
    }
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _apiService.fetchHistory();
      setState(() {
        _auditHistory = history;
      });
    } catch (e) {
      debugPrint("Error al cargar historial: $e");
    }
  }

  Future<void> _executeForensicScan() async {
    final targetText = _urlController.text.trim();
    if (targetText.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.scanTarget(_scanType, targetText);

      setState(() {
        _isLoading = false;
        if (response['verdict'] == 'PHISHING DETECTADO' || response['verdict'] == 'MALWARE DETECTADO') {
          _showRealtimeAlert = true;
          _lastAlertData = {
            'title': response['verdict'],
            'target': targetText,
            'module': _scanType == 'phishing' ? 'URL | Enfoque: Ingeniería Social' : 'Archivo | Enfoque: Código Malicioso'
          };
        } else {
          _showRealtimeAlert = false;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }

    _loadHistory();
    _urlController.clear();
  }

  void _clearScreenHistory() {
    setState(() {
      _auditHistory.clear();
      _showRealtimeAlert = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1527),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16223F),
        elevation: 4,
        title: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/images/logo_escudo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.shield, color: Color(0xFF38BDF8), size: 20);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'JOSH SECURITY',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _serverOnline ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _serverOnline ? Colors.greenAccent : Colors.redAccent),
            ),
            child: Center(
              child: Text(
                _serverOnline ? 'PY-SERVER ONLINE' : 'PY-SERVER OFFLINE',
                style: TextStyle(color: _serverOnline ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _initialSync,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // PRESENTACIÓN CENTRAL CON LOGO CORREGIDA (Línea 186 solucionada)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF16223F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/logo_escudo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.security, size: 50, color: Color(0xFF38BDF8));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "GLOBAL-CENTINELA",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                  Text(
                    "Core Security Suite v2.5",
                    style: TextStyle(color: const Color(0xFF38BDF8).withValues(alpha: 0.8), fontSize: 12),
                  ),
                ],
              ),
            ),

            if (_showRealtimeAlert && _lastAlertData != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A1619),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE53935)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gpp_bad, color: Color(0xFFE53935), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_lastAlertData!['title'] ?? 'AMENAZA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Objetivo: ${_lastAlertData!['target']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                      onPressed: () => setState(() => _showRealtimeAlert = false),
                    )
                  ],
                ),
              ),

            // CONTENEDOR MÓDULO PREVENTIVO
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF16223F), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Módulo Analítico Preventivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'phishing',
                        groupValue: _scanType,
                        activeColor: Colors.blueAccent,
                        onChanged: (val) => setState(() => _scanType = val!),
                      ),
                      const Text('Anti-Phishing', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'malware',
                        groupValue: _scanType,
                        activeColor: Colors.blueAccent,
                        onChanged: (val) => setState(() => _scanType = val!),
                      ),
                      const Text('Anti-Malware', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0D1527),
                      hintText: 'Ingresa la URL sospechosa...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.link, color: Colors.white54),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF536DFE)),
                      onPressed: _isLoading ? null : _executeForensicScan,
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lanzar Escaneo Forense', style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),

            // SECCIÓN HISTORIAL
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Auditoría Forense (${_auditHistory.length} Eventos)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_sweep, color: Colors.orangeAccent, size: 16),
                    label: const Text('Limpiar', style: TextStyle(color: Colors.orangeAccent)),
                    onPressed: _clearScreenHistory,
                  )
                ],
              ),
            ),

            Expanded(
              child: _auditHistory.isEmpty
                  ? const Center(child: Text('Vista limpia. Sin eventos.', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      itemCount: _auditHistory.length,
                      itemBuilder: (context, index) {
                        final item = _auditHistory[index];
                        return Card(
                          color: const Color(0xFF16223F),
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.verified_user, color: Colors.greenAccent),
                            title: Text(item['target'] ?? '', style: const TextStyle(color: Colors.white)),
                            subtitle: Text(item['result'] ?? '', style: const TextStyle(color: Colors.white70)),
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }
}