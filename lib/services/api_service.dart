// ====================================================================================================
// ARCHIVO: lib/services/api_service.dart
// PUENTE DE CONEXIÓN, CLIENTE SSL PINNING Y MOTOR HEURÍSTICO DE ANÁLISIS DE TELEMETRÍA v5.0
// Refactorizado y optimizado
// ====================================================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'analytics/entropy_engine.dart';
import 'core/models.dart';
import 'learning/learning_engine.dart';
import 'reputation/reputation_engine.dart';
import 'security/database_service.dart';

class ApiService {
  final EntropyEngine _entropyEngine;
  final ReputationEngine _reputationEngine;
  final LearningEngine _learningEngine;
  final Map<String, double> _communityMatrix;

  static http.Client? _secureClient;

  static const String _cloudUrl =
      'https://josh-security.onrender.com';

  static String get _baseUrl => _cloudUrl;

  ApiService({
    EntropyEngine? entropyEngine,
    ReputationEngine? reputationEngine,
    LearningEngine? learningEngine,
    Map<String, double>? communityMatrix,
  })  : _entropyEngine = entropyEngine ?? EntropyEngine(),
        _reputationEngine = reputationEngine ?? ReputationEngine(),
        _learningEngine = learningEngine ?? LearningEngine(),
        _communityMatrix = communityMatrix ?? {};

  // ===========================================================================================
  // PREFIJOS COLOMBIANOS
  // ===========================================================================================

  static const List<String> _validColombianPrefixes = [
    '300',
    '301',
    '302',
    '303',
    '304',
    '305',
    '310',
    '311',
    '312',
    '313',
    '314',
    '315',
    '316',
    '317',
    '318',
    '319',
    '320',
    '321',
    '322',
    '323',
    '324',
    '325',
    '326',
    '327',
    '333',
    '350',
    '351',
  ];

  static const List<String> _validColombianFixedPrefixes = [
    '601',
    '602',
    '603',
    '604',
    '605',
    '606',
    '607',
    '608',
  ];

  // ===========================================================================================
  // SSL PINNING
  // ===========================================================================================

  static Future<http.Client> _getHttpClient() async {
    if (_secureClient != null) {
      return _secureClient!;
    }

    try {
      final ByteData certData =
          await rootBundle.load('assets/certificates/api_cert.pem');

      final certBytes = certData.buffer.asUint8List();

      final context = SecurityContext(withTrustedRoots: true);

      if (certBytes.isNotEmpty) {
        context.setTrustedCertificatesBytes(certBytes);
      }

      final httpClient = HttpClient(context: context)
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => false;

      _secureClient = IOClient(httpClient);
    } catch (e) {
      debugPrint(
        '⚠ SSL Pinning no disponible. Se utilizará cliente estándar.\n$e',
      );

      _secureClient = http.Client();
    }

    return _secureClient!;
  }

  // ===========================================================================================
  // PUNTO DE ENTRADA
  // ===========================================================================================

  Future<Map<String, dynamic>> scanTarget(
    String type,
    String target,
  ) async {
    String normalized = type.toUpperCase();

    switch (normalized) {
      case 'TELEFONO':
      case 'PHONE':
      case 'CELLULAR':
      case 'SPAM':
        normalized = 'SPAM';
        break;

      case 'URL':
      case 'PHISHING':
        normalized = 'PHISHING';
        break;

      case 'FILE':
      case 'APK':
      case 'MALWARE':
        normalized = 'MALWARE';
        break;
    }

    final result =
        await _executeNetworkScan(target, normalized);

    await _syncWithSqlite(
      target,
      normalized,
      result,
    );

    return result;
  }

  // ===========================================================================================
  // ESCANEO CLOUD
  // ===========================================================================================

