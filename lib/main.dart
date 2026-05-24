import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'services/api_service.dart';

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

  // Variables del Sistema de Alertas Tempranas Avanzado
  Map<String, dynamic>? _activeCriticalAlert;
  String? _lastDismissedTarget; 

  // Controlador de Animación para el Giro Continuo Realista del Escudo
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    
    // Configuración del motor de rotación constante y suave
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
      
      if (_lastDismissedTarget == threatTarget) {
        return;
      }

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
    setState(() {
      _isLoading = true;
    });
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
      setState(() {
        _isLoading = false;
      });
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
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.shield, color: Color(0xFF818CF8), size: 18);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'GLOBAL-CENTINELA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF818CF8)),
            tooltip: 'Sincronizar Historial',
            onPressed: () {
              setState(() {
                _lastDismissedTarget = null;
              });
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
            
            // 🔥 NUEVA PRESENTACIÓN CENTRAL ULTRA-ESTÉTICA CON LOGO GIGANTE Y GIRO ANTI-ESPEJO
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF111827)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Motor de Renderizado 3D con Corrección de Matriz Espejo
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      // Calculamos el ángulo actual en radianes
                      final double angle = _rotationController.value * 2 * math.pi;
                      
                      // Evaluamos si el widget está de espaldas (entre 90 y 270 grados)
                      final bool isBackside = angle % (2 * math.pi) > math.pi / 2 && angle % (2 * math.pi) < 3 * math.pi / 2;

                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0015) // Perspectiva de profundidad 3D
                          ..rotateY(angle), // Rotación sobre el eje Y
                        alignment: Alignment.center,
                        child: Container(
                          height: 180, // Subimos el tamaño para darle total protagonismo
                          width: 180,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                blurRadius: 25,
                                spreadRadius: 5,
                              )
                            ]
                          ),
                          // Si está de espaldas, aplicamos una contra-rotación interna para enderezar las letras
                          child: Transform(
                            transform: isBackside ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
                            alignment: Alignment.center,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/logo_escudo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.security, size: 100, color: Color(0xFF818CF8));
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "JOSH SECURITY SYSTEM",
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 22, // Más grande e imponente
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 1.8,
                      shadows: [
                        Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4),
                      ]
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      "🛡️ Core Security Suite v2.5",
                      style: TextStyle(color: Color(0xFF818CF8), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // 🚨 REAL-TIME PUSH NOTIFICATION BANNER UI
            if (_activeCriticalAlert != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF991B1B), Color(0xFF7F1D1D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.red.shade900,
                      child: const Icon(Icons.gpp_bad, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠️ ADVERTENCIA CRÍTICA EN TIEMPO REAL',
                            style: TextStyle(color: Colors.red.shade100, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_activeCriticalAlert!['verdict']}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Módulo: ${_activeCriticalAlert!['type']} | Objetivo: ${_activeCriticalAlert!['target']}',
                            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _exportPdfReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.redAccent),
                      label: const Text('Auditar'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () {
                        setState(() {
                          _lastDismissedTarget = _activeCriticalAlert!['target'];
                          _activeCriticalAlert = null;
                        });
                      },
                    )
                  ],
                ),
              ),
            ],

            // PANEL CONTROL: SELECCIÓN DE VECTORES Y ENTRADA
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Módulo Analítico Preventivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _buildTypeRadio('url', '🌐 Anti-Phishing'),
                          const SizedBox(width: 16),
                          _buildTypeRadio('file', '📁 Anti-Malware'),
                          const SizedBox(width: 16),
                          _buildTypeRadio('phone', '📞 Anti-Fraud'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _targetController,
                      decoration: InputDecoration(
                        hintText: _scanType == 'url' 
                            ? 'Ingresa la URL sospechosa...' 
                            : _scanType == 'file' 
                                ? 'Nombre del archivo con extensión...' 
                                : 'Número telefónico (ej: +573...)',
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        prefixIcon: Icon(
                          _scanType == 'url' ? Icons.link : _scanType == 'file' ? Icons.insert_drive_file : Icons.phone,
                          color: const Color(0xFF818CF8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _executeScan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isLoading 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Lanzar Escaneo Forense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _exportPdfReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            side: const BorderSide(color: Color(0xFF334155)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 18),
                          label: const Text('Exportar PDF'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // VISTA RESUMIDA DE LA ÚLTIMA OPERACIÓN
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

            // SECCIÓN DE AUDITORÍA HISTÓRICA DE LOGS
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
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amberAccent,
                        disabledForegroundColor: Colors.white24,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.delete_sweep, size: 16),
                      label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
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

  Widget _buildTypeRadio(String value, String label) {
    return InkWell(
      onTap: () {
        setState(() {
          _scanType = value;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: _scanType,
            activeColor: const Color(0xFF818CF8),
            onChanged: (String? newValue) {
              setState(() {
                _scanType = newValue!;
              });
            },
          ),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}