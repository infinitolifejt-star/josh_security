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
  final DatabaseService _database = DatabaseService.instance;

  final PhoneInterceptorService _phoneService = PhoneInterceptorService();

  final FileScannerService _fileScanner = FileScannerService.instance;

  final ApkCentinelService _apkCentinel = ApkCentinelService.instance;

  late final SecurityCoordinator _coordinator;

  StreamSubscription<ApkInstallEvent>? _apkSubscription;

  bool _initialized = false;
  bool _isLoading = false;
  bool _isEnginePatrolling = false;
  final bool _cloudAvailable = false;

  int _currentVector = 0;
  double _vulnerabilityScore = 0;
  Color _hudColor = Colors.green;

  String _verdictText = 'SISTEMA OPERATIVO SEGURO';

  String _statusCategory = 'CENTINELA INICIALIZANDO...';

  String _agentReasoningText = 'Agente Centinela activo y listo.';

  String? _selectedFileName;
  File? _selectedFile;

  int _linksChecked = 0;
  int _callsChecked = 0;
  int _malwarePrevented = 0;

  final List<String> _forensicLogs = <String>[];

  List<Map<String, dynamic>> _historicalLogs = <Map<String, dynamic>>[];

  SecurityProvider() {
    _coordinator = SecurityCoordinator(
      phishingEngine: PhishingEngine(),
      callSecurityEngine: const CallSecurityEngine(),
      telemetryService: TelemetryService(),
    );
  }

  bool get initialized => _initialized;

  bool get isLoading => _isLoading;

  bool get isEnginePatrolling => _isEnginePatrolling;

  bool get cloudAvailable => _cloudAvailable;

  int get currentVector => _currentVector;

  double get vulnerabilityScore => _vulnerabilityScore;

  Color get hudColor => _hudColor;

  String get verdictText => _verdictText;

  String get statusCategory => _statusCategory;

  String get agentReasoningText => _agentReasoningText;

  String get agentReasoning => _agentReasoningText;

  int get linksChecked => _linksChecked;

  int get callsChecked => _callsChecked;

  int get malwarePrevented => _malwarePrevented;

  String? get selectedFileName => _selectedFileName;

  List<String> get forensicLogs => List.unmodifiable(_forensicLogs);

  List<Map<String, dynamic>> get historicalLogs => List.unmodifiable(
        _historicalLogs,
      );

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _setLoadingState(true);

    try {
      await _database.database;
      _phoneService.startListening();

      await _apkCentinel.initialize();

      _apkSubscription = _apkCentinel.onApkInstalled.listen(
        _handleApkInstallEvent,
      );

      await _loadHistoricalLogs();

      _statusCategory = 'CENTINELA OPERATIVO';

      _initialized = true;
    } catch (e) {
      _appendLog(
        'ERROR INICIALIZANDO: $e',
      );
    } finally {
      _setLoadingState(false);
    }
  }

  Future<void> _handleApkInstallEvent(
    ApkInstallEvent event,
  ) async {
    _malwarePrevented++;

    final bool isSystemOrStore = event.apkPath.contains(
      '/data/app/',
    );

    final double score = isSystemOrStore ? 5.0 : 40.0;

    final String verdict =
        isSystemOrStore ? 'SEGURO (OFICIAL)' : 'ANALIZAR_ORIGEN';

    _agentReasoningText =
        "Centinela analizó la instalación de '${event.appName}'.";

    _updateHudWithVerdict(
      score,
      verdict,
    );

    await _persistAudit(
      event.appName.isNotEmpty ? event.appName : event.packageName,
      score,
      verdict,
      'MALWARE',
      'Package: ${event.packageName} | Path: ${event.apkPath}',
    );

    await _loadHistoricalLogs();
    notifyListeners();
  }

  void updateTabState(int tab) {
    _currentVector = tab;

    const List<String> categories = <String>[
      'ANÁLISIS TELEFÓNICO',
      'ANÁLISIS PHISHING',
      'ANÁLISIS MALWARE',
    ];

    if (tab >= 0 && tab < categories.length) {
      _statusCategory = categories[tab];
    }

    notifyListeners();
  }

  Future<bool> pickLocalFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null) {
        return false;
      }

      _selectedFile = File(
        result.files.single.path!,
      );

      _selectedFileName = result.files.single.name;

      notifyListeners();
      return true;
    } catch (e) {
      _appendLog(
        'FILE PICKER ERROR: $e',
      );
      return false;
    }
  }

  Future<void> executeAuditoria(
    String target,
    int vector,
  ) async {
    if (target.trim().isEmpty && vector != 2) {
      return;
    }

    _isEnginePatrolling = true;
    _setLoadingState(true);

    try {
      switch (vector) {
        case 0:
          await _processCallScan(target);
          break;
        case 1:
          await _processUrlScan(target);
          break;
        case 2:
          await _auditFile();
          break;
      }

      await _loadHistoricalLogs();
    } catch (e) {
      _appendLog(
        'ERROR GENERAL AGÉNTICO: $e',
      );
    } finally {
      _isEnginePatrolling = false;
      _setLoadingState(false);
    }
  }

  Future<void> processIncomingCall(
    String phoneNumber,
  ) async {
    final String number =
        phoneNumber.trim().isEmpty ? 'Número Oculto' : phoneNumber.trim();

    if (number == 'Número Oculto') {
      _appendLog(
        'LLAMADA ENTRANTE SIN NÚMERO VÁLIDO.',
      );
      return;
    }

    _appendLog(
      'LLAMADA ENTRANTE DETECTADA: $number',
    );

    _callsChecked++;

    try {
      _isEnginePatrolling = true;
      _statusCategory = 'ANALIZANDO LLAMADA ENTRANTE';

      notifyListeners();

      final Map<String, dynamic> result = await _coordinator.scanCall(
        phoneNumber: number,
      );

      final double score = _extractScore(result);

      final String verdict = _extractString(
        result,
        'verdict',
        'DESCONOCIDO',
      );

      final String reasoning = _extractString(
        result,
        'agentReasoning',
        'Análisis de seguridad completado.',
      );

      _updateHudWithVerdict(
        score,
        verdict,
      );

      _agentReasoningText = reasoning;

      await _persistAudit(
        number,
        score,
        verdict,
        'PHONE',
        result.toString(),
      );

      await _loadHistoricalLogs();

      await OverlayService.showWarningOverlay(
        phoneNumber: number,
        riskLevel: verdict,
        message: _buildOverlayMessage(
          score,
          verdict,
        ),
        agentReasoning: reasoning,
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

      try {
        await OverlayService.showWarningOverlay(
          phoneNumber: number,
          riskLevel: 'ADVERTENCIA',
          message: 'Llamada entrante detectada. '
              'No fue posible completar el análisis.',
          agentReasoning: 'El Centinela no pudo completar '
              'el análisis automático.',
        );
      } catch (overlayError) {
        _appendLog(
          'ERROR MOSTRANDO OVERLAY: $overlayError',
        );
      }
    } finally {
      _isEnginePatrolling = false;
      _statusCategory = 'CENTINELA OPERATIVO';
      notifyListeners();
    }
  }

  Future<void> _processCallScan(
    String target,
  ) async {
    final Map<String, dynamic> result = await _coordinator.scanCall(
      phoneNumber: target,
    );

    final double score = _extractScore(result);

    final String verdict = _extractString(
      result,
      'verdict',
      'DESCONOCIDO',
    );

    final String reasoning = _extractString(
      result,
      'agentReasoning',
      'Sin razonamiento.',
    );

    _callsChecked++;
    _agentReasoningText = reasoning;

    _updateHudWithVerdict(
      score,
      verdict,
    );

    await _persistAudit(
      target,
      score,
      verdict,
      'PHONE',
      result.toString(),
    );
  }

  Future<void> _processUrlScan(
    String target,
  ) async {
    final Map<String, dynamic> result = await _coordinator.scanUrl(target);

    final double score = _extractScore(result);

    final String verdict = _extractString(
      result,
      'verdict',
      'DESCONOCIDO',
    );

    final String reasoning = _extractString(
      result,
      'agentReasoning',
      'Sin razonamiento.',
    );

    _linksChecked++;
    _agentReasoningText = reasoning;

    _updateHudWithVerdict(
      score,
      verdict,
    );

    await _persistAudit(
      target,
      score,
      verdict,
      'URL',
      result.toString(),
    );
  }

  Future<void> _auditFile() async {
    if (_selectedFile == null) {
      _appendLog(
        'No existe archivo seleccionado.',
      );
      return;
    }

    final dynamic verdict = await _fileScanner.scanLocalFile(
      _selectedFile!,
    );

    final double score = verdict.isCritical
        ? 100
        : verdict.isWarning
            ? 60
            : 5;

    _malwarePrevented++;

    _agentReasoningText =
        'Análisis estático de firmas y hashes sobre ejecutable.';

    _updateHudWithVerdict(
      score,
      verdict.riskLevel,
    );

    await _persistAudit(
      _selectedFileName ?? 'APK_DESCONOCIDO',
      score,
      verdict.riskLevel,
      'MALWARE',
      verdict.toString(),
    );
  }

  Future<void> _persistAudit(
    String target,
    double score,
    String verdict,
    String vector,
    String rawDetails,
  ) async {
    final String timestamp = DateTime.now().toIso8601String();

    await _database.insertScanLog({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'timestamp': timestamp,
      'target': target,
      'score': score,
      'verdict': verdict,
      'vector': vector,
    });

    await _database.insertForensicLog({
      'timestamp': timestamp,
      'service': vector,
      'activity': target,
      'verdict': verdict,
      'matched_rule': 'AGENT_$vector',
      'extra_data': rawDetails,
    });
  }

  double _extractScore(
    Map<String, dynamic> result,
  ) {
    final dynamic value = result['agentRiskScore'] ??
        result['riskScore'] ??
        result['score'] ??
        0.0;

    if (value is num) {
      return value.toDouble().clamp(0.0, 100.0);
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  String _extractString(
    Map<String, dynamic> result,
    String key,
    String fallback,
  ) {
    final dynamic value = result[key];

    if (value == null) {
      return fallback;
    }

    final String text = value.toString().trim();

    return text.isEmpty ? fallback : text;
  }

  String _buildOverlayMessage(
    double score,
    String verdict,
  ) {
    if (score >= 70) {
      return 'RIESGO ALTO: esta llamada requiere precaución inmediata.';
    }

    if (score >= 30) {
      return 'RIESGO MODERADO: verifica la identidad del interlocutor.';
    }

    return 'El Centinela ha analizado esta llamada.';
  }

  void _updateHudWithVerdict(
    double score,
    String verdict,
  ) {
    _vulnerabilityScore = score;
    _verdictText = verdict;

    if (score >= 70) {
      _hudColor = Colors.red;
    } else if (score >= 30) {
      _hudColor = Colors.orange;
    } else {
      _hudColor = Colors.green;
    }
  }

  Future<void> clearMasterBitacora() async {
    try {
      await _database.clearAllLogs();

      _historicalLogs.clear();
      _forensicLogs.clear();

      _linksChecked = 0;
      _callsChecked = 0;
      _malwarePrevented = 0;

      resetHud();
      _statusCategory = 'BITÁCORA LIMPIA';
    } catch (e) {
      _appendLog(
        'ERROR LIMPIANDO: $e',
      );
    }

    notifyListeners();
  }

  void resetHud() {
    _vulnerabilityScore = 0;
    _hudColor = Colors.green;
    _verdictText = 'SISTEMA OPERATIVO SEGURO';
    _statusCategory = 'CENTINELA OPERATIVO';
    _agentReasoningText = 'Agente Centinela activo y listo.';

    notifyListeners();
  }

  void clearForensicLogs() {
    _forensicLogs.clear();
    notifyListeners();
  }

  void _appendLog(String text) {
    final DateTime now = DateTime.now();

    final String timeStr = '${now.hour.toString().padLeft(2, '0')}:'
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

  Future<void> _loadHistoricalLogs() async {
    _historicalLogs = await _database.getScanHistory();

    notifyListeners();
  }

  void _setLoadingState(
    bool value,
  ) {
    _isLoading = value;
    notifyListeners();
  }

  void setLoading(
    bool value,
  ) {
    _setLoadingState(value);
  }

  void setStatus(
    String status,
  ) {
    _statusCategory = status;
    notifyListeners();
  }

  Future<void> reloadHistory() async {
    await _loadHistoricalLogs();
  }

  @override
  void dispose() {
    _apkSubscription?.cancel();
    _phoneService.dispose();
    super.dispose();
  }
}
