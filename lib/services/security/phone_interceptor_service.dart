// ====================================================================================================
// ARCHIVO: lib/services/security/phone_interceptor_service.dart
// JOSH SECURITY v6.0
// INTERCEPTOR TELEFÓNICO + SECURITY COORDINATOR + AGENTE + PERSISTENCIA + OVERLAY
// ====================================================================================================

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'call_security_engine.dart';
import 'database_service.dart';
import 'overlay_service.dart';
import 'phishing_engine.dart';
import 'security_coordinator.dart';
import 'telemetry_service.dart';

// ====================================================================================================
// FUENTES DE DIAGNÓSTICO
// ====================================================================================================

enum DiagnosticSource {
  local,
  cloud,
  localHeuristics,
  phoneInterceptor,
  cloudDatabase,
  fileSystem,
  agent,
}

// ====================================================================================================
// VEREDICTO DE LLAMADA
// ====================================================================================================

class CallVerdict {
  final String phoneNumber;
  final double riskScore;
  final String verdict;
  final String category;
  final String details;
  final DiagnosticSource source;

  const CallVerdict({
    required this.phoneNumber,
    required this.riskScore,
    required this.verdict,
    required this.category,
    required this.details,
    this.source = DiagnosticSource.phoneInterceptor,
  });

  String get riskLevel => verdict;

  String get analysisMessage => details;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'phoneNumber': phoneNumber,
      'riskScore': riskScore,
      'verdict': verdict,
      'category': category,
      'details': details,
      'source': source.name,
    };
  }
}

// ====================================================================================================
// SERVICIO PRINCIPAL
// ====================================================================================================

class PhoneInterceptorService {
  PhoneInterceptorService()
      : _securityCoordinator = SecurityCoordinator(
          phishingEngine: PhishingEngine(),
          callSecurityEngine: CallSecurityEngine(),
          telemetryService: TelemetryService(),
        );

  static const MethodChannel _channel =
      MethodChannel('josh_security/phone_interceptor');

  final DatabaseService _database = DatabaseService();

  final SecurityCoordinator _securityCoordinator;

  final StreamController<CallVerdict> _controller =
      StreamController<CallVerdict>.broadcast();

  Stream<CallVerdict> get onCallIntercepted => _controller.stream;

  bool _isListening = false;

  bool get isListening => _isListening;

  // ================================================================================================
  // INICIALIZACIÓN
  // ================================================================================================

  Future<void>? _initializationFuture;

  Future<void> _ensureInitialized() {
    return _initializationFuture ??= _securityCoordinator.initialize();
  }

  // ================================================================================================
  // CONTROL DE DUPLICADOS / REBOTES
  // ================================================================================================

  String? _lastProcessedNumber;
  String? _activeCallNumber;

  int _lastProcessTimestamp = 0;

  static const Duration _duplicateWindow = Duration(milliseconds: 2500);

  // ================================================================================================
  // INICIO
  // ================================================================================================

  void startListening() {
    if (_isListening) {
      developer.log(
        'El interceptor ya estaba escuchando.',
        name: 'PhoneInterceptor',
      );
      return;
    }

    if (_controller.isClosed) {
      developer.log(
        'No se puede iniciar: StreamController cerrado.',
        name: 'PhoneInterceptor',
      );
      return;
    }

    _isListening = true;

    _channel.setMethodCallHandler(_handleNativeMethodCall);

    unawaited(
      _ensureInitialized().catchError(
        (Object error, StackTrace stackTrace) {
          developer.log(
            'Error inicializando SecurityCoordinator.',
            name: 'PhoneInterceptor',
            error: error,
            stackTrace: stackTrace,
          );
        },
      ),
    );

    developer.log(
      'Interceptor telefónico iniciado y escuchando josh_security/phone_interceptor.',
      name: 'PhoneInterceptor',
    );
  }

  // ================================================================================================
  // EVENTOS NATIVOS
  // ================================================================================================

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onCallIntercepted':
          await _handleIncomingCall(call.arguments);
          break;

        case 'onCallEnded':
          await _handleCallEnded();
          break;

        default:
          developer.log(
            'Método nativo desconocido: ${call.method}',
            name: 'PhoneInterceptor',
          );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error procesando evento telefónico.',
        name: 'PhoneInterceptor',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ================================================================================================
  // LLAMADA ENTRANTE
  // ================================================================================================

