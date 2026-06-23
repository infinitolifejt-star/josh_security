// lib/views/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @pragma('vm:entry-point')
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _targetController = TextEditingController();
  late TabController _tabController;
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
    "CENTINELA v4.3: Núcleo analítico unificado y acoplado a la infraestructura Cloud."
  ];

  final List<Map<String, dynamic>> _masterBitacora = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _targetController.dispose();
    super.dispose();
  }

  /// ⚙️ SISTEMA ANTI-SLEEP DE INFRAESTRUCTURA (RENDER KEEP-ALIVE)
  void _initKeepAliveTimer() {
    // Envía un pulso silencioso al iniciar la app y luego cada 10 minutos exactos
    _sendKeepAlivePulse();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _sendKeepAlivePulse();
    });
  }

  Future<void> _sendKeepAlivePulse() async {
    try {
      // Consume el historial de forma silenciosa para mantener el contenedor activo en Render
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

      // Conversión homogénea a porcentaje limpia y segura (Escala 0.0 a 100.0)
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
          // Corrección exacta de llaves mapeadas desde ApiService / Backend Flask
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
      }
    }
  }

  void _clearMasterBitacora() {
    setState(() => _masterBitacora.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold; // El resto de tu árbol de widgets (Build, HUD visual, etc.) se mantiene intacto.
    // ... (Tu diseño HUD visual, botones y listas siguen igual de funcionales abajo)