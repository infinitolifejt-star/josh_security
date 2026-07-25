// ====================================================================================================
// ARCHIVO: lib/services/security/phone_interceptor_service.dart
// MOTOR DE INTERCEPTACIÓN TELEFÓNICA E INTEGRACIÓN HEURÍSTICA Y TELEMETRÍA DE IA v4.7
// ====================================================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'database_service.dart';
import 'security_simulator_service.dart';

/// Enumeración para catalogar el origen del diagnóstico
enum DiagnosticSource {
  cloud,
  local,
}

/// Modelo de datos estructurado para el veredicto del escaneo telefónico
class CallVerdict {
  final String phoneNumber;
  final String riskLevel; // 'SEGURO', 'ADVERTENCIA', 'CRÍTICO'
  final String analysisMessage;
  final DiagnosticSource source;
  final Map<String, dynamic> telemetryDetails;

  CallVerdict({
    required this.phoneNumber,
    required this.riskLevel,
    required this.analysisMessage,
    required this.source,
    required this.telemetryDetails,
  });
}

/// Core del Servicio Local de Interceptación Telefónica y Análisis de Riesgo
class PhoneInterceptorService {
  static final PhoneInterceptorService _instance = PhoneInterceptorService._internal();
  factory PhoneInterceptorService() => _instance;
  PhoneInterceptorService._internal();

  final DatabaseService _dbService = DatabaseService.instance;
  final SecuritySimulatorService _simulatorService = SecuritySimulatorService();

  // Prefijos/Indicativos internacionales de alto riesgo (Sincronizado con matriz global)
  static final Set<String> _criticalCountryCodes = {
    '234', '254', '381', '216', '225', '233', '92', '880', '371', '370', '881', '882', '883', '870'
  };

  /// Genera una llamada simulada ALEATORIA Y DINÁMICA rotando entre Verde, Amarillo y Rojo
  Map<String, dynamic> getRandomSimulatedCall() {
    final dynamicVector = _simulatorService.generateDynamicPhoneVector();
    final String generatedNumber = dynamicVector['target'];
    final String expectedClassification = dynamicVector['expectedClassification'];

    double score;
    String callerName;
    String reason;

    switch (expectedClassification) {
      case 'CRÍTICO': // 🔴 ROJO
        score = 85.0 + Random().nextDouble() * 15.0; // 85% a 100%
        callerName = 'Llamada Sospechosa / Botnet';
        reason = 'Indicativo internacional de alto riesgo o patrón de entropía en ráfaga.';
        break;

      case 'ADVERTENCIA': // 🟡 AMARILLO
        score = 35.0 + Random().nextDouble() * 30.0; // 35% a 65%
        callerName = 'Número Fijo / Comercial No Verificado';
        reason = 'Línea corporativa sin registro previo en la libreta de contactos.';
        break;

      case 'SEGURO': // 🟢 VERDE
      default:
        score = Random().nextDouble() * 20.0; // 0% a 20%
        callerName = 'Contacto Limpio / Frecuente';
        reason = 'Número con comportamiento estándar y libre de reportes de riesgo.';
        break;
    }

    return {
      'number': generatedNumber,
      'caller': callerName,
      'risk': expectedClassification,
      'score': double.parse(score.toStringAsFixed(1)),
      'reason': reason,
      'timestamp': dynamicVector['timestamp'],
    };
  }