  Future<void> _handleIncomingCall(dynamic rawArguments) async {
    if (rawArguments is! Map) {
      developer.log(
        'Payload telefónico inválido: $rawArguments',
        name: 'PhoneInterceptor',
      );
      return;
    }

    final Map<String, dynamic> args = Map<String, dynamic>.from(rawArguments);

    final String phone = _normalizePhoneNumber(
      _extractPhoneNumber(args),
    );

    if (phone.isEmpty) {
      developer.log(
        'Evento telefónico sin número.',
        name: 'PhoneInterceptor',
      );
      return;
    }

    final int now = DateTime.now().millisecondsSinceEpoch;

    // ----------------------------------------------------------------------------------------------
    // DUPLICADO
    // ----------------------------------------------------------------------------------------------

    if (_lastProcessedNumber == phone &&
        (now - _lastProcessTimestamp) < _duplicateWindow.inMilliseconds) {
      developer.log(
        'Evento duplicado ignorado para $phone.',
        name: 'PhoneInterceptor',
      );
      return;
    }

    // ----------------------------------------------------------------------------------------------
    // MISMA LLAMADA ACTIVA
    // ----------------------------------------------------------------------------------------------

    if (_activeCallNumber == phone) {
      developer.log(
        'Evento repetido de llamada activa ignorado para $phone.',
        name: 'PhoneInterceptor',
      );
      return;
    }

    _lastProcessedNumber = phone;
    _lastProcessTimestamp = now;
    _activeCallNumber = phone;

    developer.log(
      'Número recibido desde Android: $phone',
      name: 'PhoneInterceptor',
    );

    // ----------------------------------------------------------------------------------------------
    // ANÁLISIS MEDIANTE SECURITY COORDINATOR
    // ----------------------------------------------------------------------------------------------

    final CallVerdict verdict = await analyzePhoneNumber(phone);

    // ----------------------------------------------------------------------------------------------
    // PERSISTENCIA
    // ----------------------------------------------------------------------------------------------

    await _saveCall(verdict);

    // ----------------------------------------------------------------------------------------------
    // STREAM EN TIEMPO REAL
    // ----------------------------------------------------------------------------------------------

    if (!_controller.isClosed) {
      _controller.add(verdict);
    }

    // ----------------------------------------------------------------------------------------------
    // DESPLIEGUE DEL OVERLAY
    // ----------------------------------------------------------------------------------------------

    await showOverlayIfRequired(verdict);
  }

  // ================================================================================================
  // EXTRACCIÓN DEL NÚMERO
  // ================================================================================================

