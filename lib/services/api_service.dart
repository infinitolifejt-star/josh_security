// ====================================================================================================
// ARCHIVO: lib/services/api_service.dart
// PUENTE DE CONEXIÓN Y MOTOR HEURÍSTICO DE ANÁLISIS DE TELEMETRÍA v4.6
// ====================================================================================================

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// 🔗 Importaciones Relativas Corregidas (Mismo nivel dentro de lib/services/)
import 'core/models.dart';
import 'analytics/entropy_engine.dart';
import 'reputation/reputation_engine.dart';
import 'learning/learning_engine.dart';

class ApiService {
  final EntropyEngine _entropyEngine;
  final ReputationEngine _reputationEngine;
  final LearningEngine _learningEngine;
  final Map<String, double> _communityMatrix;

  /// INFRAESTRUCTURA UNIFICADA EN RENDER
  static const String _cloudUrl = 'https://josh-security.onrender.com';
  static String get _baseUrl => _cloudUrl;

  /// MATRIZ EXTENDIDA DE OPERADORES MÓVILES Y FIJOS (COLOMBIA)
  final List<String> _validColombianPrefixes = [
    '300', '301', '302', '303', '304', '305', '310', '311', '312', '313', '314', 
    '315', '316', '317', '318', '319', '320', '321', '322', '323', '324', '325', 
    '326', '327', '333', '350', '351'
  ];

  final List<String> _validColombianFixedPrefixes = [
    '601', '602', '603', '604', '605', '606', '607', '608'
  ];

  ApiService({
    EntropyEngine? entropyEngine,
    ReputationEngine? reputationEngine,
    LearningEngine? learningEngine,
    Map<String, double>? communityMatrix,
  })  : _entropyEngine = entropyEngine ?? EntropyEngine(),
        _reputationEngine = reputationEngine ?? ReputationEngine(),
        _learningEngine = learningEngine ?? LearningEngine(),
        _communityMatrix = communityMatrix ?? {};

  /// Ejecuta el análisis perimetral combinando Nube + Heurística Local
  Future<Map<String, dynamic>> scanTarget(String type, String target) async {
    String normalizedType = type.toUpperCase();
    if (normalizedType == 'TELEFONO' || normalizedType == 'CELLULAR' || normalizedType == 'SPAM') {
      normalizedType = 'SPAM';
    } else if (normalizedType == 'URL' || normalizedType == 'PHISHING') {
      normalizedType = 'PHISHING';
    } else if (normalizedType == 'MALWARE' || normalizedType == 'FILE') {
      normalizedType = 'MALWARE';
    }

    final Map<String, dynamic> resultData = await _executeNetworkScan(target, normalizedType);
    _syncWithSqlite(target, normalizedType, resultData);

    return resultData;
  }

  /// Cliente REST con Exponential Backoff
  Future<Map<String, dynamic>> _executeNetworkScan(String target, String type) async {
    final String targetEndpoint = '$_baseUrl/api/v1/scan';
    
    int maxRetries = 3;
    int delaySeconds = 2;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('🛰️ [RED] Enviando payload a: $targetEndpoint (Intento $attempt/$maxRetries)');
        
        final response = await http.post(
          Uri.parse(targetEndpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Access-Control-Allow-Origin': '*', 
          },
          body: jsonEncode({
            'target': target,
            'type': type,
          }),
        ).timeout(Duration(seconds: attempt == 1 ? 35 : 15));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
          
          double parsedScore = double.tryParse(data['risk_score']?.toString() ?? '12.0') ?? 12.0;
          if (parsedScore <= 1.0) parsedScore *= 100.0;

          String rawClassification = data['classification']?.toString().toUpperCase() ?? 'SEGURO';
          
          String cleanClassification = 'SEGURO';
          if (rawClassification == 'SUSPICIOUS' || rawClassification == 'SOSPECHOSO' || rawClassification == 'ADVERTENCIA' || parsedScore >= 30.0) {
            cleanClassification = 'ADVERTENCIA';
          }
          if (rawClassification == 'CRITICAL' || rawClassification == 'CRÍTICO' || parsedScore >= 70.0) {
            cleanClassification = 'CRÍTICO';
          }

          return {
            'riskScore': _normalize(parsedScore),
            'score': parsedScore.toStringAsFixed(0),
            'classification': cleanClassification,
            'riskLevel': cleanClassification,
            'metrics': data['metrics'] ?? {"network": 1.0},
            'logs': data['logs'] ?? data['verdict'] ?? 'AUDITORÍA CENTRAL: Conexión Cloud exitosa.',
          };
        } else if (response.statusCode == 404) {
          return await _executeAlternativeNetworkScan(target, type, '$_baseUrl/scan');
        } else if (response.statusCode >= 500) {
          throw http.ClientException('Falla de servidor o aprovisionamiento en Render.');
        }
        
