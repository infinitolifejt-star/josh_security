// ====================================================================================================
// ARCHIVO: lib/providers/security_provider.dart
// JOSH SECURITY v6.0 - PROVIDER ORQUESTADOR CON AGENTE E IA CONTEXTUAL
// ====================================================================================================

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/security/call_security_engine.dart';
import '../services/security/database_service.dart';
import '../services/security/file_scanner_service.dart';
import '../services/security/phishing_engine.dart';
import '../services/security/phone_interceptor_service.dart';
import '../services/security/security_coordinator.dart';
import '../services/security/telemetry_service.dart';

class SecurityProvider extends ChangeNotifier {
  //============================================================================
  // SERVICIOS & COORDINADOR DE SEGURIDAD
  //============================================================================
  final DatabaseService _database = DatabaseService.instance;
  final PhoneInterceptorService _phoneService = PhoneInterceptorService();
  final FileScannerService _fileScanner = FileScannerService.instance;

  late final SecurityCoordinator _coordinator;

  //============================================================================
  // ESTADO GENERAL & HUD
  //============================================================================
  bool _initialized = false;
  bool _isLoading = false;
  bool _isEnginePatrolling = false;
  final bool _cloudAvailable = false;
  int _currentVector = 0;

  double _vulnerabilityScore = 0;
  Color _hudColor = Colors.green;
  String _verdictText = "SISTEMA OPERATIVO SEGURO";
  String _statusCategory = "CENTINELA INICIALIZANDO...";
  String _agentReasoningText = "Agente Centinela activo y listo.";

  String? _selectedFileName;
  File? _selectedFile;

  //============================================================================
  // MÉTRICAS Y CONSOLAS
  //============================================================================
  int _linksChecked = 0;
  int _callsChecked = 0;
  int _malwarePrevented = 0;

  final List<String> _forensicLogs = [];
  List<Map<String, dynamic>> _historicalLogs = [];

  SecurityProvider() {
    // Inicializar coordinador unificado
    _coordinator = SecurityCoordinator(
      phishingEngine: PhishingEngine(),
      callSecurityEngine: CallSecurityEngine(),
      telemetryService: TelemetryService(),
    );
  }

  //============================================================================
  // GETTERS
  //============================================================================
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
  int get linksChecked => _linksChecked;
  int get callsChecked => _callsChecked;
  int get malwarePrevented => _malwarePrevented;
  String? get selectedFileName => _selectedFileName;
  List<String> get forensicLogs => List.unmodifiable(_forensicLogs);
  List<Map<String, dynamic>> get historicalLogs => List.unmodifiable(_historicalLogs);

  //============================================================================
  // INICIALIZACIÓN Y CONTROL
  //============================================================================
  Future<void> initialize() async {
    if (_initialized) return;
    _setLoadingState(true);

    try {
      await _database.database;
      _phoneService.startListening();
      await _loadHistoricalLogs();
      _statusCategory = "CENTINELA OPERATIVO";
      _initialized = true;
    } catch (e) {
      _appendLog("ERROR INICIALIZANDO: $e");
    } finally {
      _setLoadingState(false);
    }
  }

  void updateTabState(int tab) {
    _currentVector = tab;
    final categories = ["ANÁLISIS TELEFÓNICO", "ANÁLISIS PHISHING", "ANÁLISIS MALWARE"];
    if (tab >= 0 && tab < categories.length) {
      _statusCategory = categories[tab];
    }
    notifyListeners();
  }