  String _extractPhoneNumber(Map<String, dynamic> args) {
    const List<String> possibleKeys = <String>[
      'phoneNumber',
      'phone_number',
      'number',
      'incomingNumber',
      'incoming_number',
      'telephone',
      'tel',
    ];

    for (final String key in possibleKeys) {
      final dynamic value = args[key];

      if (value == null) {
        continue;
      }

      final String text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  // ================================================================================================
  // NORMALIZACIÓN
  // ================================================================================================

  String _normalizePhoneNumber(String value) {
    final String trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final String lower = trimmed.toLowerCase();

    const List<String> hiddenValues = <String>[
      'unknown',
      'unknown number',
      'private',
      'private number',
      'restricted',
      'restricted number',
      'unknown caller',
      'oculto',
      'número oculto',
      'numero oculto',
      'privado',
      'número privado',
      'numero privado',
      'desconocido',
      'número desconocido',
      'numero desconocido',
      'restringido',
    ];

    if (hiddenValues.contains(lower)) {
      return trimmed;
    }

    final String normalized = trimmed.replaceAll(
      RegExp(r'[^\d+]'),
      '',
    );

    return normalized.isNotEmpty ? normalized : trimmed;
  }

  // ================================================================================================
  // FINALIZACIÓN DE LLAMADA
  // ================================================================================================

  Future<void> _handleCallEnded() async {
    try {
      developer.log(
        'Evento de finalización de llamada recibido.',
        name: 'PhoneInterceptor',
      );

      _activeCallNumber = null;

      unawaited(
        Future<void>.delayed(
          _duplicateWindow,
          () {
            _lastProcessedNumber = null;
            _lastProcessTimestamp = 0;
          },
        ),
      );

      await OverlayService.closeOverlay();
    } catch (e, stackTrace) {
      developer.log(
        'Error cerrando overlay al finalizar llamada.',
        name: 'PhoneInterceptor',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ================================================================================================
  // STOP
  // ================================================================================================

  void stopListening() {
    if (!_isListening) {
      return;
    }

    _isListening = false;

    _channel.setMethodCallHandler(null);

    _activeCallNumber = null;
    _lastProcessedNumber = null;
    _lastProcessTimestamp = 0;

    developer.log(
      'Interceptor telefónico detenido.',
      name: 'PhoneInterceptor',
    );
  }

  // ================================================================================================
  // OVERLAY
  // ================================================================================================

  Future<void> showOverlayIfRequired(CallVerdict verdict) async {
    try {
      await OverlayService.showWarningOverlay(
        phoneNumber: verdict.phoneNumber,
        riskLevel: verdict.verdict,
        message: verdict.details,
        agentReasoning: verdict.details,
      );
    } catch (e, stackTrace) {
      developer.log(
        'No fue posible mostrar el overlay.',
        name: 'PhoneInterceptor',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ================================================================================================
  // PERSISTENCIA
  // ================================================================================================

  Future<void> _saveCall(CallVerdict verdict) async {
    try {
      await _database.insertCallHistory(
        phoneNumber: verdict.phoneNumber,
        riskScore: verdict.riskScore,
        verdict: verdict.verdict,
        category: verdict.category,
        details: verdict.details,
        source: verdict.source.name,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e, stackTrace) {
      developer.log(
        'No fue posible guardar historial telefónico.',
        name: 'PhoneInterceptor',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ================================================================================================
  // API PÚBLICA
  // ================================================================================================

  Future<CallVerdict> analyzeIncomingCall(String phoneNumber) async {
    return analyzePhoneNumber(phoneNumber);
  }

  // ================================================================================================
  // MOTOR TELEFÓNICO CENTRAL
  // ================================================================================================

  Future<CallVerdict> analyzePhoneNumber(String phoneNumber) async {
    await _ensureInitialized();

    final String clean = phoneNumber.trim();

    if (clean.isEmpty) {
      return const CallVerdict(
        phoneNumber: 'Número Oculto',
        riskScore: 40.0,
        verdict: 'ADVERTENCIA',
        category: 'IDENTIFICADOR AUSENTE',
        details: 'La llamada no proporcionó un identificador telefónico válido.',
        source: DiagnosticSource.agent,
      );
    }

    try {
      final Map<String, dynamic> result = await _securityCoordinator.scanCall(
        phoneNumber: clean,
      );

      final double riskScore = _readDouble(
        result['score'],
        fallback: _readDouble(
          result['riskScore'],
          fallback: 0.0,
        ),
      );

      final String verdict = _readString(
        result['verdict'],
        fallback: 'UNKNOWN',
      );

      final String category = _resolveCategory(result);

      final String details = _buildAnalysisDetails(result);

      developer.log(
        'Llamada analizada por SecurityCoordinator: '
        '$clean | score=$riskScore | verdict=$verdict',
        name: 'PhoneInterceptor',
      );

      return CallVerdict(
        phoneNumber: clean,
        riskScore: riskScore,
        verdict: verdict,
        category: category,
        details: details,
        source: DiagnosticSource.agent,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error en SecurityCoordinator.scanCall().',
        name: 'PhoneInterceptor',
        error: e,
        stackTrace: stackTrace,
      );

      return CallVerdict(
        phoneNumber: clean,
        riskScore: 0.0,
        verdict: 'ANÁLISIS NO DISPONIBLE',
        category: 'ERROR DEL MOTOR',
        details: 'No fue posible completar el análisis central de seguridad.',
        source: DiagnosticSource.phoneInterceptor,
      );
    }
  }

  // ================================================================================================
  // CONSTRUCCIÓN DEL DIAGNÓSTICO
  // ================================================================================================

  String _buildAnalysisDetails(Map<String, dynamic> result) {
    final List<String> sections = <String>[];

    final dynamic reasons = result['reasons'];

    if (reasons is List) {
      final List<String> validReasons = reasons
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();

      if (validReasons.isNotEmpty) {
        sections.add('EVIDENCIA: ${validReasons.join(' | ')}');
      }
    }

    final String heuristicReason = _readString(
      result['reason'],
      fallback: '',
    );

    if (heuristicReason.isNotEmpty) {
      sections.add('HEURÍSTICA: $heuristicReason');
    }

    final String agentReasoning = _readString(
      result['agentReasoning'],
      fallback: '',
    );

    if (agentReasoning.isNotEmpty) {
      sections.add('AGENTE: $agentReasoning');
    }

    final String action = _readString(
      result['actionRecommendation'],
      fallback: '',
    );

    if (action.isNotEmpty) {
      sections.add('ACCIÓN: $action');
    }

    if (sections.isEmpty) {
      return 'Análisis de seguridad completado.';
    }

    return sections.join('\n');
  }

  // ================================================================================================
  // CATEGORÍA
  // ================================================================================================

  String _resolveCategory(Map<String, dynamic> result) {
    final String validationStatus = _readString(
      result['validation_status'],
      fallback: '',
    );

    if (validationStatus.isNotEmpty) {
      return validationStatus;
    }

    final dynamic reasons = result['reasons'];

    if (reasons is List && reasons.isNotEmpty) {
      return 'ANÁLISIS TELEFÓNICO';
    }

    return 'LLAMADA TELEFÓNICA';
  }

  // ================================================================================================
  // CONVERSIÓN SEGURA
  // ================================================================================================

  double _readDouble(
    dynamic value, {
    required double fallback,
  }) {
    if (value is num) {
      return value.toDouble().clamp(0.0, 100.0);
    }

    if (value is String) {
      final double? parsed = double.tryParse(value);

      if (parsed != null) {
        return parsed.clamp(0.0, 100.0);
      }
    }

    return fallback;
  }

  String _readString(
    dynamic value, {
    required String fallback,
  }) {
    if (value == null) {
      return fallback;
    }

    final String text = value.toString().trim();

    return text.isEmpty ? fallback : text;
  }

  // ================================================================================================
  // HISTORIAL
  // ================================================================================================

  Future<List<Map<String, dynamic>>> getHistory() async {
    return _database.getCallHistory();
  }

  Future<void> clearHistory() async {
    await _database.clearCallHistory();
  }

  // ================================================================================================
  // DISPOSE
  // ================================================================================================

  void dispose() {
    stopListening();

    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