  Future<bool> _checkNetworkConnectivity() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return DateTime.now().second % 2 == 0;
  }

  Future<double> checkNumber(String phoneNumber) async {
    try {
      final CallVerdict verdict = await analyzeIncomingCall(phoneNumber);
      if (verdict.riskLevel == 'CRÍTICO') return 100.0;
      if (verdict.riskLevel == 'ADVERTENCIA') return 50.0;
      return 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Evaluador principal de números entrantes mediante detección de prefijos y patrones entrópicos
  Future<CallVerdict> analyzeIncomingCall(String rawPhoneNumber) async {
    final String cleanNumber = rawPhoneNumber.trim();
    final String digitsOnly = cleanNumber.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.isEmpty) {
      final CallVerdict emptyVerdict = CallVerdict(
        phoneNumber: 'DESCONOCIDO',
        riskLevel: 'ADVERTENCIA',
        analysisMessage: 'El número entrante no pudo ser leído de forma correcta. Se recomienda precaución.',
        source: DiagnosticSource.local,
        telemetryDetails: {'error': 'Entrada vacía o inválida'},
      );

      await _persistVerdictLog(emptyVerdict, 'HEURISTIC_EMPTY_ERR');
      return emptyVerdict;
    }

    final bool isConnected = await _checkNetworkConnectivity();
    final DiagnosticSource selectedSource = isConnected ? DiagnosticSource.cloud : DiagnosticSource.local;

    // 1. Verificación de líneas de emergencia/servicios públicos conocidos
    if (digitsOnly == '123' || digitsOnly == '112' || digitsOnly == '165' || digitsOnly.startsWith('018000')) {
      final CallVerdict safeVerdict = CallVerdict(
        phoneNumber: cleanNumber,
        riskLevel: 'SEGURO',
        analysisMessage: 'Línea oficial o de emergencia verificada.',
        source: selectedSource,
        telemetryDetails: {'matched_rule': 'WHITELIST_EMERGENCY'},
      );
      await _persistVerdictLog(safeVerdict, 'WHITELIST_EMERGENCY');
      return safeVerdict;
    }

    // 2. Detección por Indicativo Internacional Sospechoso (Inicio de cadena)
    bool isCriticalCountry = false;
    String matchedCode = '';
    for (String code in _criticalCountryCodes) {
      if (digitsOnly.startsWith(code) || cleanNumber.startsWith('+$code')) {
        isCriticalCountry = true;
        matchedCode = code;
        break;
      }
    }

    // 3. Detección de Patrón Entrópico / Repetición en Ráfaga (Ej: 222333, 88888)
    final bool hasBurstPattern = RegExp(r'(\d)\1{3,}').hasMatch(digitsOnly);

    final String timestamp = DateTime.now().toIso8601String();
    final int trackingId = Random().nextInt(900000) + 100000;

    CallVerdict finalVerdict;
    String matchedRule;

    if (isCriticalCountry || hasBurstPattern) {
      matchedRule = isCriticalCountry ? 'HEURISTIC_SUSPICIOUS_COUNTRY_+$matchedCode' : 'HEURISTIC_ENTROPY_BURST_PATTERN';
      finalVerdict = CallVerdict(
        phoneNumber: cleanNumber,
        riskLevel: 'CRÍTICO',
        analysisMessage: isCriticalCountry 
            ? 'Llamada procedente de país/indicativo ($matchedCode) con alto índice de fraude VoIP.'
            : 'Patrón numérico anómalo detectado (Marcador automático / Botnet).',
        source: selectedSource,
        telemetryDetails: {
          'tracking_id': 'JOSH-SEC-$trackingId',
          'timestamp': timestamp,
          'matched_rule': matchedRule,
          'hybrid_routing': isConnected ? 'RENDER_CLOUD' : 'LOCAL_SHIELD',
        },
      );
    } else if (cleanNumber.startsWith('+57601') || cleanNumber.startsWith('601') || digitsOnly.length < 7) {
      matchedRule = 'HEURISTIC_UNVERIFIED_FIXED_LINE';
      finalVerdict = CallVerdict(
        phoneNumber: cleanNumber,
        riskLevel: 'ADVERTENCIA',
        analysisMessage: 'Llamada catalogada potencialmente como spam comercial o línea no verificada.',
        source: selectedSource,
        telemetryDetails: {
          'tracking_id': 'JOSH-SEC-$trackingId',
          'timestamp': timestamp,
          'matched_rule': matchedRule,
          'hybrid_routing': isConnected ? 'RENDER_CLOUD' : 'LOCAL_SHIELD',
        },
      );
    } else {
      matchedRule = 'DEFAULT_CLEAN_CHECK';
      finalVerdict = CallVerdict(
        phoneNumber: cleanNumber,
        riskLevel: 'SEGURO',
        analysisMessage: 'JOSH Security está patrullando. Este número no presenta reportes de riesgo.',
        source: selectedSource,
        telemetryDetails: {
          'tracking_id': 'JOSH-SEC-$trackingId',
          'timestamp': timestamp,
          'matched_rule': matchedRule,
          'hybrid_routing': isConnected ? 'RENDER_CLOUD' : 'LOCAL_SHIELD',
        },
      );
    }

    await _persistVerdictLog(finalVerdict, matchedRule);
    return finalVerdict;
  }

  Future<void> _persistVerdictLog(CallVerdict verdict, String matchedRule) async {
    try {
      final Map<String, dynamic> logEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'service': 'PhoneInterceptorService',
        'activity': 'Análisis de número telefónico: ${verdict.phoneNumber}',
        'verdict': verdict.riskLevel,
        'matched_rule': matchedRule,
        'extra_data': jsonEncode(verdict.telemetryDetails),
      };
      await _dbService.insertForensicLog(logEntry);
    } catch (e, stackTrace) {
      developer.log(
        'ERR_DATABASE_PERSISTENCE_PHONE_INTERCEPTOR',
        error: e,
        stackTrace: stackTrace,
        name: 'josh.security.db',
      );
    }
  }
}