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

  /// ⚠️ ARQUITECTURA ALPHA UNIFICADA - FORZADO DE CANAL DE RED
  /// IP física fija de tu laptop en el router de tu casa
  static const String _wifiLocalIp = 'http://192.168.1.13:5000';

  /// Endpoint base adaptativo corregido para evitar rebotes de enrutamiento
  static String get _baseUrl => _wifiLocalIp;

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
  /// 🚀 PUENTE DE CONEXIÓN UNIFICADO CON LA API DE FLASK
  /// =====================================================================
  Future<Map<String, dynamic>> scanTarget(String type, String target) async {
    Map<String, dynamic> resultData;

    String normalizedType = type.toUpperCase();
    if (normalizedType == 'TELEFONO' || normalizedType == 'CELLULAR' || normalizedType == 'SPAM') {
      normalizedType = 'SPAM';
    } else if (normalizedType == 'URL' || normalizedType == 'PHISHING') {
      normalizedType = 'PHISHING';
    } else if (normalizedType == 'MALWARE' || normalizedType == 'FILE') {
      normalizedType = 'MALWARE';
    }

    resultData = await _executeNetworkScan(target, normalizedType);
    _syncWithSqlite(target, normalizedType, resultData);

    return resultData;
  }

  /// =====================================================================
  /// 🌐 CLIENTE REST: ESCANEO DE VECTORES EN CALIENTE
  /// =====================================================================
  Future<Map<String, dynamic>> _executeNetworkScan(String target, String type) async {
    final String targetEndpoint = '$_baseUrl/api/v1/scan';
    try {
      print('🛰️ [RED] Centinela enviando payload a: $targetEndpoint');
      
      final response = await http.post(
        Uri.parse(targetEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Connection': 'keep-alive', // 🔧 Fuerza el canal de red a mantenerse abierto
        },
        body: jsonEncode({
          'target': target,
          'type': type,
        }),
      ).timeout(const Duration(seconds: 12)); // Tolerancia extendida para saltar ráfagas de Firewall

      print('📡 [RED] Respuesta recibida HTTP: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        double parsedScore = double.tryParse(data['risk_score']?.toString() ?? '0.12') ?? 0.12;
        String parsedClassification = data['classification']?.toString() ?? 'SAFE';
        String parsedRiskLevel = data['risk_level']?.toString() ?? parsedClassification;
        String parsedScoreLabel = data['score']?.toString() ?? '0';

        return {
          'riskScore': parsedScore,
          'score': parsedScoreLabel,
          'classification': parsedClassification,
          'riskLevel': parsedRiskLevel,
          'metrics': data['metrics'] ?? {"network": 1.0},
          'logs': data['logs'] ?? 'AUDITORÍA CENTRAL: Conexión WiFi local exitosa.',
        };
      } else {
        return _fallbackStaticResult(type, 'Error HTTP de pasarela: ${response.statusCode}');
      }
    } catch (e) {
      print('🚨 [ERROR RED] Falla al conectar con ($_baseUrl): $e');
      return _fallbackStaticResult(type, 'Servidor CORE INALCANZABLE. Fallback 15% Activado.');
    }
  }

  Future<List<dynamic>> fetchScanHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/history'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      print('⚠️ Error al pedir historial: $e');
    }
    return [];
  }

  Future<void> _syncWithSqlite(String target, String type, Map<String, dynamic> localResult) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/v1/sync'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'target': target,
          'type': type,
          'risk_score': localResult['riskScore'],
          'classification': localResult['classification'],
          'logs': localResult['logs'] ?? 'Trazabilidad integrada.',
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Map<String, dynamic> _fallbackStaticResult(String type, String errorReason) {
    return {
      'riskScore': 0.15,
      'score': '0',
      'classification': 'SAFE',
      'riskLevel': 'INDETERMINADO',
      'metrics': {"entropy": 0.0, "fallback": 1.0},
      'logs': 'CONTROL INTERNO: $errorReason'
    };
  }

  AnalysisResult analyze(String phone, List<CallRecord> history) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    
    print('🔍 [DEBUG HEURÍSTICO] Analizando: $cleanPhone | Historial: ${history.length} registros');

    final double entropy = _normalize(_entropyEngine.analyzeNumberStructure(cleanPhone));
    final double frequencyRisk = _normalize(_entropyEngine.analyzeFrequency(history));
    final double timeRisk = _normalize(_normalize(_entropyEngine.analyzeTimeRiskDensity(history)));
    final double durationRisk = _normalize(_entropyEngine.analyzeDurationPattern(history));
    final double communityScore = _normalize(_communityMatrix[cleanPhone] ?? 0.0);

    print('📊 [DEBUG VECTORES] Ent: $entropy, Freq: $frequencyRisk, Time: $timeRisk, Dur: $durationRisk');

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
    
    print('🏁 [DEBUG RESULTADO] Score final: $riskScore | Clasificación: $classification');

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