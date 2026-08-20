// ====================================================================================================
// ARCHIVO: lib/providers/security_provider.dart
// JOSH SECURITY
// PROVIDER ORQUESTADOR DE SEGURIDAD
// ====================================================================================================

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/security/apk_centinel_service.dart';
import '../services/security/call_security_engine.dart';
import '../services/security/database_service.dart';
import '../services/security/file_scanner_service.dart';
import '../services/security/overlay_service.dart';
import '../services/security/phishing_engine.dart';
import '../services/security/phone_interceptor_service.dart';
import '../services/security/security_coordinator.dart';
import '../services/security/telemetry_service.dart';

class SecurityProvider with ChangeNotifier {
  // ================================================================================================
  // SERVICIOS
  // ================================================================================================

  final DatabaseService _database = DatabaseService.instance;

  final PhoneInterceptorService _phoneService =
      PhoneInterceptorService();

  final FileScannerService _fileScanner =
      FileScannerService.instance;

  final ApkCentinelService _apkCentinel =
      ApkCentinelService.instance;

  late final SecurityCoordinator _coordinator;

  StreamSubscription<ApkInstallEvent>? _apkSubscription;

  // ================================================================================================
  // ESTADO
  // ================================================================================================

  bool _initialized = false;
  bool _isLoading = false;
  bool _isEnginePatrolling = false;

  // El motor actual trabaja localmente.
  final bool _cloudAvailable = false;

  int _currentVector = 0;

  double _vulnerabilityScore = 0.0;

  Color _hudColor = Colors.green;

  String _verdictText =
      'SISTEMA OPERATIVO SEGURO';

  String _statusCategory =
      'CENTINELA INICIALIZANDO...';

  String _agentReasoningText =
      'Agente Centinela activo y listo.';

  // ================================================================================================
  // ARCHIVO SELECCIONADO
  // ================================================================================================

  String? _selectedFileName;

  File? _selectedFile;

  // ================================================================================================
  // MÉTRICAS
  // ================================================================================================

  int _linksChecked = 0;
  int _callsChecked = 0;
  int _malwarePrevented = 0;

  // ================================================================================================
  // BITÁCORA
  // ================================================================================================

  final List<String> _forensicLogs = <String>[];

  List<Map<String, dynamic>> _historicalLogs =
      <Map<String, dynamic>>[];

  // ================================================================================================
  // CONSTRUCTOR
  // ================================================================================================

  SecurityProvider() {
    _coordinator = SecurityCoordinator(
      phishingEngine: PhishingEngine(),
      callSecurityEngine: const CallSecurityEngine(),
      telemetryService: TelemetryService(),
    );
  }

  // ================================================================================================
  // GETTERS
  // ================================================================================================

  bool get initialized => _initialized;

  bool get isLoading => _isLoading;

  bool get isEnginePatrolling =>
      _isEnginePatrolling;

  bool get cloudAvailable =>
      _cloudAvailable;

  int get currentVector =>
      _currentVector;

  double get vulnerabilityScore =>
      _vulnerabilityScore;

  Color get hudColor =>
      _hudColor;

  String get verdictText =>
      _verdictText;

  String get statusCategory =>
      _statusCategory;

  String get agentReasoningText =>
      _agentReasoningText;

  String get agentReasoning =>
      _agentReasoningText;

  int get linksChecked =>
      _linksChecked;

  int get callsChecked =>
      _callsChecked;

  int get malwarePrevented =>
      _malwarePrevented;

  String? get selectedFileName =>
      _selectedFileName;

  File? get selectedFile =>
      _selectedFile;

  List<String> get forensicLogs =>
      List.unmodifiable(_forensicLogs);

  List<Map<String, dynamic>> get historicalLogs =>
      List.unmodifiable(_historicalLogs);

  // ================================================================================================
  // INICIALIZACIÓN
  // ================================================================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _setLoadingState(true);

