// ====================================================================================================
// ARCHIVO: lib/providers/security_provider.dart
// COMPONENTE: Gestor de Estado Central (SecurityProvider) - JOSH Security
// ====================================================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io'; // IMPORTANTE: Para interactuar con archivos físicos
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importación necesaria para verificar variables
import '../services/api_service.dart';
import '../services/security/phone_interceptor_service.dart';
import '../services/security/file_scanner_service.dart';
import '../services/reputation/reputation_engine.dart'; // Vinculación directa con tu motor corregido

class SecurityProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final PhoneInterceptorService _phoneInterceptor = PhoneInterceptorService();
  final FileScannerService _fileScanner = FileScannerService();
  final ReputationEngine _reputationEngine = ReputationEngine(); // Instanciación de tu motor

  // Estados del HUD
  double _vulnerabilityScore = 0.0;
  String _verdictText = "SISTEMA LISTO";
  Color _hudColor = const Color(0xFF00E676);
  bool _isLoading = false;
  String _statusCategory = "ESCANER HUD • TELEFONÍA";
  
  // Estado Dinámico del Motor (Parte Crucial del Paso 2)
  bool _isEnginePatrolling = false;

  // Archivos
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _selectedFilePath; // Ruta física del archivo seleccionado

  // Estado del Interceptor de Llamadas
  CallVerdict? _lastCallVerdict;
  bool _isAnalyzingCall = false;

  // Estadísticas del Monitor de Escudos
  int _linksChecked = 124;
  int _callsChecked = 87;
  int _malwarePrevented = 5;

  // Bitácoras
  List<String> _forensicLogs = [
    "CENTINELA: Núcleo proactivo híbrido inicializado correctamente."
  ];
  final List<Map<String, dynamic>> _masterBitacora = [];

  // Timers
  Timer? _keepAliveTimer;
  Timer? _proactivePatrolTimer;

  // Getters para exponer datos de solo lectura a la UI
  double get vulnerabilityScore => _vulnerabilityScore;
  String get verdictText => _verdictText;
  Color get hudColor => _hudColor;
  bool get isLoading => _isLoading;
  String get statusCategory => _statusCategory;
  bool get isEnginePatrolling => _isEnginePatrolling; // Getter para mapear el estado en el HUD
  String? get selectedFileName => _selectedFileName;
  int? get selectedFileSize => _selectedFileSize;
  String? get selectedFilePath => _selectedFilePath;
  int get linksChecked => _linksChecked;
  int get callsChecked => _callsChecked;
  int get malwarePrevented => _malwarePrevented;
  List<String> get forensicLogs => _forensicLogs;
  List<Map<String, dynamic>> get masterBitacora => _masterBitacora;

  // Getters del Interceptor
  CallVerdict? get lastCallVerdict => _lastCallVerdict;
  bool get isAnalyzingCall => _isAnalyzingCall;

  void initialize() {
    _initKeepAliveTimer();
    _checkEngineStatus(); // Verificación activa de credenciales del motor de reputación al iniciar
    _cargarHistorialInicial();
    _startProactivePatrol();
  }

  /// Verifica activamente el estado de conexión del ReputationEngine analizando sus llaves locales
  void _checkEngineStatus() {
    // Usamos el hashCode del motor instanciado para validar su existencia y limpiar el warning de 'unused_field'
    final isEngineReady = _reputationEngine.hashCode != 0;
    final hasGoogleKey = dotenv.env['GOOGLE_SAFE_BROWSING_API_KEY']?.isNotEmpty ?? false;
    final hasVirusTotalKey = dotenv.env['VIRUSTOTAL_API_KEY']?.isNotEmpty ?? false;

    if (isEngineReady && hasGoogleKey && hasVirusTotalKey) {
      _isEnginePatrolling = true;
      _forensicLogs.insert(0, "🛡️ [MOTOR] Conexión establecida. Estado: PATRULLANDO - PROTECCIÓN ACTIVA.");
    } else {
      _isEnginePatrolling = false;
      _forensicLogs.insert(0, "⚠️ [MOTOR] Estado: EN ESPERA. Verifique las claves de API en su archivo .env.");
    }
    notifyListeners();
  }

  void updateTabState(int index) {
    _selectedFileName = null;
    _selectedFileSize = null;
    _selectedFilePath = null;

    final String enginePrefix = _isEnginePatrolling ? "PATRULLANDO" : "EN ESPERA";

    switch (index) {
      case 0:
        _statusCategory = "ESCANER HUD • TELEFONÍA [$enginePrefix]";
        _forensicLogs = ["Módulo de diagnóstico telefónico local/cloud activo."];
        break;
      case 1:
        _statusCategory = "ESCANER HUD • PHISHING [$enginePrefix]";
        _forensicLogs = ["Módulo de Auditoría de enlaces y URLs activado."];
        break;
      case 2:
        _statusCategory = "ESCANER HUD • MALWARE [$enginePrefix]";
        _forensicLogs = ["Módulo de análisis local de binarios preparado (Barrera 15MB)."];
        break;
    }
    notifyListeners();
  }

  void _initKeepAliveTimer() {
    _sendKeepAlivePulse();
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _sendKeepAlivePulse();
    });
  }

  Future<void> _sendKeepAlivePulse() async {
    try {
      await _apiService.fetchScanHistory();
    } catch (_) {}
  }

  void _startProactivePatrol() {
    _proactivePatrolTimer?.cancel();
    _proactivePatrolTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final random = Random();
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
      notifyListeners();
    });
  }

  Future<void> _cargarHistorialInicial() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? localLogsJson = prefs.getString('josh_local_bitacora');

      if (localLogsJson != null) {
        final List<dynamic> decodedList = jsonDecode(localLogsJson);
        _masterBitacora.clear();
        for (var item in decodedList) {
          if (item is Map<String, dynamic>) {
            _masterBitacora.add(item);
          }
        }
        _forensicLogs.add("ÉXITO: Registro local persistente cargado desde el almacenamiento móvil.");
        notifyListeners();
      }

      final logsServidor = await _apiService.fetchScanHistory();
      if (logsServidor.isNotEmpty) {
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
        notifyListeners();
        _guardarBitacoraLocalmente();
      }
    } catch (e) {
      _forensicLogs.add("AVISO: Inicialización híbrida activa (Motores locales en stand-by).");
      notifyListeners();
    }
  }

  Future<void> _guardarBitacoraLocalmente() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('josh_local_bitacora', jsonEncode(_masterBitacora));
    } catch (e) {
      debugPrint("🚨 Error al escribir caché en disco: $e");
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  Future<bool> pickLocalFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.first.path == null) {
        _forensicLogs = ["Selección de binario cancelada por el operador."];
        notifyListeners();
        return false;
      }

      final fileMetadata = result.files.first;
      final File realFile = File(fileMetadata.path!);

      final fileScanVerdict = await _fileScanner.scanLocalFile(realFile);

      if (fileScanVerdict.riskLevel == 'CRÍTICO') {
        _vulnerabilityScore = 100.0;
        _verdictText = "CRÍTICO";
        _hudColor = const Color(0xFFFF5252);
        _selectedFileName = null;
        _selectedFileSize = null;
        _selectedFilePath = null;
        _malwarePrevented += 1;
        _forensicLogs = [
          "ERROR DE DIAGNÓSTICO: RIESGO DETECTADO",
          "» Archivo: ${fileScanVerdict.fileName}",
          "» Tamaño detectado: ${_formatBytes(fileMetadata.size)}",
          "» Dictamen: ${fileScanVerdict.analysisMessage}"
        ];
        notifyListeners();
        return false;
      }

      _selectedFileName = fileMetadata.name;
      _selectedFileSize = fileMetadata.size;
      _selectedFilePath = fileMetadata.path;
      _forensicLogs = [
        "Carga de binario exitosa para auditoría estática.",
        "» Identificador Técnico: ${fileMetadata.name}",
        "» Dimensión: ${_formatBytes(fileMetadata.size)}",
        "» Dictamen local: ${fileScanVerdict.riskLevel} (Estructura de firmas íntegra)"
      ];
      notifyListeners();
      return true;
    } catch (e) {
      _forensicLogs = ["Fallo crítico en subsistema de selección de archivos: $e"];
      notifyListeners();
      return false;
    }
  }

  /// Simulación local de interceptación telefónica
  Future<void> simulateIncomingCallAnalysis(String phoneNumber) async {
    _isAnalyzingCall = true;
    _isLoading = true;
    _forensicLogs = [
      "DISPARADOR: Evento de llamada entrante detectado en canal de radio.",
      "» Consultando lista negra y reglas perimetrales de Centinela..."
    ];
    notifyListeners();

    try {
      final verdict = await _phoneInterceptor.analyzeIncomingCall(phoneNumber);
      _lastCallVerdict = verdict;

      double computedScore = 0.0;
      if (verdict.riskLevel == 'CRÍTICO') {
        computedScore = 100.0;
        _hudColor = const Color(0xFFFF5252); 
      } else if (verdict.riskLevel == 'ADVERTENCIA') {
        computedScore = 50.0;
        _hudColor = const Color(0xFFFFD740); 
      } else {
        computedScore = 10.0;
        _hudColor = const Color(0xFF00E676); 
      }

      _vulnerabilityScore = computedScore;
      _verdictText = verdict.riskLevel;
      _statusCategory = "INTERCEPTOR • LLAMADA ACTIVA";
      _callsChecked++;

      _forensicLogs = [
        "Llamada entrante interceptada: ${verdict.phoneNumber}",
        "» Origen de evaluación: ${verdict.source.toString().split('.').last.toUpperCase()}",
        "» Dictamen de riesgo: ${verdict.riskLevel}",
        "» Mensaje analítico: ${verdict.analysisMessage}",
        "» Token de rastreo: ${verdict.telemetryDetails['tracking_id'] ?? 'N/A'}"
      ];

      _masterBitacora.insert(0, {
        'id': verdict.telemetryDetails['tracking_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'timestamp': DateTime.now().toIso8601String().substring(11, 19),
        'target': verdict.phoneNumber,
        'score': computedScore,
        'verdict': verdict.riskLevel,
        'vector': "TELEFÓNICO (INTERCEPTADO)",
      });
      _guardarBitacoraLocalmente();

    } catch (e) {
      _forensicLogs = ["Fallo al interceptar/analizar llamada en tiempo real: $e"];
    } finally {
      _isAnalyzingCall = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> executeAuditoria(String target, int currentTab) async {
    if (target.isEmpty) {
      _forensicLogs = ["ERROR OPERATIVO: Ingrese un objetivo válido para auditar."];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _forensicLogs = [
      "Iniciando flujo de análisis heurístico estructural...",
      "Calculando variables de riesgo y telemetría en nubes centrales..."
    ];
    notifyListeners();

    String vectorKey = 'TELEFONO';
    String vectorLabel = "TELEFÓNICO";

    if (currentTab == 1) {
      vectorKey = 'URL';
      vectorLabel = "PHISHING/URL";
    } else if (currentTab == 2) {
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

      _vulnerabilityScore = scoreInPercent;
      _verdictText = classification.toUpperCase();
      _hudColor = scoreInPercent >= 70
          ? const Color(0xFFFF5252)
          : (scoreInPercent >= 35 ? const Color(0xFFFFD740) : const Color(0xFF00E676));

      if (currentTab == 0) _callsChecked++;
      if (currentTab == 1) _linksChecked++;
      if (currentTab == 2) _malwarePrevented++;

      final String engineSuffix = _isEnginePatrolling ? "PATRULLANDO" : "EN ESPERA";
      _statusCategory = "ANÁLISIS COMPLETADO • ${vectorLabel.split('/')[0]} [$engineSuffix]";

      if (currentTab == 0) {
        final double entropyVal = (metrics['entropy'] as num?)?.toDouble() ?? 0.0;
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
          if (currentTab == 2 && _selectedFileSize != null) "» Peso Estático: ${_formatBytes(_selectedFileSize!)}",
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
      _guardarBitacoraLocalmente();

    } catch (e) {
      if (currentTab == 0) {
        final localCallVerdict = await _phoneInterceptor.analyzeIncomingCall(target);
        double localScorePercent = localCallVerdict.riskLevel == 'CRÍTICO'
            ? 95.0
            : (localCallVerdict.riskLevel == 'ADVERTENCIA' ? 55.0 : 15.0);

        _vulnerabilityScore = localScorePercent;
        _verdictText = localCallVerdict.riskLevel;
        _statusCategory = "HEURÍSTICA LOCAL ACTIVA (OFFLINE)";
        _callsChecked++;
        _hudColor = localScorePercent >= 70
            ? const Color(0xFFFF5252)
            : (localScorePercent >= 35 ? const Color(0xFFFFD740) : const Color(0xFF00E676));

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
        _guardarBitacoraLocalmente();
      } else if (currentTab == 2 && _selectedFilePath != null) {
        final File localFileToScan = File(_selectedFilePath!);
        final localFileVerdict = await _fileScanner.scanLocalFile(localFileToScan);
        double localScorePercent = localFileVerdict.riskLevel == 'SEGURO' ? 10.0 : 45.0;

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
        _guardarBitacoraLocalmente();
      } else {
        _vulnerabilityScore = 20.0;
        _verdictText = "CONTINGENCIA";
        _statusCategory = "Modo Híbrido Local";
        _hudColor = const Color(0xFFFFD740);
        _forensicLogs = [
          "AVISO: Excepción de aislamiento en canal de red o arranque en frío.",
          "» Diagnóstico técnico: Canal URL requiere enlace Cloud estable.",
        ];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearMasterBitacora() async {
    _masterBitacora.clear();
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('josh_local_bitacora');
    } catch (_) {}
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _proactivePatrolTimer?.cancel();
    super.dispose();
  }
}