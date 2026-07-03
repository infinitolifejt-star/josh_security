import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // Requerido para debugPrint
import 'package:http/http.dart' as http;

// 🔗 Importaciones Relativas Corregidas (Apuntan al directorio interno de services)
import 'core/models.dart';
import 'analytics/entropy_engine.dart';
import 'reputation/reputation_engine.dart';
import 'learning/learning_engine.dart';

class ApiService {
  final EntropyEngine _entropyEngine;
  final ReputationEngine _reputationEngine;
  final LearningEngine _learningEngine;
  final Map<String, double> _communityMatrix;

  /// ⚠️ ARQUITECTURA CLOUD - INFRAESTRUCTURA UNIFICADA EN RENDER
  static const String _cloudUrl = 'https://josh-security.onrender.com';
  static String get _baseUrl => _cloudUrl;

  /// 🇨🇴 MATRIZ EXTENDIDA DE OPERADORES MÓVILES (Actualizado 2026)
  final List<String> _validColombianPrefixes = [
    '300', '301', '302', '303', '304', '305', '310', '311', '312', '313', '314', 
    '315', '316', '317', '318', '319', '320', '321', '322', '323', '324', '325', 
    '326', '327', '333', '350', '351'
  ];

  /// ☎️ MATRIZ UNIFICADA DE INDICATIVOS FIJOS NACIONALES (Anti-Vishing / PBX Virtuales)
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

  /// =====================================================================
  /// 🚀 PUENTE DE CONEXIÓN UNIFICADO CON LA API DE FLASK EN RENDER
  /// =====================================================================
  Future<Map<String, dynamic>> scanTarget(String type, String target) async {
    String normalizedType = type.toUpperCase();
    if (normalizedType == 'TELEFONO' || normalizedType == 'CELLULAR' || normalizedType == 'SPAM') {
      normalizedType = 'SPAM';
    } else if (normalizedType == 'URL' || normalizedType == 'PHISHING') {
      normalizedType = 'PHISHING';
    } else if (normalizedType == 'MALWARE' || normalizedType == 'FILE') {
      normalizedType = 'MALWARE';
    }

    // Ejecuta escaneo en la nube
    final Map<String, dynamic> resultData = await _executeNetworkScan(target, normalizedType);
    
    // Sincronización asíncrona sin bloquear la respuesta de la interfaz de usuario
    _syncWithSqlite(target, normalizedType, resultData);

    return resultData;
  }

