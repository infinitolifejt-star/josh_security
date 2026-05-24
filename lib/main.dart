import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'components/logo_animado.dart';
import 'components/banner_alerta.dart';
import 'components/modulo_escaneo.dart';

void main() {
  runApp(const JoshSecurityApp());
}

class JoshSecurityApp extends StatelessWidget {
  const JoshSecurityApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JOSH SECURITY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        cardColor: const Color(0xFF1E293B), // Slate 800
        primaryColor: const Color(0xFF6366F1), // Indigo 500
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _targetController = TextEditingController();
  
  String _scanType = 'url';
  bool _isLoading = false;
  Map<String, dynamic>? _lastVerdict;
  List<dynamic> _history = [];

  Map<String, dynamic>? _activeCriticalAlert;
  String? _lastDismissedTarget; 

  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final historyData = await _apiService.fetchHistory();
      setState(() {
        _history = historyData;
        _evaluateLatestThreatsForAlert(historyData);
      });
    } catch (e) {
      _showSnackBar('❌ Error de sincronización con el Core: $e', Colors.redAccent);
    }
  }

  void _evaluateLatestThreatsForAlert(List<dynamic> historyLog) {
    if (historyLog.isEmpty) return;
    
    final threat = historyLog.firstWhere(
      (element) {
        final v = element['result']?.toString() ?? '';
        return v.contains('CRÍTICO') || v.contains('DETECTADO');
      },
      orElse: () => null,
    );
    
    if (threat != null) {
      final threatTarget = threat['target'] ?? '';
      if (_lastDismissedTarget == threatTarget) return;

      setState(() {
        _activeCriticalAlert = {
          'type': threat['type']?.toString().toUpperCase() ?? 'AMENAZA',
          'target': threatTarget,
          'verdict': threat['result'] ?? 'AMENAZA DETECTADA',
          'date': threat['date'] ?? 'Ahora'
        };
      });
    } else {
      setState(() {
        _activeCriticalAlert = null;
      });
    }
  }

  Future<void> _executeScan() async {
    final targetText = _targetController.text.trim();
    if (targetText.isEmpty) {
      _showSnackBar('⚠️ Por favor ingresa un objetivo válido para el análisis.', Colors.amber);
      return;
    }

    setState(() {
      _isLoading = true;
      _lastVerdict = null;
    });

    try {
      final response = await _apiService.scanTarget(_scanType, targetText);
      setState(() {
        _lastVerdict = response;
      });

      final verdict = response['verdict']?.toString() ?? '';
      if (verdict.contains('CRÍTICO') || verdict.contains('DETECTADO') || verdict.contains('SOSPECHOSO')) {
        _lastDismissedTarget = null; 
        setState(() {
          _activeCriticalAlert = {
            'type': _scanType.toUpperCase(),
            'target': targetText,
            'verdict': verdict,
            'date': 'Ahora mismo'
          };
        });
        _showSnackBar('🚨 ALERTA: ¡Amenaza detectada en el vector analizado!', Colors.redAccent);
      } else {
        _showSnackBar('✅ Análisis completado. Objetivo limpio y seguro.', Colors.green);
      }

      await _loadHistory();
    } catch (e) {
      _showSnackBar('❌ Error en el motor analítico: $e', Colors.redAccent);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAuditHistory() async {
    setState(() { _isLoading = true; });
    try {
      setState(() {
        _history.clear();
        _activeCriticalAlert = null;
        _lastDismissedTarget = null;
        _lastVerdict = null;
      });
      _showSnackBar('🧹 Panel de Auditoría Forense vaciado con éxito.', Colors.amber);
    } catch (e) {
      _showSnackBar('❌ Error al limpiar registros: $e', Colors.redAccent);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _exportPdfReport() async {
    _showSnackBar('⏳ Compilando Reporte Forense PDF binario...', const Color(0xFF3B82F6));
    try {
      await _apiService.downloadPdfReport();
      _showSnackBar('📥 Reporte PDF descargado automáticamente.', Colors.green);
    } catch (e) {
      _showSnackBar('❌ Error al compilar el documento PDF: $e', Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 4,
        title: Row(
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.4), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/logo_escudo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, color: Color(0xFF818CF8), size: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('GLOBAL-CENTINELA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF818CF8)),
            onPressed: () {
              setState(() { _lastDismissedTarget = null; });
              _loadHistory();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📡 1. Componente de Logo 3D Modularizado
            LogoAnimado(rotationController: _rotationController),

            // 🚨 2. Componente de Banner de Alerta Crítica Modularizado
            if (_activeCriticalAlert != null)
              BannerAlerta(
                activeCriticalAlert: _activeCriticalAlert!,
                onExportPdf: _exportPdfReport,
                onClose: () {
                  setState(() {
                    _lastDismissedTarget = _activeCriticalAlert!['target'];
                    _activeCriticalAlert = null;
                  });
                },
              ),

            // 🎛️ 3. Componente de Entrada de Datos Modularizado
            ModuloEscaneo(
              scanType: _scanType,
              targetController: _targetController,
              isLoading: _isLoading,
              onTypeChanged: (newType) => setState(() => _scanType = newType),
              onExecuteScan: _executeScan,
              onExportPdf: _exportPdfReport,
            ),
            const SizedBox(height: 24),

            // Vista del Veredicto Directo
            if (_lastVerdict != null) ...[
              const Text('Resultado del Análisis Directo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lastVerdict!['verdict'].toString().contains('LIMPIO') || _lastVerdict!['verdict'].toString().contains('SEGURO')
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _lastVerdict!['verdict'].toString().contains('LIMPIO') || _lastVerdict!['verdict'].toString().contains('SEGURO')
                        ? Colors.green
                        : Colors.red,
                    width: 1
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Veredicto: ${_lastVerdict!['verdict']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Detalle: ${_lastVerdict!['detail']}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Panel de Historial de Auditoría Forense
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Auditoría de Eventos Forenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Row(
                  children: [
                    Text('${_history.length} Eventos', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _history.isEmpty ? null : _clearAuditHistory,
                      icon: const Icon(Icons.delete_sweep, size: 16),
                      label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: Colors.amberAccent, disabledForegroundColor: Colors.white24),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _history.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.folder_open, color: Colors.white24, size: 40),
                          SizedBox(height: 8),
                          Text('Vista limpia. Sin eventos forenses en memoria.', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final verdict = item['result'] ?? 'INFO';
                      
                      Color alertColor = Colors.green;
                      if (verdict.contains('CRÍTICO') || verdict.contains('DETECTADO')) {
                        alertColor = Colors.redAccent;
                      } else if (verdict.contains('SOSPECHOSO') || verdict.contains('NUEVO')) {
                        alertColor = Colors.amber;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: alertColor.withValues(alpha: 0.5), width: 1),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: alertColor.withValues(alpha: 0.1),
                            child: Icon(
                              item['type'] == 'url' ? Icons.link : item['type'] == 'file' ? Icons.insert_drive_file : Icons.phone,
                              color: alertColor,
                              size: 20,
                            ),
                          ),
                          title: Text(item['target'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Resultado: $verdict', style: TextStyle(color: alertColor, fontWeight: FontWeight.w600, fontSize: 12)),
                              if (item['vt_detail'] != null && item['vt_detail'].toString().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(item['vt_detail'], style: const TextStyle(fontSize: 11, color: Colors.white54)),
                              ],
                              const SizedBox(height: 4),
                              Text('Fecha: ${item['date']}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                            ],
                          ),
                          trailing: const Icon(Icons.shield, size: 16, color: Colors.white24),
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