  Future<bool> pickLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result?.files.single.path == null) return false;

      _selectedFile = File(result!.files.single.path!);
      _selectedFileName = result.files.single.name;
      notifyListeners();
      return true;
    } catch (e) {
      _appendLog("FILE PICKER ERROR: $e");
      return false;
    }
  }

  //============================================================================
  // AUDITORÍA CENTRALIZADA AGÉNTICA
  //============================================================================
  Future<void> executeAuditoria(String target, int vector) async {
    if (target.trim().isEmpty && vector != 2) return;

    _isEnginePatrolling = true;
    _setLoadingState(true);

    _appendLog("===================================================");
    _appendLog("AGENTE CENTINELA EVALUANDO | OBJ: $target | VEC: $vector");

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
      _appendLog("ERROR GENERAL AGÉNTICO: $e");
    } finally {
      _isEnginePatrolling = false;
      _setLoadingState(false);
    }
  }

  //============================================================================
  // PROCESAMIENTO DE VECTORES CON EL COORDINADOR DE IA AGÉNTICA
  //============================================================================
  Future<void> _processCallScan(String target) async {
    _appendLog("Iniciando análisis agéntico de llamada...");
    final result = await _coordinator.scanCall(phoneNumber: target);
    
    double agentScore = (result["agentRiskScore"] ?? result["riskScore"] ?? 0.0).toDouble();
    String verdict = result["verdict"] ?? "DESCONOCIDO";
    String reasoning = result["agentReasoning"] ?? "Sin razonamiento.";

    _callsChecked++;
    _agentReasoningText = reasoning;
    _updateHudWithVerdict(agentScore, verdict);

    _appendLog("RIESGO AGÉNTICO: ${agentScore.toStringAsFixed(1)}% | VEREDICTO: $verdict");
    _appendLog("RAZONAMIENTO: $reasoning");

    await _persistAudit(target, agentScore, verdict, "PHONE", result.toString());
  }

  Future<void> _processUrlScan(String target) async {
    _appendLog("Iniciando análisis agéntico de URL...");
    final result = await _coordinator.scanUrl(target);

    double agentScore = (result["agentRiskScore"] ?? result["riskScore"] ?? 0.0).toDouble();
    String verdict = result["verdict"] ?? "DESCONOCIDO";
    String reasoning = result["agentReasoning"] ?? "Sin razonamiento.";

    _linksChecked++;
    _agentReasoningText = reasoning;
    _updateHudWithVerdict(agentScore, verdict);

    _appendLog("RIESGO AGÉNTICO: ${agentScore.toStringAsFixed(1)}% | VEREDICTO: $verdict");
    _appendLog("RAZONAMIENTO: $reasoning");

    await _persistAudit(target, agentScore, verdict, "URL", result.toString());
  }

  Future<void> _auditFile() async {
    if (_selectedFile == null) {
      _appendLog("No existe archivo seleccionado.");
      return;
    }

    _appendLog("Escaneando archivo local...");
    final verdict = await _fileScanner.scanLocalFile(_selectedFile!);
    final double score = verdict.isCritical ? 100 : (verdict.isWarning ? 60 : 5);

    _malwarePrevented++;
    _agentReasoningText = "Análisis estático de firmas y hashes sobre ejecutable.";
    _updateHudWithVerdict(score, verdict.riskLevel);
    _appendLog("Resultado: ${verdict.riskLevel}");

    await _persistAudit(_selectedFileName ?? "APK_DESCONOCIDO", score, verdict.riskLevel, "MALWARE", verdict.toString());
  }

  Future<void> _persistAudit(String target, double score, String verdict, String vector, String rawDetails) async {
    final nowIso = DateTime.now().toIso8601String();
    await _database.insertScanLog({
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "timestamp": nowIso,
      "target": target,
      "score": score,
      "verdict": verdict,
      "vector": vector,
    });
    await _database.insertForensicLog({
      "timestamp": nowIso,
      "service": vector,
      "activity": target,
      "verdict": verdict,
      "matched_rule": "AGENT_$vector",
      "extra_data": rawDetails,
    });
  }

  //============================================================================
  // GESTIÓN DE ESTADO Y RESET
  //============================================================================
  void _updateHudWithVerdict(double score, String verdict) {
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
      _appendLog("Eliminando registros locales y de memoria...");
      await _database.clearAllLogs();
      _historicalLogs.clear();
      _forensicLogs.clear();
      _linksChecked = 0;
      _callsChecked = 0;
      _malwarePrevented = 0;
      resetHud();
      _statusCategory = "BITÁCORA LIMPIA";
    } catch (e) {
      _appendLog("ERROR LIMPIANDO: $e");
    }
    notifyListeners();
  }

  void resetHud() {
    _vulnerabilityScore = 0;
    _hudColor = Colors.green;
    _verdictText = "SISTEMA OPERATIVO SEGURO";
    _statusCategory = "CENTINELA OPERATIVO";
    _agentReasoningText = "Agente Centinela activo y listo.";
    notifyListeners();
  }

  void clearForensicLogs() {
    _forensicLogs.clear();
    notifyListeners();
  }

  void _appendLog(String text) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    _forensicLogs.add("[$timeStr]  $text");
    if (_forensicLogs.length > 500) _forensicLogs.removeAt(0);
    notifyListeners();
  }

  Future<void> _loadHistoricalLogs() async {
    _historicalLogs = await _database.getScanHistory();
    notifyListeners();
  }

  void _setLoadingState(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setLoading(bool value) => _setLoadingState(value);
  void setStatus(String status) {
    _statusCategory = status;
    notifyListeners();
  }
  Future<void> reloadHistory() async => await _loadHistoricalLogs();

  @override
  void dispose() {
    _phoneService.dispose();
    super.dispose();
  }
}