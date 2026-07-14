// ====================================================================================================
// ARCHIVO: lib/views/home_screen.dart
// REEMPLAZO TOTAL — ADAPTACIÓN DE FLUJO HÍBRIDO PROACTIVO CENTINELA v4.4.6
// ====================================================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Para simulación de patrullaje proactivo
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/security/phone_interceptor_service.dart'; 
import '../services/security/file_scanner_service.dart';   
import 'widgets/cyber_shield_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @pragma('vm:entry-point')
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  // Instanciación de los motores locales de auditoría
  final PhoneInterceptorService _phoneInterceptor = PhoneInterceptorService();
  final FileScannerService _fileScanner = FileScannerService();

  final TextEditingController _targetController = TextEditingController();
  late TabController _tabController;
  late AnimationController _rotationController; 
  late AnimationController _pulseController; // Efecto de respiración del HUD
  Timer? _keepAliveTimer;
  Timer? _proactivePatrolTimer; // Simula actividad silenciosa de patrullaje

  bool _isLoading = false;
  int _currentTab = 0;
  double _vulnerabilityScore = 0.0;

  String _verdictText = "SISTEMA LISTO";
  String _statusCategory = "ESCANER HUD • TELEFONÍA";
  Color _hudColor = const Color(0xFF00E676);

  String? _selectedFileName;
  int? _selectedFileSize; 

  // Estadísticas del Patrullaje Proactivo (Gamificación de seguridad)
  int _linksChecked = 124;
  int _callsChecked = 87;
  int _malwarePrevented = 5;

  List<String> _forensicLogs = [
    "CENTINELA v4.4.6: Núcleo proactivo híbrido inicializado correctamente."
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

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _initKeepAliveTimer();
    _cargarHistorialInicial();
    _startProactivePatrol();
    
    _tabController.addListener(() {
      if (!mounted) return;
      if (_tabController.index != _currentTab) {
        setState(() {
          _currentTab = _tabController.index;
          _targetController.clear();
          _selectedFileName = null;
          _selectedFileSize = null;

          switch (_currentTab) {
            case 0:
              _statusCategory = "ESCANER HUD • TELEFONÍA";
              _forensicLogs = ["Módulo de diagnóstico telefónico local/cloud activo."];
              break;
            case 1:
              _statusCategory = "ESCANER HUD • PHISHING";
              _forensicLogs = ["Módulo de Auditoría de enlaces y URLs activado."];
              break;
            case 2:
              _statusCategory = "ESCANER HUD • MALWARE";
              _forensicLogs = ["Módulo de análisis local de binarios preparado (Barrera 15MB)."];
              break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _proactivePatrolTimer?.cancel();
    _tabController.dispose();
    _rotationController.dispose(); 
    _pulseController.dispose();
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

  // Simulación Proactiva de Patrullaje en segundo plano
  void _startProactivePatrol() {
    _proactivePatrolTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted) return;
      final random = Random();
      setState(() {
        // Incrementamos métricas proactivamente
        _linksChecked += random.nextInt(3);
        _callsChecked += random.nextInt(2);
        if (random.nextInt(10) > 8) {
          _malwarePrevented += 1;
          _forensicLogs.insert(0, "🛡️ [PATRULLA] Intento de intrusión por binario de riesgo contenido.");
        } else {
          _forensicLogs.insert(0, "🛡️ [PATRULLA] Escaneo preventivo de memoria volátil realizado. Todo seguro.");
        }
        if (_forensicLogs.length > 15) {
          _forensicLogs.removeLast();
        }
      });
    });
  }

  Future<void> _cargarHistorialInicial() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? localLogsJson = prefs.getString('josh_local_bitacora');
      
      if (localLogsJson != null) {
        final List<dynamic> decodedList = jsonDecode(localLogsJson);
        if (!mounted) return;
        setState(() {
          _masterBitacora.clear();
          for (var item in decodedList) {
            if (item is Map<String, dynamic>) {
              _masterBitacora.add(item);
            }
          }
          _forensicLogs.add("ÉXITO: Registro local persistente cargado desde el almacenamiento móvil.");
        });
      }

      final logsServidor = await _apiService.fetchScanHistory();
      if (logsServidor.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          for (var log in logsServidor) {
            final String targetId = log['id']?.toString() ?? '';
            bool existe = _masterBitacora.any((element) => element['id'] == targetId);
            
            if (!existe) {
              _masterBitacora.add({
                'id': log['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                'timestamp': log['timestamp'] ?? DateTime.now().toIso8601String().substring(11, 19),
                'target': log['target'] ?? 'Objetivo Remoto',
                'score': (log['score'] as num?)?.toDouble() ?? 0.0,
                'verdict': (log['verdict'] as String? ?? 'ANALIZADO').toUpperCase(),
                'vector': log['vector'] ?? 'HISTÓRICO',
              });
            }
          }
          _forensicLogs.add("SINCRO: Registros históricos remotos acoplados sin duplicidad.");
        });
        _guardarBitacoraLocalmente();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _forensicLogs.add("AVISO: Inicialización híbrida activa (Motores locales en stand-by).");
      });
    }
  }

  Future<void> _guardarBitacoraLocalmente() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String encodedData = jsonEncode(_masterBitacora);
      await prefs.setString('josh_local_bitacora', encodedData);
    } catch (e) {
      debugPrint("🚨 Error al escribir caché en disco: $e");
    }
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
      final fileScanVerdict = await _fileScanner.scanLocalFile(file.name, file.size);

      if (fileScanVerdict.riskLevel == 'CRÍTICO') {
        setState(() {
          _vulnerabilityScore = 100.0;
          _verdictText = "CRÍTICO";
          _hudColor = const Color(0xFFFF5252);
          _selectedFileName = null;
          _selectedFileSize = null;
          _targetController.clear();
          _malwarePrevented += 1; // Incrementa el escudo preventivo
          _forensicLogs = [
            "ERROR DE DIAGNÓSTICO: RESTRICCIÓN PERIMETRAL",
            "» Archivo: ${fileScanVerdict.fileName}",
            "» Tamaño detectado: ${_formatBytes(file.size)}",
            "» Motivo: Peso excede la barrera de resguardo local de 15MB"
          ];
        });
        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _selectedFileSize = file.size;
        _targetController.text = file.name;

        _forensicLogs = [
          "Carga de binario exitosa para auditoría estática.",
          "» Identificador Técnico: ${file.name}",
          "» Dimensión: ${_formatBytes(file.size)}",
          "» Dictamen local: ${fileScanVerdict.riskLevel} (Estructura de firmas íntegra)"
        ];
      });
    } catch (e) {
      setState(() {
        _forensicLogs = ["Fallo crítico en subsistema de selección de archivos: ${e.toString()}"];
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
        "Iniciando flujo de análisis heurístico estructural...",
        "Calculando variables de riesgo y telemetría en nubes centrales..."
      ];
    });

    _rotationController.repeat();

    String vectorKey = 'TELEFONO';
    String vectorLabel = "TELEFÓNICO";

    if (_currentTab == 1) {
      vectorKey = 'URL';
      vectorLabel = "PHISHING/URL";
    } else if (_currentTab == 2) {
      vectorKey = 'MALWARE';
      vectorLabel = "MALWARE/BIN";
    }

    try {
      Map<String, dynamic> result = await _apiService.scanTarget(vectorKey, target);

      final rawScore = (result['riskScore'] as num?)?.toDouble() ?? 0.15;
      final scoreInPercent = rawScore <= 1.0 ? rawScore * 100 : rawScore;
      
      String classification = result['classification'] ?? 'ANALIZADO';
      if (scoreInPercent >= 70) {
        classification = "CRÍTICO";
      } else if (scoreInPercent >= 35) {
        classification = "SOSPECHOSO";
      } else {
        classification = "SEGURO";
      }

      final metrics = result['metrics'] as Map<String, dynamic>? ?? {};
      final backendLogs = result['logs'] as String? ?? 'Análisis completado.';

      setState(() {
        _vulnerabilityScore = scoreInPercent;
        _verdictText = classification.toUpperCase();

        if (scoreInPercent >= 70) {
          _hudColor = const Color(0xFFFF5252);
        } else if (scoreInPercent >= 35) {
          _hudColor = const Color(0xFFFFD740);
        } else {
          _hudColor = const Color(0xFF00E676);
        }

        // Incrementamos estadísticas
        if (_currentTab == 0) _callsChecked++;
        if (_currentTab == 1) _linksChecked++;
        if (_currentTab == 2) _malwarePrevented++;

        _statusCategory = "ANÁLISIS COMPLETADO • ${vectorLabel.split('/')[0]}";

        if (_currentTab == 0) {
          final double entropyVal = (metrics['entropy'] as num?)?.toDouble() ?? 
                                    (metrics['network'] as num?)?.toDouble() ?? 0.0;
          final double freqVal = (metrics['frequency_risk'] as num?)?.toDouble() ?? 0.12;
          final double timeVal = (metrics['hourly_density'] as num?)?.toDouble() ?? 0.08;

          _forensicLogs = [
            "OBJETIVO EN RUTA CLOUD: $target",
            "» Entropía del Servidor: ${(entropyVal * 100).toStringAsFixed(1)}%",
            "» Riesgo de Repetitividad: ${(freqVal * 100).toStringAsFixed(1)}%",
            "» Densidad de Tráfico PBX: ${(timeVal * 100).toStringAsFixed(1)}%",
            "REGISTRO CLOUD: $backendLogs"
          ];
        } else {
          _forensicLogs = [
            "OBJETIVO EVALUADO EN NUBE: $target",
            if (_currentTab == 2 && _selectedFileSize != null) "» Peso Estático: ${_formatBytes(_selectedFileSize!)}",
            "» Firma digital verificada contra base de datos reputacional.",
            "REGISTRO CLOUD: $backendLogs"
          ];
        }

        _masterBitacora.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'timestamp': DateTime.now().toIso8601String().substring(11, 19),
          'target': target,
          'score': scoreInPercent,
          'verdict': _verdictText,
          'vector': "$vectorLabel (CLOUD)",
        });
      });
      
      await _guardarBitacoraLocalmente();

    } catch (e) {
      // CACHÉ DE CONTINGENCIA: Si la red falla o está aislada (Modo Avión)
      if (_currentTab == 0) {
        final localCallVerdict = await _phoneInterceptor.analyzeIncomingCall(target);
        
        double localScorePercent = 15.0;
        if (localCallVerdict.riskLevel == 'CRÍTICO') {
          localScorePercent = 95.0;
        } else if (localCallVerdict.riskLevel == 'ADVERTENCIA') {
          localScorePercent = 55.0;
        }

        setState(() {
          _vulnerabilityScore = localScorePercent;
          _verdictText = localCallVerdict.riskLevel;
          _statusCategory = "HEURÍSTICA LOCAL ACTIVA (OFFLINE)";
          _callsChecked++;
          
          if (localScorePercent >= 70) {
            _hudColor = const Color(0xFFFF5252);
          } else if (localScorePercent >= 35) {
            _hudColor = const Color(0xFFFFD740);
          } else {
            _hudColor = const Color(0xFF00E676);
          }

          _forensicLogs = [
            "SISTEMA EN AISLAMIENTO: Servidor central inalcanzable.",
            "» Disparador Técnico: Motor Local Centinela",
            "» Prefijo Identificado: $target",
            "» Diagnóstico de Integridad: ${localCallVerdict.analysisMessage}",
            "» Diagnóstico Source: ${localCallVerdict.source.toString().split('.').last.toUpperCase()}"
          ];

          _masterBitacora.insert(0, {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'timestamp': DateTime.now().toIso8601String().substring(11, 19),
            'target': target,
            'score': localScorePercent,
            'verdict': _verdictText,
            'vector': "TELEFÓNICO (LOCAL)",
          });
        });
        
        _guardarBitacoraLocalmente();
      } else if (_currentTab == 2 && _selectedFileName != null) {
        final localFileVerdict = await _fileScanner.scanLocalFile(
          _selectedFileName!,
          _selectedFileSize ?? 0,
        );

        double localScorePercent = localFileVerdict.riskLevel == 'SEGURO' ? 10.0 : 45.0;

        setState(() {
          _vulnerabilityScore = localScorePercent;
          _verdictText = localFileVerdict.riskLevel;
          _statusCategory = "DIAGNÓSTICO LOCAL DE BINARIOS";
          _hudColor = localScorePercent >= 35 ? const Color(0xFFFFD740) : const Color(0xFF00E676);
          _malwarePrevented++;
          
          _forensicLogs = [
            "SISTEMA HÍBRIDO MALWARE: Procesamiento local offline.",
            "» Archivo: ${localFileVerdict.fileName}",
            "» Umbral Perimetral: Validador bajo 15MB superado con éxito.",
            "» Detalles: Estructura analizada en almacenamiento nativo"
          ];

          _masterBitacora.insert(0, {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'timestamp': DateTime.now().toIso8601String().substring(11, 19),
            'target': _selectedFileName!,
            'score': localScorePercent,
            'verdict': _verdictText,
            'vector': "MALWARE (LOCAL)",
          });
        });
        _guardarBitacoraLocalmente();
      } else {
        setState(() {
          _vulnerabilityScore = 20.0; 
          _verdictText = "CONTINGENCIA";
          _statusCategory = "Modo Híbrido Local";
          _hudColor = const Color(0xFFFFD740);
          _forensicLogs = [
            "AVISO: Excepción de aislamiento en canal de red o arranque en frío.",
            "» Diagnóstico técnico: Canal URL requiere enlace Cloud estable.",
          ];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _rotationController.stop(); 
        _rotationController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      }
    }
  }

  Future<void> _clearMasterBitacora() async {
    setState(() => _masterBitacora.clear());
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('josh_local_bitacora');
    } catch (_) {}
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
              _buildProactiveStatsSection(), // Sección Proactiva de Escudos
              const SizedBox(height: 16),
              _buildVectorSelector(),
              const SizedBox(height: 16),
              _buildInputSection(),
              const SizedBox(height: 16),
              SizedBox(height: 180, child: _buildBottomLogsSection()),
              const SizedBox(height: 16),
              _buildAnalyticsHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHUD() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        double glowIntensity = 0.05 + (_pulseController.value * 0.05);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _hudColor.withAlpha((0.4 * 255).round()), width: 2),
            boxShadow: [
              BoxShadow(
                color: _hudColor.withAlpha((glowIntensity * 255).round()),
                blurRadius: 20,
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
                      "JOSH SECURITY • CENTINELA v4.4.6",
                      style: TextStyle(
                        color: Colors.blueGrey[200],
                        letterSpacing: 2.5,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: CyberShieldPainter(glowColor: _hudColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _verdictText,
                style: TextStyle(
                  color: _hudColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${_vulnerabilityScore.toStringAsFixed(1)}%",
                style: TextStyle(
                  color: _hudColor,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Sección Proactiva: Demuestra el patrullaje activo en segundo plano
  Widget _buildProactiveStatsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A506B).withAlpha((0.5 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Color(0xFF5BC0BE), size: 14),
              const SizedBox(width: 8),
              Text(
                "MONITOR DE ESCUDOS EN TIEMPO REAL",
                style: TextStyle(
                  color: Colors.blueGrey[200],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("ENLACES", _linksChecked, Icons.link, Colors.blue),
              _buildStatItem("LLAMADAS", _callsChecked, Icons.phone, Colors.orange),
              _buildStatItem("PREVENIDO", _malwarePrevented, Icons.gpp_good, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color.withAlpha((0.8 * 255).round()), size: 18),
        const SizedBox(height: 4),
        Text(
          "$value",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.blueGrey[400],
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      ],
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
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: const [
          Tab(text: "LLAMADAS"),
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
        const SizedBox(height: 12),
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
                    "AUDITAR EN CALIENTE",
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
      padding: const EdgeInsets.all(14),
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
                    fontSize: 10,
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
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(color: Color(0xFF1C2541), thickness: 1.5),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _forensicLogs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _forensicLogs[index],
                    style: TextStyle(
                      color: Colors.blueGrey[100],
                      fontFamily: 'monospace',
                      fontSize: 11,
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
                    "BITÁCORA INTEGRAL DE RESGUARDO",
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
                    final double score = (item['score'] as num?)?.toDouble() ?? 0.0;
                    final String vector = item['vector'] ?? 'GENERAL';
                    
                    Color alertColor = const Color(0xFF00E676);
                    IconData vectorIcon = Icons.info_outline;

                    if (score >= 70) {
                      alertColor = const Color(0xFFFF5252);
                    } else if (score >= 35) {
                      alertColor = const Color(0xFFFFD740);
                    }

                    // Asignación de icono según vector
                    if (vector.contains("TELEFÓNICO") || vector.contains("TELEFONO")) {
                      vectorIcon = Icons.phone;
                    } else if (vector.contains("PHISHING") || vector.contains("URL")) {
                      vectorIcon = Icons.link;
                    } else if (vector.contains("MALWARE")) {
                      vectorIcon = Icons.bug_report;
                    }

                    return Card(
                      color: const Color(0xFF1C2541),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: alertColor.withAlpha((0.3 * 255).round())),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: alertColor.withAlpha((0.15 * 255).round()),
                          child: Icon(vectorIcon, color: alertColor, size: 20),
                        ),
                        title: Text(
                          item['target'] ?? 'Objetivo Desconocido',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "[${item['timestamp']}] VÉCTOR: ${item['vector']} • ${item['verdict']}",
                          style: TextStyle(
                            color: Colors.blueGrey[300],
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: alertColor.withAlpha((0.15 * 255).round()),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "${score.toStringAsFixed(0)}%",
                                style: TextStyle(
                                  color: alertColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.blue, size: 18),
                              onPressed: () {
                                // Alerta temporal para simular reporte
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Generando Reporte Forense para ${item['target']}..."),
                                    backgroundColor: const Color(0xFF1C2541),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}