    try {
      await _database.database;

      _phoneService.startListening();

      await _apkCentinel.initialize();

      await _apkSubscription?.cancel();

      _apkSubscription =
          _apkCentinel.onApkInstalled.listen(
        _handleApkInstallEvent,
        onError: (Object error, StackTrace stackTrace) {
          _appendLog(
            'ERROR STREAM APK CENTINEL: $error',
          );

          debugPrint(
            '[JOSH APK] Stream error: $error',
          );

          debugPrint(
            stackTrace.toString(),
          );
        },
      );

      await _loadHistoricalLogs();

      _statusCategory =
          'CENTINELA OPERATIVO';

      _initialized = true;

      _appendLog(
        'CENTINELA INICIALIZADO CORRECTAMENTE.',
      );
    } catch (e, stackTrace) {
      _initialized = false;

      _statusCategory =
          'ERROR DE INICIALIZACIÓN';

      _appendLog(
        'ERROR INICIALIZANDO CENTINELA: $e',
      );

      debugPrint(
        '[JOSH SECURITY] Error inicializando: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    } finally {
      _setLoadingState(false);
    }
  }

  // ================================================================================================
  // EVENTO DE INSTALACIÓN APK
  //
  // IMPORTANTE:
  // Detectar una instalación NO significa que se haya prevenido malware.
  // Solo incrementamos malwarePrevented cuando el evento representa una detección
  // crítica/no verificada según la lógica disponible actualmente.
  // ================================================================================================

