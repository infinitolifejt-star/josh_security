// lib/services/api_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'core/models.dart';
import 'analytics/entropy_engine.dart';
import 'reputation/reputation_engine.dart';
import 'learning/learning_engine.dart';
import 'security/secure_logger.dart';

class ApiService {
  final EntropyEngine _entropyEngine;
  final ReputationEngine _reputationEngine;
  final LearningEngine _learningEngine;
  final SecureLogger _logger;
  final Map<String, double> _communityMatrix;

  /// Endpoint base adaptativo para la API segura en Flask
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    return 'http://127.0.0.1:5000'; 
  }

  /// Calibración heurística para el ecosistema telefónico colombiano
  final List<String> _validColombianPrefixes = [
    '300', '301', '302', '303', '304', '305', '310', '311', '312', '313', '314', 
    '315', '316', '317', '318', '319', '320', '321', '322', '323', '324', '350', '351'
  ];

  ApiService({
    EntropyEngine? entropyEngine,
    ReputationEngine? reputationEngine,
    LearningEngine? learningEngine,
    SecureLogger? logger,
    Map<String, double>? communityMatrix,
  })  : _entropyEngine = entropyEngine ?? EntropyEngine(),
        _reputationEngine = reputationEngine ?? ReputationEngine(),
        _learningEngine = learningEngine ?? LearningEngine(),
        _logger = logger ?? SecureLogger(),
        _communityMatrix = communityMatrix ?? {};

  /// =====================================================================
  /// 🚀 PUENTE DE CONEXIÓN UNIFICADO CON LA API DE FLASK (Modo Red Completo)
  /// =====================================================================
  Future<Map<String, dynamic>> scanTarget(String type, String target) async {
    Map<String, dynamic> resultData;

    // Normalizar etiquetas para asegurar compatibilidad exacta con los 3 motores de app.py
    String normalizedType = type.toUpperCase();
    if (normalizedType == 'TELEFONO' || normalizedType == 'CELLULAR' || normalizedType == 'SPAM') {
      normalizedType = 'SPAM';
    } else if (normalizedType == 'URL' || normalizedType == 'PHISHING') {
      normalizedType = 'PHISHING';
    } else if (normalizedType == 'MALWARE' || normalizedType == 'FILE') {
      normalizedType = 'MALWARE';
    }

    // CONTROL OPERATIVO: Forzamos a que TODOS los escaneos consuman el Py-Server en vivo
    // Rompemos la simulación local estática para que la persistencia y el historial funcionen.
    resultData = await _executeNetworkScan(target, normalizedType);

    // Sincronización asíncrona de auditoría paralela
    _syncWithSqlite(target, normalizedType, resultData);

    return resultData;
  }

  /// =====================================================================
  /// 🌐 CLIENTE REST: ESCANEO DE VECTORES EN CALIENTE
  /// =====================================================================
  Future<Map<String, dynamic>> _executeNetworkScan(String target, String type) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/v1/scan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'target': target,
          'type': type, // Envía 'SPAM', 'PHISHING' o 'MALWARE' de forma limpia
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'riskScore': data['risk_score'] ?? 0.12,
          'classification': data['classification'] ?? 'SAFE',
          'metrics': data['metrics'] ?? {"network": 1.0},
          'logs': data['logs'] ?? 'AUDITORÍA CENTRAL: Microservicio Centinela estable.',
        };
      } else {
        return _fallbackStaticResult(type, 'Error HTTP de pasarela: ${response.statusCode}');
      }
    } catch (e) {
      return _fallbackStaticResult(type, 'Servidor CORE OFFLINE. Modo resiliencia activado.');
    }
  }

  /// =====================================================================
  /// 🔍 HISTORIAL DINÁMICO: CONSULTA ASÍNCRONA DE REGISTROS DE SESIÓN
  /// =====================================================================
  Future<List<dynamic>> fetchScanHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/history'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      // Retornar logs de contingencia silenciosa si el canal REST está ocupado
    }
    return [];
  }

  /// 🗄️ PERSISTENCIA EN SEGUNDO PLANO
  Future<void> _syncWithSqlite(String target, String type, Map<String, dynamic> localResult) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/v1/sync'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'target': target,
          'type': type,
          'risk_score': localResult['riskScore'],
          'classification': localResult['classification'],
          'logs': localResult['logs'] ?? 'Trazabilidad integrada.',
        }),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  /// 🛡️ MÓDULO DE DEGRADACIÓN SEGURA (FALLBACK)
  Map<String, dynamic> _fallbackStaticResult(String type, String errorReason) {
    return {
      'riskScore': 0.15,
      'classification': 'SAFE',
      'metrics': {"entropy": 0.0, "fallback": 1.0},
      'logs': 'CONTROL INTERNO: $errorReason. Resguardo local preventivo activo.'
    };
  }

  /// Heurística local de respaldo (Mantenida por integridad estructural)
  AnalysisResult analyze(String phone, List<CallRecord> history) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final double entropy = _normalize(_entropyEngine.analyzeNumberStructure(cleanPhone));
    final double frequencyRisk = _normalize(_entropyEngine.analyzeFrequency(history));
    final double timeRisk = _normalize(_entropyEngine.analyzeTimeRiskDensity(history));
    final double durationRisk = _normalize(_entropyEngine.analyzeDurationPattern(history));
    final double communityScore = _normalize(_communityMatrix[cleanPhone] ?? 0.0);

    double riskScore = _reputationEngine.computeRiskScore(
      entropy: entropy,
      frequency: frequencyRisk,
      timeRisk: timeRisk,
      durationRisk: durationRisk,
      communityScore: communityScore,
    );

    bool hasValidPrefix = false;
    for (final prefix in _validColombianPrefixes) {
      if (cleanPhone.startsWith(prefix)) {
        hasValidPrefix = true;
        break;
      }
    }
    if (hasValidPrefix && riskScore > 0.1) {
      riskScore = math.max(0.0, riskScore - 0.20);
    }

    riskScore = _normalize(_learningEngine.adjustScore(riskScore));
    final String classification = _reputationEngine.classify(riskScore);

    return AnalysisResult(
      riskScore: riskScore,
      classification: classification,
      metrics: {"entropy": entropy, "calibrated": hasValidPrefix ? 1.0 : 0.0},
    );
  }

  double _normalize(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    if (value < 0.0) return 0.0;
    if (value > 1.0) return 1.0;
    return value;
  }
}

typedef PhoneHeuristicEngine = ApiService;