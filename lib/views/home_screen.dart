import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _history = [];
  bool _isLoading = false;
  String _connectionStatus = "CONECTANDO...";
  Color _statusColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    setState(() {
      _isLoading = true;
    });
    final data = await _apiService.fetchHistory();
    setState(() {
      _history = data;
      _isLoading = false;
      if (data.isNotEmpty || _history.toString().contains('id')) {
        _connectionStatus = "PY-SERVER: CONECTADO";
        _statusColor = Colors.green;
      } else {
        _connectionStatus = "PY-SERVER: DESCONECTADO";
        _statusColor = Colors.red;
      }
    });
  }

  void _showScanModal(BuildContext context, String type) {
    final TextEditingController _inputController = TextEditingController();
    bool _isSending = false;

    String modalTitle = '🛡️ Escaneo Antimalware';
    String hintText = 'ejemplo_troyano.exe';
    String labelText = 'Ingrese el nombre o firma del archivo (.exe, .dll):';

    if (type == 'url') {
      modalTitle = '🌐 Análisis Antiphishing';
      hintText = 'https://banco-falso-login.com';
      labelText = 'Ingrese la URL sospechosa para evaluación:';
    } else if (type == 'phone') {
      modalTitle = '📞 Rastreador de Llamadas & Fraude';
      hintText = '+573001234567';
      labelText = 'Ingrese el número telefónico sospechoso:';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text(modalTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(labelText, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inputController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      hintText: hintText,
                      hintStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blueGrey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isSending ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: _isSending ? null : () async {
                    if (_inputController.text.trim().isEmpty) return;
                    setModalState(() { _isSending = true; });
                    final response = await _apiService.sendScan(type: type, target: _inputController.text.trim());
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Veredicto: ${response['verdict'] ?? 'Procesado'}'), backgroundColor: Colors.blueAccent),
                    );
                    _loadHistoryData();
                  },
                  child: _isSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Ejecutar Análisis', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('🛡️ JOSH SECURITY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: _statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: _statusColor)),
            child: Center(child: Text(_connectionStatus, style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.bold))),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: const [
                  Icon(Icons.gpp_good, color: Colors.greenAccent, size: 64),
                  SizedBox(height: 12),
                  Text(
                    'JOSH SECURITY: TU RESPALDO DIGITAL\nNUESTRA PRIORIDAD ERES TÚ', 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('🎛️ MÓDULOS DE PROTECCIÓN DISPONIBLES', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showScanModal(context, 'file'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: const [
                          Icon(Icons.bug_report, color: Colors.cyanAccent),
                          SizedBox(height: 6),
                          Text('Malware', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _showScanModal(context, 'url'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: const [
                          Icon(Icons.language, color: Colors.amberAccent),
                          SizedBox(height: 6),
                          Text('Phishing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _showScanModal(context, 'phone'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: const [
                          Icon(Icons.phone_in_talk, color: Colors.lightGreenAccent),
                          SizedBox(height: 6),
                          Text('Llamadas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _loadHistoryData,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: const [
                          Icon(Icons.sync, color: Colors.purpleAccent),
                          SizedBox(height: 6),
                          Text('Sincronizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // FILA CON TITULO DE LOGS Y BOTÓN FLOTANTE DE REPORTE PDF
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📋 AUDITORÍA DE EVENTOS FORENSES', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generando Reporte Forense PDF Oficial...'), backgroundColor: Colors.redAccent),
                    );
                    await _apiService.downloadPdfReport();
                  },
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 16),
                  label: const Text('Exportar PDF', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 12),

            _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty 
                    ? const Text('No hay eventos forenses registrados.', style: TextStyle(color: Colors.grey))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          final isFile = item['type'] == 'file';
                          final isPhone = item['type'] == 'phone';
                          final veredicto = (item['result'] ?? 'PROCESADO').toString().toUpperCase();
                          
                          bool tieneRiesgo = veredicto.contains('MALWARE') || veredicto.contains('PHISHING') || veredicto.contains('FRAUDE') || veredicto.contains('SOSPECHOSO');

                          IconData iconItem = Icons.link;
                          Color colorItem = Colors.amberAccent;
                          
                          if (isFile) {
                            iconItem = tieneRiesgo ? Icons.gavel : Icons.file_present;
                            colorItem = tieneRiesgo ? Colors.redAccent : Colors.cyanAccent;
                          } else if (isPhone) {
                            iconItem = tieneRiesgo ? Icons.phone_locked : Icons.phone_android;
                            colorItem = tieneRiesgo ? Colors.redAccent : Colors.lightGreenAccent;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B), 
                              borderRadius: BorderRadius.circular(8),
                              border: tieneRiesgo ? Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5) : null,
                            ),
                            child: ListTile(
                              leading: Icon(iconItem, color: colorItem, size: 28),
                              title: Text(
                                '[HISTORIAL ${item['type'].toString().toUpperCase()}]',
                                style: TextStyle(color: tieneRiesgo ? Colors.redAccent : Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['target'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text(item['vt_detail'] ?? item['result'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: tieneRiesgo ? Colors.red.withOpacity(0.15) : Colors.greenAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  veredicto,
                                  style: TextStyle(color: tieneRiesgo ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}