  Future<void> _handleApkInstallEvent(
    ApkInstallEvent event,
  ) async {
    try {
      final String appName =
          event.appName.trim().isNotEmpty
              ? event.appName.trim()
              : event.packageName.trim().isNotEmpty
                  ? event.packageName.trim()
                  : 'Aplicación desconocida';

      final bool isOfficialOrSystem =
          _isOfficialOrSystemApkPath(
        event.apkPath,
      );

      final double score =
          isOfficialOrSystem ? 5.0 : 40.0;

      final String verdict =
          isOfficialOrSystem
              ? 'SEGURO (OFICIAL)'
              : 'ANALIZAR_ORIGEN';

      _agentReasoningText =
          "Centinela detectó la instalación de '$appName'.";

      _updateHudWithVerdict(
        score,
        verdict,
      );

      if (isOfficialOrSystem) {
        _appendLog(
          'APK OFICIAL/SISTEMA DETECTADO: $appName',
        );
      } else {
        _appendLog(
          'APK NO VERIFICADO DETECTADO: $appName',
        );
      }

      // No marcamos automáticamente cualquier APK no verificado
      // como malware prevenido.
      if (score >= 70) {
        _malwarePrevented++;
      }

      await _persistAudit(
        appName,
        score,
        verdict,
        'MALWARE',
        'Package: ${event.packageName} | '
        'Path: ${event.apkPath}',
      );

      await _loadHistoricalLogs();

      notifyListeners();
    } catch (e, stackTrace) {
      _appendLog(
        'ERROR PROCESANDO EVENTO APK: $e',
      );

      debugPrint(
        '[JOSH APK] Error procesando instalación: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ================================================================================================
  // VALIDACIÓN DE RUTA APK
  // ================================================================================================

  bool _isOfficialOrSystemApkPath(
    String path,
  ) {
    final String normalized =
        path.trim().toLowerCase();

    if (normalized.isEmpty) {
      return false;
    }

    return normalized.contains('/data/app/') ||
        normalized.contains('/system/app/') ||
        normalized.contains('/system/priv-app/') ||
        normalized.contains('/product/app/') ||
        normalized.contains('/vendor/app/');
  }

  // ================================================================================================
  // CAMBIO DE VECTOR
  // ================================================================================================

  void updateTabState(int tab) {
    _currentVector = tab;

    const List<String> categories =
        <String>[
      'ANÁLISIS TELEFÓNICO',
      'ANÁLISIS PHISHING',
      'ANÁLISIS MALWARE',
    ];

    if (tab >= 0 && tab < categories.length) {
      _statusCategory = categories[tab];
    }

    notifyListeners();
  }

  // ================================================================================================
  // SELECCIÓN DE ARCHIVO
  // ================================================================================================

  Future<bool> pickLocalFile() async {
    try {
      final FilePickerResult? result =
          await FilePicker.platform.pickFiles();

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null) {
        return false;
      }

      final String path =
          result.files.single.path!;

      _selectedFile =
          File(path);

      _selectedFileName =
          result.files.single.name;

      _agentReasoningText =
          'Archivo seleccionado. '
          'Listo para análisis perimetral.';

      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      _appendLog(
        'FILE PICKER ERROR: $e',
      );

      debugPrint(
        '[JOSH FILE] Error seleccionando archivo: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      return false;
    }
  }

  // ================================================================================================
  // AUDITORÍA PRINCIPAL
  //
  // showCallOverlay:
  // false -> análisis normal.
  // true  -> análisis de llamada entrante y presentación del overlay.
  //
  // Esto permite que processIncomingCall() analice UNA SOLA VEZ.
  // ================================================================================================

  Future<void> executeAuditoria(
    String target,
    int vector, {
    bool showCallOverlay = false,
  }) async {
    final String cleanTarget =
        target.trim();

    if (cleanTarget.isEmpty &&
        vector != 2) {
      _appendLog(
        'AUDITORÍA CANCELADA: objetivo vacío.',
      );

      return;
    }

    if (_isEnginePatrolling) {
      _appendLog(
        'AUDITORÍA IGNORADA: Centinela ya está procesando.',
      );

      return;
    }

    _isEnginePatrolling = true;

    _setLoadingState(true);

    try {
      switch (vector) {
        case 0:
          await _processCallScan(
            cleanTarget,
            showOverlay: showCallOverlay,
          );
          break;

        case 1:
          await _processUrlScan(
            cleanTarget,
          );
          break;

        case 2:
          await _auditFile();
          break;

        default:
          _appendLog(
            'VECTOR DE SEGURIDAD NO SOPORTADO: $vector',
          );
          break;
      }

      await _loadHistoricalLogs();
    } catch (e, stackTrace) {
      _appendLog(
        'ERROR GENERAL DE AUDITORÍA: $e',
      );

      debugPrint(
        '[JOSH ENGINE] Error general: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    } finally {
      _isEnginePatrolling = false;

      _setLoadingState(false);
    }
  }

  // ================================================================================================
  // LLAMADA ENTRANTE
  //
  // Flujo:
  //
  // Android PhoneCallReceiver
  //        ↓
  // MethodChannel
  //        ↓
  // main.dart
  //        ↓
  // SecurityProvider.processIncomingCall()
  //        ↓
  // executeAuditoria(numero, 0, showCallOverlay: true)
  //        ↓
  // _processCallScan()
  //        ↓
  // SecurityCoordinator.scanCall()
  //        ↓
  // resultado
  //        ↓
  // HUD + DB + Overlay
  //
  // La llamada NO se analiza dos veces.
  // ================================================================================================

  Future<void> processIncomingCall(
    String phoneNumber,
  ) async {
    final String number =
        phoneNumber.trim().isEmpty
            ? 'Número Oculto'
            : phoneNumber.trim();

    if (number == 'Número Oculto') {
      _appendLog(
        'LLAMADA ENTRANTE SIN NÚMERO VÁLIDO.',
      );

      return;
    }

    _appendLog(
      'LLAMADA ENTRANTE DETECTADA: $number',
    );

    _statusCategory =
        'ANALIZANDO LLAMADA ENTRANTE';

    notifyListeners();

    try {
      await executeAuditoria(
        number,
        0,
        showCallOverlay: true,
      );
    } catch (e, stackTrace) {
      _appendLog(
        'ERROR ANALIZANDO LLAMADA: $e',
      );

      debugPrint(
        '[JOSH PHONE] Error analizando llamada: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    } finally {
      _statusCategory =
          'CENTINELA OPERATIVO';

      notifyListeners();
    }
  }

  // ================================================================================================
  // VECTOR 0 - LLAMADAS
  // ================================================================================================

  Future<void> _processCallScan(
    String target, {
    bool showOverlay = false,
  }) async {
    final String number =
        target.trim();

    if (number.isEmpty) {
      return;
    }

    try {
      final Map<String, dynamic> result =
          await _coordinator.scanCall(
        phoneNumber: number,
      );

      final double score =
          _extractScore(result);

      final String verdict =
          _extractString(
        result,
        'verdict',
        'DESCONOCIDO',
      );

      final String reasoning =
          _extractString(
        result,
        'agentReasoning',
        'Análisis de seguridad completado.',
      );

      _callsChecked++;

      _agentReasoningText =
          reasoning;

      _updateHudWithVerdict(
        score,
        verdict,
      );

      await _persistAudit(
        number,
        score,
        verdict,
        'PHONE',
        result.toString(),
      );

      if (showOverlay) {
        try {
          await OverlayService.showWarningOverlay(
            phoneNumber: number,
            riskLevel: verdict,
            message: buildOverlayMessage(
              score,
              verdict,
            ),
            agentReasoning: reasoning,
          );
        } catch (overlayError, overlayStack) {
          _appendLog(
            'ERROR MOSTRANDO OVERLAY: $overlayError',
          );

          debugPrint(
            '[JOSH OVERLAY] Error: $overlayError',
          );

          debugPrint(
            overlayStack.toString(),
          );
        }
      }
    } catch (e, stackTrace) {
      _appendLog(
        'ERROR ANALIZANDO LLAMADA: $e',
      );

      debugPrint(
        '[JOSH PHONE] Error analizando llamada: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (showOverlay) {
        try {
          await OverlayService.showWarningOverlay(
            phoneNumber: number,
            riskLevel: 'ADVERTENCIA',
            message:
                'Llamada entrante detectada. '
                'No fue posible completar el análisis.',
            agentReasoning:
                'El Centinela no pudo completar '
                'el análisis automático.',
          );
        } catch (overlayError, overlayStack) {
          _appendLog(
            'ERROR MOSTRANDO OVERLAY DE ERROR: '
            '$overlayError',
          );

          debugPrint(
            '[JOSH OVERLAY] Error: $overlayError',
          );

          debugPrint(
            overlayStack.toString(),
          );
        }
      }

      rethrow;
    }
  }

  // ================================================================================================
  // VECTOR 1 - PHISHING / URL
  // ================================================================================================

  Future<void> _processUrlScan(
    String target,
  ) async {
    final String url =
        target.trim();

    if (url.isEmpty) {
      return;
    }

    final Map<String, dynamic> result =
        await _coordinator.scanUrl(
      url,
    );

    final double score =
        _extractScore(result);

    final String verdict =
        _extractString(
      result,
      'verdict',
      'DESCONOCIDO',
    );

    final String reasoning =
        _extractString(
      result,
      'agentReasoning',
      'Sin razonamiento.',
    );

    _linksChecked++;

    _agentReasoningText =
        reasoning;

    _updateHudWithVerdict(
      score,
      verdict,
    );

    await _persistAudit(
      url,
      score,
      verdict,
      'URL',
      result.toString(),
    );
  }

  // ================================================================================================
  // VECTOR 2 - MALWARE / ARCHIVO
  // ================================================================================================

  Future<void> _auditFile() async {
    final File? file =
        _selectedFile;

    if (file == null) {
      _appendLog(
        'NO EXISTE ARCHIVO SELECCIONADO.',
      );

      return;
    }

    final FileScanVerdict verdict =
        await _fileScanner.scanLocalFile(
      file,
    );

    final double score =
        _mapFileVerdictToScore(
      verdict,
    );

    _agentReasoningText =
        'Análisis estático de firmas, extensión, '
        'integridad y reputación del archivo.';

    _updateHudWithVerdict(
      score,
      verdict.riskLevel,
    );

    // Solo contamos como prevención real
    // cuando el veredicto es crítico.
    if (verdict.isCritical) {
      _malwarePrevented++;
    }

    await _persistAudit(
      _selectedFileName ??
          file.path.split(
            Platform.pathSeparator,
          ).last,
      score,
      verdict.riskLevel,
      'MALWARE',
      _serializeFileVerdict(
        verdict,
      ),
    );
  }

  // ================================================================================================
  // CONVERSIÓN DE VEREDICTO DE ARCHIVO A SCORE
  // ================================================================================================

  double _mapFileVerdictToScore(
    FileScanVerdict verdict,
  ) {
    final double riskScore =
        verdict.riskScore
            .toDouble();

    if (verdict.isCritical) {
      return riskScore
          .clamp(80.0, 100.0)
          .toDouble();
    }

    if (verdict.isWarning) {
      return riskScore
          .clamp(40.0, 79.0)
          .toDouble();
    }

    return riskScore
        .clamp(0.0, 39.0)
        .toDouble();
  }

  // ================================================================================================
  // SERIALIZACIÓN DEL VEREDICTO DE ARCHIVO
  // ================================================================================================

  String _serializeFileVerdict(
    FileScanVerdict verdict,
  ) {
    return <String, dynamic>{
      'fileName': verdict.fileName,
      'fileSizeInBytes':
          verdict.fileSizeInBytes,
      'fileSizeInMB':
          verdict.fileSizeInMB,
      'riskScore':
          verdict.riskScore,
      'riskLevel':
          verdict.riskLevel,
      'analysisMessage':
          verdict.analysisMessage,
      'source':
          verdict.source.toString(),
      'telemetryDetails':
          verdict.telemetryDetails,
    }.toString();
  }

  // ================================================================================================
  // PERSISTENCIA DE AUDITORÍA
  // ================================================================================================

  Future<void> _persistAudit(
    String target,
    double score,
    String verdict,
    String vector,
    String rawDetails,
  ) async {
    final String timestamp =
        DateTime.now().toIso8601String();

    // ----------------------------------------------------------------------------------------------
    // SCAN LOG
    // ----------------------------------------------------------------------------------------------

    try {
      await _database.insertScanLog(
        <String, dynamic>{
          'id':
              DateTime.now()
                  .millisecondsSinceEpoch
                  .toString(),
          'timestamp':
              timestamp,
          'target':
              target,
          'score':
              score,
          'verdict':
              verdict,
          'vector':
              vector,
        },
      );
    } catch (e, stackTrace) {
      _appendLog(
        'ERROR GUARDANDO SCAN LOG: $e',
      );

      debugPrint(
        '[JOSH DATABASE] insertScanLog error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }

    // ----------------------------------------------------------------------------------------------
    // FORENSIC LOG
    // ----------------------------------------------------------------------------------------------

    try {
      await _database.insertForensicLog(
        <String, dynamic>{
          'timestamp':
              timestamp,
          'service':
              vector,
          'activity':
              target,
          'verdict':
              verdict,
          'matched_rule':
              'AGENT_$vector',
          'extra_data':
              rawDetails,
        },
      );
    } catch (e, stackTrace) {
      _appendLog(
        'ERROR GUARDANDO FORENSIC LOG: $e',
      );

      debugPrint(
        '[JOSH DATABASE] insertForensicLog error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ================================================================================================
  // EXTRACCIÓN SEGURA DE SCORE
  // ================================================================================================

  double _extractScore(
    Map<String, dynamic> result,
  ) {
    final dynamic value =
        result['agentRiskScore'] ??
        result['riskScore'] ??
        result['score'] ??
        0.0;

    if (value is num) {
      final double score =
          value.toDouble();

      if (!score.isFinite) {
        return 0.0;
      }

      return score
          .clamp(0.0, 100.0)
          .toDouble();
    }

    final double? parsed =
        double.tryParse(
      value.toString(),
    );

    if (parsed == null ||
        !parsed.isFinite) {
      return 0.0;
    }

    return parsed
        .clamp(0.0, 100.0)
        .toDouble();
  }

  // ================================================================================================
  // EXTRACCIÓN SEGURA DE TEXTO
  // ================================================================================================

  String _extractString(
    Map<String, dynamic> result,
    String key,
    String fallback,
  ) {
    final dynamic value =
        result[key];

    if (value == null) {
      return fallback;
    }

    final String text =
        value.toString().trim();

    return text.isEmpty
        ? fallback
        : text;
  }

  // ================================================================================================
  // MENSAJE PARA OVERLAY
  //
  // Este método ahora SÍ se utiliza desde _processCallScan().
  // Por eso desaparece el warning de _buildOverlayMessage no referenciado.
  // ================================================================================================

  String buildOverlayMessage(
    double score,
    String verdict,
  ) {
    if (score >= 70) {
      return 'RIESGO ALTO: esta llamada requiere '
          'precaución inmediata.';
    }

    if (score >= 30) {
      return 'RIESGO MODERADO: verifica la identidad '
          'del interlocutor.';
    }

    return 'El Centinela ha analizado esta llamada.';
  }

  // ================================================================================================
  // ACTUALIZACIÓN DEL HUD
  // ================================================================================================

  void _updateHudWithVerdict(
    double score,
    String verdict,
  ) {
    final double safeScore =
        score.isFinite
            ? score
                .clamp(0.0, 100.0)
                .toDouble()
            : 0.0;

    _vulnerabilityScore =
        safeScore;

    final String cleanVerdict =
        verdict.trim();

    _verdictText =
        cleanVerdict.isEmpty
            ? 'DESCONOCIDO'
            : cleanVerdict;

    if (safeScore >= 70) {
      _hudColor =
          Colors.red;
    } else if (safeScore >= 30) {
      _hudColor =
          Colors.orange;
    } else {
      _hudColor =
          Colors.green;
    }

    notifyListeners();
  }

  // ================================================================================================
  // LIMPIAR BITÁCORA MAESTRA
  // ================================================================================================

  Future<void> clearMasterBitacora() async {
    try {
      await _database.clearAllLogs();

      _historicalLogs.clear();

      _forensicLogs.clear();

      _linksChecked = 0;
      _callsChecked = 0;
      _malwarePrevented = 0;

      resetHud(
        notify: false,
      );

      _statusCategory =
          'BITÁCORA LIMPIA';

      _agentReasoningText =
          'Agente Centinela activo y listo.';
    } catch (e, stackTrace) {
      _appendLog(
        'ERROR LIMPIANDO BITÁCORA: $e',
      );

      debugPrint(
        '[JOSH DATABASE] Error limpiando: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }

    notifyListeners();
  }

  // ================================================================================================
  // RESET HUD
  // ================================================================================================

  void resetHud({
    bool notify = true,
  }) {
    _vulnerabilityScore =
        0.0;

    _hudColor =
        Colors.green;

    _verdictText =
        'SISTEMA OPERATIVO SEGURO';

    _statusCategory =
        'CENTINELA OPERATIVO';

    _agentReasoningText =
        'Agente Centinela activo y listo.';

    if (notify) {
      notifyListeners();
    }
  }

  // ================================================================================================
  // LOGS FORENSES
  // ================================================================================================

  void clearForensicLogs() {
    _forensicLogs.clear();

    notifyListeners();
  }

  void _appendLog(
    String text,
  ) {
    final DateTime now =
        DateTime.now();

    final String timeStr =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    _forensicLogs.add(
      '[$timeStr]  $text',
    );

    if (_forensicLogs.length > 500) {
      _forensicLogs.removeAt(0);
    }

    notifyListeners();
  }

  // ================================================================================================
  // HISTORIAL
  // ================================================================================================

  Future<void> _loadHistoricalLogs() async {
    try {
      _historicalLogs =
          await _database.getScanHistory();

      notifyListeners();
    } catch (e, stackTrace) {
      _appendLog(
        'ERROR CARGANDO HISTORIAL: $e',
      );

      debugPrint(
        '[JOSH DATABASE] Error cargando historial: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  Future<void> reloadHistory() async {
    await _loadHistoricalLogs();
  }

  // ================================================================================================
  // ESTADO DE CARGA
  // ================================================================================================

  void _setLoadingState(
    bool value,
  ) {
    if (_isLoading == value) {
      return;
    }

    _isLoading =
        value;

    notifyListeners();
  }

  void setLoading(
    bool value,
  ) {
    _setLoadingState(
      value,
    );
  }

  // ================================================================================================
  // ESTADO / STATUS
  // ================================================================================================

  void setStatus(
    String status,
  ) {
    final String cleanStatus =
        status.trim();

    _statusCategory =
        cleanStatus.isEmpty
            ? 'CENTINELA OPERATIVO'
            : cleanStatus;

    notifyListeners();
  }

  // ================================================================================================
  // DISPOSE
  // ================================================================================================

  @override
  void dispose() {
    _apkSubscription?.cancel();

    _apkSubscription = null;

    _phoneService.dispose();

    super.dispose();
  }
}