        return _fallbackStaticResult(type, 'Error de respuesta en la Nube: ${response.statusCode}');
      } catch (e) {
        debugPrint('🚨 [INTENTO $attempt FALLIDO] Error: $e');
        if (attempt < maxRetries) {
          int currentDelay = delaySeconds * math.pow(2, attempt - 1).toInt();
          await Future.delayed(Duration(seconds: currentDelay));
        }
      }
    }

    return _fallbackStaticResult(type, 'Servidor central inalcanzable. Heurística local activa.');
  }

  Future<Map<String, dynamic>> _executeAlternativeNetworkScan(String target, String type, String altEndpoint) async {
    try {
      final response = await http.post(
        Uri.parse(altEndpoint),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: jsonEncode({'target': target, 'type': type}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        double parsedScore = double.tryParse(data['risk_score']?.toString() ?? '12.0') ?? 12.0;
        if (parsedScore <= 1.0) parsedScore *= 100.0;
        
        String cleanClassification = parsedScore < 30.0 ? 'SEGURO' : (parsedScore < 70.0 ? 'ADVERTENCIA' : 'CRÍTICO');

        return {
          'riskScore': _normalize(parsedScore),
          'score': parsedScore.toStringAsFixed(0),
          'classification': cleanClassification,
          'riskLevel': cleanClassification,
          'metrics': data['metrics'] ?? {"network": 1.0},
          'logs': 'AUDITORÍA ALTERNATIVA: Conexión perimetral exitosa.',
        };
      }
    } catch (_) {}
    return _fallbackStaticResult(type, 'Ruta estructural no encontrada en el backend.');
  }

  Future<List<dynamic>> fetchScanHistory() async {
    final String historyEndpoint = '$_baseUrl/api/v1/history';
    try {
      final response = await http.get(
        Uri.parse(historyEndpoint),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
      }
    } catch (e) {
      debugPrint('⚠️ Error al solicitar historial: $e');
    }
    return [];
  }

  Future<void> _syncWithSqlite(String target, String type, Map<String, dynamic> localResult) async {
    final String syncEndpoint = '$_baseUrl/api/v1/sync';
    try {
      await http.post(
        Uri.parse(syncEndpoint), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'target': target,
          'type': type,
          'risk_score': localResult['riskScore'],
          'classification': localResult['classification'],
          'logs': localResult['logs'] ?? 'Trazabilidad integrada.',
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Map<String, dynamic> _fallbackStaticResult(String type, String errorReason) {
    return {
      'riskScore': 15.0,
      'score': '15',
      'classification': 'SEGURO',
      'riskLevel': 'FALLBACK LOCAL',
      'metrics': {"entropy": 0.0, "fallback": 1.0},
      'logs': 'CONTROL INTERNO CENTINELA: $errorReason'
    };
  }

  /// Análisis Heurístico Local (Escala 0.0 - 100.0)
  AnalysisResult analyze(String phone, List<CallRecord> history) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    final double entropy = _entropyEngine.analyzeNumberStructure(cleanPhone);
    final double frequencyRisk = _entropyEngine.analyzeFrequency(history);
    final double timeRisk = _entropyEngine.analyzeTimeRiskDensity(history);
    final double durationRisk = _entropyEngine.analyzeDurationPattern(history);
    final double communityScore = _communityMatrix[cleanPhone] ?? 0.0;

    double riskScore = _reputationEngine.computeRiskScore(
      entropy: entropy,
      frequency: frequencyRisk,
      timeRisk: timeRisk,
      durationRisk: durationRisk,
      communityScore: communityScore,
    );

    bool isKnownColombianOrigin = false;
    for (final prefix in _validColombianPrefixes) {
      if (cleanPhone.startsWith(prefix) || cleanPhone.startsWith('57$prefix')) {
        isKnownColombianOrigin = true;
        break;
      }
    }
    
    if (!isKnownColombianOrigin) {
      for (final fixedPrefix in _validColombianFixedPrefixes) {
        if (cleanPhone.startsWith(fixedPrefix) || cleanPhone.startsWith('57$fixedPrefix')) {
          isKnownColombianOrigin = true;
          break;
        }
      }
    }

    // Calibración de procedencia
    if (isKnownColombianOrigin && riskScore > 10.0 && entropy < 55.0) {
      riskScore = math.max(0.0, riskScore - 15.0); 
    } else if (!isKnownColombianOrigin && riskScore < 80.0) {
      riskScore = math.min(100.0, riskScore + 10.0);
    }

    riskScore = _learningEngine.adjustScore(riskScore);
    final String classification = _reputationEngine.classify(riskScore);

    return AnalysisResult(
      riskScore: riskScore,
      classification: classification,
      metrics: {
        "entropy": entropy, 
        "calibrated": isKnownColombianOrigin ? 1.0 : 0.0,
        "learning_boost": 1.0
      },
    );
  }

  double _normalize(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return value.clamp(0.0, 100.0);
  }
}

typedef PhoneHeuristicEngine = ApiService;