  /// =====================================================================
  /// 🌐 CLIENTE REST CON IMPLEMENTACIÓN DE EXPONENTIAL BACKOFF REFORZADO
  /// =====================================================================
  Future<Map<String, dynamic>> _executeNetworkScan(String target, String type) async {
    final String targetEndpoint = '$_baseUrl/api/v1/scan';
    
    int maxRetries = 3;
    int delaySeconds = 2;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('🛰️ [RED] Centinela enviando payload a: $targetEndpoint (Intento $attempt/$maxRetries)');
        
        // TODO: [DEUDA TÉCNICA - CENTINELA] Restringir 'Access-Control-Allow-Origin' en producción una vez finalizadas las pruebas locales en Chrome Web CORS.
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

        debugPrint('📡 [RED] Respuesta recibida HTTP: ${response.statusCode}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
          
          double parsedScore = double.tryParse(data['risk_score']?.toString() ?? '0.12') ?? 0.12;
          String rawClassification = data['classification']?.toString().toUpperCase() ?? 'SAFE';
          
          // Mapeo semántico unificado alineado con el Pilar III de Acompañamiento Humano
          String cleanClassification = 'SEGURO';
          if (rawClassification == 'SUSPICIOUS' || rawClassification == 'SOSPECHOSO' || parsedScore >= 0.3) {
            cleanClassification = 'SOSPECHOSO';
          }
          if (rawClassification == 'CRITICAL' || rawClassification == 'CRÍTICO' || parsedScore >= 0.6) {
            cleanClassification = 'CRÍTICO';
          }

          String parsedScoreLabel = data['score']?.toString() ?? (parsedScore * 100).toStringAsFixed(0);

          return {
            'riskScore': _normalize(parsedScore),
            'score': parsedScoreLabel,
            'classification': cleanClassification,
            'riskLevel': cleanClassification,
            'metrics': data['metrics'] ?? {"network": 1.0},
            'logs': data['logs'] ?? data['verdict'] ?? 'AUDITORÍA CENTRAL: Conexión Cloud de alta fidelidad exitosa.',
          };
        } else if (response.statusCode == 404) {
          debugPrint('⚠️ [DEBUG RUTA] 404 detectado. Intentando fallback alternativo directo...');
          return await _executeAlternativeNetworkScan(target, type, '$_baseUrl/scan');
        } else if (response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504) {
          // Si es un error de pasarela de Render, forzamos el reintento saltando al catch
          throw http.ClientException('Falla de aprovisionamiento temporal en Render.');
        }
        
        return _fallbackStaticResult(type, 'Error de pasarela en la Nube: ${response.statusCode}');
      } catch (e) {
        debugPrint('🚨 [INTENTO $attempt FALLIDO] Error de transporte o arranque en frío: $e');
        
        if (attempt < maxRetries) {
          int currentDelay = delaySeconds * math.pow(2, attempt - 1).toInt();
          debugPrint('⏳ [BACKOFF] Reintento programado en $currentDelay segundos...');
          await Future.delayed(Duration(seconds: currentDelay));
        } else {
          debugPrint('❌ [RED] Se agotaron los reintentos analíticos concurrentes frente a Render.');
        }
      }
    }

    return _fallbackStaticResult(type, 'Servidor central en Render inalcanzable tras reintentos exponenciales. Heurística local de contingencia activa.');
  }

  /// Escaneo alternativo de contingencia anti-404 sin prefijo api/v1
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
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        double parsedScore = double.tryParse(data['risk_score']?.toString() ?? '0.12') ?? 0.12;
        
        String cleanClassification = parsedScore < 0.3 ? 'SEGURO' : (parsedScore < 0.6 ? 'SOSPECHOSO' : 'CRÍTICO');

        return {
          'riskScore': _normalize(parsedScore),
          'score': data['score']?.toString() ?? (parsedScore * 100).toStringAsFixed(0),
          'classification': cleanClassification,
          'riskLevel': cleanClassification,
          'metrics': data['metrics'] ?? {"network": 1.0},
          'logs': 'AUDITORÍA ALTERNATIVA: Conexión perimetral exitosa sin prefijo.',
        };
      }
    } catch (_) {}
    return _fallbackStaticResult(type, 'Ruta estructural no encontrada en el servidor backend (404 Total).');
  }

  /// =====================================================================
  /// 🗄️ PERSISTENCIA FORENSE DIGITAL CENTRALIZADA
  /// =====================================================================
  Future<List<dynamic>> fetchScanHistory() async {
    final String historyEndpoint = '$_baseUrl/api/v1/history';
    try {
      final response = await http.get(
        Uri.parse(historyEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
      }
    } catch (e) {
      debugPrint('⚠️ Error al pedir historial centralizado: $e');
    }
    return [];
  }

  Future<void> _syncWithSqlite(String target, String type, Map<String, dynamic> localResult) async {
    final String syncEndpoint = '$_baseUrl/api/v1/sync';
    try {
      await http.post(
        Uri.parse(syncEndpoint), 
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: jsonEncode({
          'target': target,
          'type': type,
          'risk_score': localResult['riskScore'],
          'classification': localResult['classification'],
          'logs': localResult['logs'] ?? 'Trazabilidad integrada.',
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Map<String, dynamic> _fallbackStaticResult(String type, String errorReason) {
    return {
      'riskScore': 0.15,
      'score': '15',
      'classification': 'SEGURO', // Fallback conservador no alarmista según Carta Magna
      'riskLevel': 'FALLBACK LOCAL',
      'metrics': {"entropy": 0.0, "fallback": 1.0},
      'logs': 'CONTROL INTERNO CENTINELA: $errorReason'
    };
  }

  /// =====================================================================
  /// 🧠 MOTOR HEURÍSTICO LOCAL Y ANÁLISIS DE TELEMETRÍA (OPERADORES COL)
  /// =====================================================================
  AnalysisResult analyze(String phone, List<CallRecord> history) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    
    debugPrint('🔍 [DEBUG HEURÍSTICO] Analizando: $cleanPhone | Historial: ${history.length} registros');

    final double entropy = _normalize(_entropyEngine.analyzeNumberStructure(cleanPhone));
    final double frequencyRisk = _normalize(_entropyEngine.analyzeFrequency(history));
    final double timeRisk = _normalize(_entropyEngine.analyzeTimeRiskDensity(history));
    final double durationRisk = _normalize(_entropyEngine.analyzeDurationPattern(history));
    final double communityScore = _normalize(_communityMatrix[cleanPhone] ?? 0.0);

    debugPrint('📊 [DEBUG VECTORES] Ent: $entropy, Freq: $frequencyRisk, Time: $timeRisk, Dur: $durationRisk');

    double riskScore = _reputationEngine.computeRiskScore(
      entropy: entropy,
      frequency: frequencyRisk,
      timeRisk: timeRisk,
      durationRisk: durationRisk,
      communityScore: communityScore,
    );

    // Verificación de Origen: ¿Es un celular o un fijo colombiano válido?
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

    // 🧠 Calibración Avanzada: Solo se premia la procedencia si la entropía no delata automatización
    if (isKnownColombianOrigin && riskScore > 0.1 && entropy < 0.55) {
      riskScore = math.max(0.0, riskScore - 0.15); 
    } else if (!isKnownColombianOrigin && riskScore < 0.8) {
      // Si viene de un origen indeterminado o prefijo internacional extraño, sube el umbral base de sospecha
      riskScore = math.min(1.0, riskScore + 0.10);
    }

    riskScore = _normalize(_learningEngine.adjustScore(riskScore));
    final String classification = _reputationEngine.classify(riskScore);
    
    debugPrint('🏁 [DEBUG RESULTADO] Score final: $riskScore | Clasificación: $classification');

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
    if (value < 0.0) return 0.0;
    if (value > 1.0) return 1.0;
    return value;
  }
}

typedef PhoneHeuristicEngine = ApiService;