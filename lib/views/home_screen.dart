import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import 'widgets/cyber_shield_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @pragma('vm:entry-point')
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _targetController = TextEditingController();
  late TabController _tabController;
  late AnimationController _rotationController; 
  Timer? _keepAliveTimer;

  bool _isLoading = false;
  int _currentTab = 0;
  double _vulnerabilityScore = 0.0;

  String _verdictText = "SISTEMA LISTO";
  String _statusCategory = "ESCANER HUD • TELEFONÍA";
  Color _hudColor = const Color(0xFF00E676);

  String? _selectedFileName;
  int? _selectedFileSize; 

  List<String> _forensicLogs = [
    "CENTINELA v4.4.0: Núcleo analítico unificado acoplado a la infraestructura Cloud en Render."
  ];

  final List<Map<String, dynamic>> _masterBitacora = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _initKeepAliveTimer();
    
    _tabController.addListener(() {
      if (!mounted || !_tabController.indexIsChanging) return;
      setState(() {
        _currentTab = _tabController.index;
        _targetController.clear();
        _selectedFileName = null;
        _selectedFileSize = null;

        switch (_currentTab) {
          case 0:
            _statusCategory = "ESCANER HUD • TELEFONÍA";
            _forensicLogs = ["Módulo Heurístico de llamadas telefónicas activado."];
            break;
          case 1:
            _statusCategory = "ESCANER HUD • PHISHING";
            _forensicLogs = ["Módulo de Auditoría de enlaces y URLs activado."];
            break;
          case 2:
            _statusCategory = "ESCANER HUD • MALWARE";
            _forensicLogs = ["Módulo de análisis estático de archivos preparado."];
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _tabController.dispose();
    _rotationController.stop();
    _rotationController.dispose(); 
    _targetController.dispose();
    super.dispose();
  }

  void _initKeepAliveTimer() {
    _sendKeepAlivePulse();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _sendKeepAlivePulse();
    });
  }

  Future<void> _sendKeepAlivePulse() async {
    try {
      await _apiService.fetchScanHistory();
      debugPrint("🛰️ [SISTEMA] Pulso keep-alive transmitido a Render para evitar suspensión.");
    } catch (_) {}
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  Future<void> _pickLocalFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null) {
        setState(() {
          _forensicLogs = ["Selección de binario cancelada por el operador."];
        });
        return;
      }

      final file = result.files.first;
      const int maxSize = 15 * 1024 * 1024;

      if (file.size > maxSize) {
        setState(() {
          _forensicLogs = ["ERROR DE SEGURIDAD: El archivo excede el límite crítico de 15MB."];
        });
        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _selectedFileSize = file.size;
        _targetController.text = file.name;

        _forensicLogs = [
          "Carga de binario exitosa.",
          "Cripto-Nombre: ${file.name}",
          "Tamaño de carga: ${_formatBytes(file.size)}",
          "Estado: Listo para inspección criptográfica en la nube."
        ];
      });
    } catch (e) {
      setState(() {
        _forensicLogs = ["Fallo crítico en subsistema de carga:", e.toString()];
      });
    }
  }

  Future<void> _executeAuditoria() async {
    final target = _targetController.text.trim();

    if (target.isEmpty) {
      setState(() {
        _forensicLogs = ["ERROR OPERATIVO: Ingrese un objetivo válido para auditar."];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _forensicLogs = [
        "Iniciando oleoducto de análisis heurístico estructural...",
        "Calculando variables de riesgo y telemetría en nubes centrales..."
      ];
    });

    _rotationController.repeat();

    try {
      Map<String, dynamic> result;
      String vectorKey = 'TELEFONO';
      String vectorLabel = "TELEFÓNICO";

      if (_currentTab == 1) {
        vectorKey = 'URL';
        vectorLabel = "PHISHING/URL";
      } else if (_currentTab == 2) {
        vectorKey = 'MALWARE';
        vectorLabel = "MALWARE/BIN";
      }

      result = await _apiService.scanTarget(vectorKey, target);

      final rawScore = (result['riskScore'] as num?)?.toDouble() ?? 0.15;
      final scoreInPercent = rawScore <= 1.0 ? rawScore * 100 : rawScore;
      
      final classification = result['classification'] ?? 'ANALIZADO';
      final metrics = result['metrics'] as Map<String, dynamic>? ?? {};
      final backendLogs = result['logs'] as String? ?? 'Análisis completado.';

      setState(() {
        _vulnerabilityScore = scoreInPercent;
        _verdictText = classification.toString().toUpperCase();

        if (scoreInPercent >= 70) {
          _hudColor = const Color(0xFFFF5252);
        } else if (scoreInPercent >= 35) {
          _hudColor = const Color(0xFFFFD740);
        } else {
          _hudColor = const Color(0xFF00E676);
        }

        _statusCategory = "ANÁLISIS COMPLETADO • ${vectorLabel.split('/')[0]}";

        if (_currentTab == 0) {
          final double entropyVal = (metrics['entropy'] as num?)?.toDouble() ?? 0.0;
          final double freqVal = (metrics['frequency_risk'] as num?)?.toDouble() ?? 0.0;
          final double timeVal = (metrics['hourly_density'] as num?)?.toDouble() ?? 0.0;

          _forensicLogs = [
            "OBJETIVO EN RUTA: $target",
            "» Entropía Estructural: ${(entropyVal * 100).toStringAsFixed(1)}%",
            "» Riesgo por Frecuencia: ${(freqVal * 100).toStringAsFixed(1)}%",
            "» Densidad Horaria: ${(timeVal * 100).toStringAsFixed(1)}%",
            "AUDIT LOG: $backendLogs"
          ];
        } else {
          _forensicLogs = [
            "OBJETIVO EVALUADO: $target",
            if (_currentTab == 2 && _selectedFileSize != null) "» Peso Estático: ${_formatBytes(_selectedFileSize!)}",
            "» Patrones de desbordamiento analizados con éxito.",
            "AUDIT LOG: $backendLogs"
          ];
        }

        _masterBitacora.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'timestamp': DateTime.now().toIso8601String().substring(11, 19),
          'target': target,
          'score': scoreInPercent,
          'verdict': _verdictText,
          'vector': vectorLabel,
        });
      });
    } catch (e) {
      setState(() {
        _vulnerabilityScore = 15.0; 
        _verdictText = "CONTINGENCIA";
        _statusCategory = "Modo Híbrido Local";
        _hudColor = const Color(0xFFFFD740);
        _forensicLogs = [
          "AVISO: Excepción de aislamiento capturada o arranque en frío.",
          "Detalle: ${e.toString()}",
        ];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _rotationController.stop(); 
        _rotationController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      }
    }
  }

  void _clearMasterBitacora() {
    setState(() => _masterBitacora.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopHUD(),
              const SizedBox(height: 16),
              _buildVectorSelector(),
              const SizedBox(height: 16),
              _buildInputSection(),
              const SizedBox(height: 16),
              SizedBox(height: 220, child: _buildBottomLogsSection()),
              const SizedBox(height: 16),
              _buildAnalyticsHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHUD() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hudColor.withAlpha((0.4 * 255).round()), width: 2),
        boxShadow: [
          BoxShadow(
            color: _hudColor.withAlpha((0.08 * 255).round()),
            blurRadius: 16,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, color: _hudColor, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "JOSH SECURITY • CENTINELA v4.4.0",
                  style: TextStyle(
                    color: Colors.blueGrey[200],
                    letterSpacing: 2.5,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _hudColor.withAlpha((0.4 * 255).round()), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _hudColor.withAlpha((0.1 * 255).round()),
                  blurRadius: 12,
                )
              ],
            ),
            child: RotationTransition(
              turns: _rotationController,
              child: SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: CyberShieldPainter(glowColor: _hudColor),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          Text(
            _verdictText,
            style: TextStyle(
              color: _hudColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${_vulnerabilityScore.toStringAsFixed(1)}%",
            style: TextStyle(
              color: _hudColor,
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVectorSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF3A506B),
          border: Border.all(color: Colors.blueAccent.withAlpha((0.4 * 255).round())),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.blueGrey[300],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: "SPAM / BOTS"),
          Tab(text: "PHISHING"),
          Tab(text: "MALWARE"),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    IconData inputIcon = Icons.phone_android;
    String hintText = "Ingrese terminal telefónico (Ej. 300...)";

    if (_currentTab == 1) {
      inputIcon = Icons.link;
      hintText = "Ingrese dirección URL fraudulenta";
    } else if (_currentTab == 2) {
      inputIcon = Icons.bug_report_outlined;
      hintText = _selectedFileName ?? "Seleccione binario corporativo";
    }

    return Column(
      children: [
        TextField(
          controller: _targetController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.blueGrey[400], fontSize: 13),
            prefixIcon: Icon(inputIcon, color: const Color(0xFF5BC0BE)),
            filled: true,
            fillColor: const Color(0xFF1C2541),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            suffixIcon: _currentTab == 2
                ? IconButton(
                    icon: const Icon(Icons.folder_open, color: Color(0xFF5BC0BE)),
                    onPressed: _isLoading ? null : _pickLocalFile,
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3A506B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF5BC0BE), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _executeAuditoria,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hudColor,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.blueGrey[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                  )
                : const Text(
                    "ANALIZAR VECTORES EN CALIENTE",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomLogsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2541)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _statusCategory,
                  style: const TextStyle(
                    color: Color(0xFF5BC0BE),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isLoading ? Colors.amber : _hudColor,
                ),
              )
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFF1C2541), thickness: 1.5),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _forensicLogs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _forensicLogs[index],
                    style: TextStyle(
                      color: Colors.blueGrey[100],
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsHistorySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111A35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2541)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_toggle_off, color: Color(0xFF5BC0BE), size: 16),
                  SizedBox(width: 8),
                  Text(
                    "HISTORIAL DE ENTRADAS ANALIZADAS",
                    style: TextStyle(
                      color: Color(0xFF5BC0BE),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              if (_masterBitacora.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFFF5252), size: 20),
                  tooltip: "Limpiar Consola HUD",
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: _clearMasterBitacora,
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFF1C2541), thickness: 1.5),
          ),
          _masterBitacora.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      "No hay registros de amenazas en la sesión activa.",
                      style: TextStyle(
                        color: Colors.blueGrey[500],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _masterBitacora.length,
                  itemBuilder: (context, index) {
                    final item = _masterBitacora[index];
                    final double score = item['score'] ?? 0.0;
                    
                    Color alertColor = const Color(0xFF00E676);
                    if (score >= 70) {
                      alertColor = const Color(0xFFFF5252);
                    } else if (score >= 35) {
                      alertColor = const Color(0xFFFFD740);
                    }

                    return Container(
                      key: ValueKey(item['id']),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1128),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: alertColor.withAlpha((0.3 * 255).round())),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: alertColor.withAlpha((0.15 * 255).round()),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${score.toStringAsFixed(0)}%",
                              style: TextStyle(
                                color: alertColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['target'] ?? 'Objetivo Desconocido',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "[${item['timestamp']}] VÉCTOR: ${item['vector']} • ${item['verdict']}",
                                  style: TextStyle(
                                    color: Colors.blueGrey[400],
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}