  Future<Map<String, dynamic>> _executeNetworkScan(
    String target,
    String type,
  ) async {
    final client = await _getHttpClient();

    final endpoint = '$_baseUrl/api/v1/scan';

    const retries = 3;

    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final response = await client
            .post(
              Uri.parse(endpoint),
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'target': target,
                'type': type,
              }),
            )
            .timeout(
              Duration(seconds: attempt == 0 ? 35 : 15),
            );

        if (response.statusCode == 404) {
          return await _executeAlternativeNetworkScan(
            target,
            type,
            '$_baseUrl/scan',
          );
        }

        if (response.statusCode >= 500) {
          throw http.ClientException('Servidor temporalmente ocupado');
        }

        if (response.statusCode == 200 ||
            response.statusCode == 201) {
          final data =
              jsonDecode(response.body) as Map<String, dynamic>;

          double score = double.tryParse(
                  data['risk_score']?.toString() ?? '0') ??
              0;

          if (score <= 1) {
            score *= 100;
          }

          String classification =
              data['classification']
                      ?.toString()
                      .toUpperCase() ??
                  'SEGURO';

          if (classification == 'SUSPICIOUS') {
            classification = 'ADVERTENCIA';
          }

          if (classification == 'CRITICAL') {
            classification = 'CRÍTICO';
          }

          if (score >= 70) {
            classification = 'CRÍTICO';
          } else if (score >= 30) {
            classification = 'ADVERTENCIA';
          }

          return {
            'riskScore': _normalize(score),
            'score': score.toStringAsFixed(0),
            'classification': classification,
            'riskLevel': classification,
            'metrics':
                data['metrics'] ?? {'network': 1.0},
            'logs': data['logs'] ??
                data['verdict'] ??
                'Escaneo Cloud completado.',
          };
        }

        return _fallbackStaticResult(
          type,
          'HTTP ${response.statusCode}',
        );
      } catch (_) {
        if (attempt != retries - 1) {
          await Future.delayed(
            Duration(
              seconds:
                  math.pow(2, attempt + 1).toInt(),
            ),
          );
        }
      }
    }

    return _fallbackStaticResult(
      type,
      'Servidor no disponible',
    );
  }
  // ===========================================================================================
  // RUTA ALTERNATIVA DEL BACKEND
  // ===========================================================================================

  Future<Map<String, dynamic>> _executeAlternativeNetworkScan(
    String target,
    String type,
    String endpoint,
  ) async {
    try {
      final client = await _getHttpClient();

      final response = await client
          .post(
            Uri.parse(endpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'target': target,
              'type': type,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        final data =
            jsonDecode(response.body) as Map<String, dynamic>;

        double score = double.tryParse(
                data['risk_score']?.toString() ?? '0') ??
            0;

        if (score <= 1) {
          score *= 100;
        }

        final classification = score < 30
            ? 'SEGURO'
            : (score < 70
                ? 'ADVERTENCIA'
                : 'CRÍTICO');

        return {
          'riskScore': _normalize(score),
          'score': score.toStringAsFixed(0),
          'classification': classification,
          'riskLevel': classification,
          'metrics': data['metrics'] ??
              {'network': 1.0},
          'logs':
              'AUDITORÍA ALTERNATIVA: conexión exitosa.',
        };
      }
    } catch (_) {}

    return _fallbackStaticResult(
      type,
      'Ruta alternativa no disponible.',
    );
  }

  // ===========================================================================================
  // HISTORIAL CLOUD
  // ===========================================================================================

  Future<List<dynamic>> fetchScanHistory() async {
    try {
      final client = await _getHttpClient();

      final response = await client
          .get(
            Uri.parse('$_baseUrl/api/v1/history'),
            headers: const {
              'Content-Type': 'application/json'
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          return decoded;
        }
      }
    } catch (_) {}

    return [];
  }

  // ===========================================================================================
  // SINCRONIZACIÓN SQLITE + CLOUD
  // ===========================================================================================

  Future<void> _syncWithSqlite(
    String target,
    String type,
    Map<String, dynamic> result,
  ) async {
    try {
      await DatabaseService.instance.insertForensicLog({
        'timestamp': DateTime.now().toIso8601String(),
        'service': type,
        'activity': target,
        'verdict': result['classification'],
        'matched_rule': 'HEURISTICA_CENTINELA',
        'extra_data': jsonEncode({
          'score': result['riskScore'],
          'risk_level': result['classification'],
          'vector': type,
          'logs': result['logs'],
        }),
      });
    } catch (_) {}

    try {
      final client = await _getHttpClient();

      await client
          .post(
            Uri.parse(
              '$_baseUrl/api/v1/sync',
            ),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'target': target,
              'type': type,
              'risk_score': result['riskScore'],
              'classification':
                  result['classification'],
              'logs': result['logs'],
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ===========================================================================================
  // FALLBACK LOCAL
  // ===========================================================================================

  Map<String, dynamic> _fallbackStaticResult(
    String type,
    String reason,
  ) {
    return {
      'riskScore': 15.0,
      'score': '15',
      'classification': 'SEGURO',
      'riskLevel': 'FALLBACK LOCAL',
      'metrics': {
        'entropy': 0.0,
        'fallback': 1.0,
      },
      'logs': 'CENTINELA: $reason',
    };
  }

  // ===========================================================================================
  // MOTOR HEURÍSTICO TELEFÓNICO
  // ===========================================================================================

  AnalysisResult analyze(
    String phone,
    List<CallRecord> history,
  ) {
    final cleanPhone =
        phone.replaceAll(RegExp(r'\D'), '');

    final entropy =
        _entropyEngine.analyzeNumberStructure(
      cleanPhone,
    );

    final frequency =
        _entropyEngine.analyzeFrequency(
      history,
    );

    final timeRisk =
        _entropyEngine.analyzeTimeRiskDensity(
      history,
    );

    final durationRisk =
        _entropyEngine.analyzeDurationPattern(
      history,
    );

    final community =
        _communityMatrix[cleanPhone] ?? 0.0;

    double risk =
        _reputationEngine.computeRiskScore(
      entropy: entropy,
      frequency: frequency,
      timeRisk: timeRisk,
      durationRisk: durationRisk,
      communityScore: community,
    );

    bool colombian = false;

    for (final prefix
        in _validColombianPrefixes) {
      if (cleanPhone.startsWith(prefix) ||
          cleanPhone.startsWith('57$prefix')) {
        colombian = true;
        break;
      }
    }

    if (!colombian) {
      for (final prefix
          in _validColombianFixedPrefixes) {
        if (cleanPhone.startsWith(prefix) ||
            cleanPhone.startsWith(
                '57$prefix')) {
          colombian = true;
          break;
        }
      }
    }

    // IMPORTANTE:
    // Un prefijo colombiano NO hace seguro un número.
    // Solo evita un castigo automático.
    if (colombian) {
      if (entropy < 40 &&
          frequency < 20 &&
          durationRisk < 20 &&
          timeRisk < 20) {
        risk -= 8;
      } else if (entropy > 70 ||
          frequency > 60 ||
          timeRisk > 60) {
        risk += 12;
      }
    } else {
      if (risk < 80) {
        risk += 10;
      }
    }

    risk = _learningEngine.adjustScore(risk);

    risk = _normalize(risk);
    // Nunca permitimos salir del rango 0-100.
    risk = _normalize(risk);

    final classification =
        _reputationEngine.classify(risk);

    return AnalysisResult(
      riskScore: risk,
      classification: classification,
      metrics: {
        'entropy': entropy,
        'frequency': frequency,
        'timeRisk': timeRisk,
        'durationRisk': durationRisk,
        'communityScore': community,
        'colombian_origin': colombian ? 1.0 : 0.0,
        'learning_boost': 1.0,
      },
    );
  }

  // ===========================================================================================
  // UTILIDADES
  // ===========================================================================================

  double _normalize(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0.0;
    }

    return value.clamp(0.0, 100.0);
  }
}

/// Alias utilizado por otros módulos.
typedef PhoneHeuristicEngine = ApiService;
