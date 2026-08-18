// ====================================================================================================
// ARCHIVO: lib/services/security/phone_interceptor_service.dart
// JOSH SECURITY - INTERCEPTOR TELEFÓNICO
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

enum DiagnosticSource {
  local,
  cloud,
  localHeuristics,
  phoneInterceptor,
  cloudDatabase,
  fileSystem,
  agent,
}

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

class PhoneInterceptorService {
  PhoneInterceptorService()
      : _securityCoordinator = SecurityCoordinator(
          phishingEngine: PhishingEngine(),
          callSecurityEngine: const CallSecurityEngine(),
          telemetryService: TelemetryService(),
        );

  static const MethodChannel _channel = MethodChannel(
    'josh_security/phone_interceptor',
  );

  final DatabaseService _database = DatabaseService.instance;
  final SecurityCoordinator _securityCoordinator;
  final StreamController<CallVerdict> _controller =
      StreamController<CallVerdict>.broadcast();

  Stream<CallVerdict> get onCallIntercepted => _controller.stream;

  Future<void>? _initializationFuture;
  bool _initialized = false;
  bool _isListening = false;
  bool _callBeingProcessed = false;

  String? _lastProcessedNumber;
  int _lastProcessTimestamp = 0;

  static const Duration _duplicateWindow = Duration(seconds: 3);

  bool get isListening => _isListening;

  void startListening() {
    if (_isListening || _controller.isClosed) {
      return;
    }
    _isListening = true;
    _channel.setMethodCallHandler(_handleNativeMethodCall);

    unawaited(
      initialize().catchError(
        (Object error, StackTrace stackTrace) {
          developer.log(
            'Error inicializando PhoneInterceptorService.',
            name: 'PhoneInterceptor',
            error: error,
            stackTrace: stackTrace,
          );
        },
      ),
    );
  }

  void stopListening() {
    if (!_isListening) {
      return;
    }
    _isListening = false;
    _channel.setMethodCallHandler(null);
    _callBeingProcessed = false;
    _lastProcessedNumber = null;
    _lastProcessTimestamp = 0;
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onCallIntercepted':
          await _handleNativeIncomingCall(call.arguments);
          break;
        case 'onCallEnded':
          await handleCallEnded();
          break;
        default:
          developer.log(
            'Método nativo desconocido: ${call.method}',
            name: 'PhoneInterceptor',
          );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error procesando evento nativo telefónico.',
        name: 'PhoneInterceptor',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _handleNativeIncomingCall(dynamic rawArguments) async {
    if (rawArguments is! Map) {
      return;
    }
    final Map<String, dynamic> arguments =
        Map<String, dynamic>.from(rawArguments);
    final String phoneNumber = _extractPhoneNumber(arguments);

    if (phoneNumber.isEmpty) {
      developer.log(
        'Evento telefónico sin número válido.',
        name: 'PhoneInterceptor',
      );
      return;
    }
    await handleIncomingCall(phoneNumber);
  }

  String _extractPhoneNumber(Map<String, dynamic> arguments) {
    const List<String> keys = <String>[
      'phoneNumber',
      'phone_number',
      'number',
      'incomingNumber',
      'incoming_number',
      'telephone',
      'tel',
    ];

    for (final String key in keys) {
      final dynamic value = arguments[key];
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

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    if (_initializationFuture != null) {
      return _initializationFuture!;
    }
    _initializationFuture = _performInitialization();
    try {
      await _initializationFuture!;
      _initialized = true;
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
  }

  Future<void> _performInitialization() async {
    await Future.wait(<Future<dynamic>>[
      _securityCoordinator.initialize(),
      _database.database,
    ]);
  }

  Future<CallVerdict> handleIncomingCall(String phoneNumber) async {
    await initialize();
    final String phone = _normalizePhoneNumber(phoneNumber);

    if (phone.isEmpty) {
      return const CallVerdict(
        phoneNumber: 'Número Oculto',
        riskScore: 40,
        verdict: 'ADVERTENCIA',
        category: 'IDENTIFICADOR AUSENTE',
        details:
            'La llamada no proporcionó un identificador telefónico válido.',
        source: DiagnosticSource.agent,
      );
    }

    final int now = DateTime.now().millisecondsSinceEpoch;

    if (_callBeingProcessed) {
      return _duplicateVerdict(phone);
    }

    if (_lastProcessedNumber == phone &&
        now - _lastProcessTimestamp < _duplicateWindow.inMilliseconds) {
      return _duplicateVerdict(phone);
    }

    _lastProcessedNumber = phone;
    _lastProcessTimestamp = now;
    _callBeingProcessed = true;

    try {
      final CallVerdict verdict = await analyzePhoneNumber(phone);
      await _saveCall(verdict);
      if (!_controller.isClosed) {
        _controller.add(verdict);
      }
      await showOverlayIfRequired(verdict);
      return verdict;
    } finally {
      _callBeingProcessed = false;
    }
  }

  CallVerdict _duplicateVerdict(String phone) {
    return CallVerdict(
      phoneNumber: phone,
      riskScore: 0,
      verdict: 'EVENTO DUPLICADO',
      category: 'CONTROL DE EVENTOS',
      details: 'Evento telefónico duplicado ignorado.',
      source: DiagnosticSource.phoneInterceptor,
    );
  }

  Future<void> handleCallEnded() async {
    _callBeingProcessed = false;
    try {
      await OverlayService.closeOverlay();
    } catch (e, stackTrace) {
      developer.log(
        'Error cerrando overlay.',
        name: 'PhoneInterceptor',
        error: e,
        stackTrace: stackTrace,
      );
    }

    final String? last = _lastProcessedNumber;
    if (last == null) {
      return;
    }

    unawaited(
      Future<void>.delayed(
        _duplicateWindow,
        () {
          if (_lastProcessedNumber == last) {
            _lastProcessedNumber = null;
            _lastProcessTimestamp = 0;
          }
        },
      ),
    );
  }

  Future<CallVerdict> analyzeIncomingCall(String phoneNumber) {
    return handleIncomingCall(phoneNumber);
  }

  Future<CallVerdict> analyzePhoneNumber(String phoneNumber) async {
    await initialize();
    final String clean = phoneNumber.trim();

    if (clean.isEmpty) {
      return const CallVerdict(
        phoneNumber: 'Número Oculto',
        riskScore: 40,
        verdict: 'ADVERTENCIA',
        category: 'IDENTIFICADOR AUSENTE',
        details:
            'La llamada no proporcionó un identificador telefónico válido.',
        source: DiagnosticSource.agent,
      );
    }

    try {
      final Map<String, dynamic> result =
          await _securityCoordinator.scanCall(phoneNumber: clean);

      final double riskScore = _readDouble(
        result['score'],
        fallback: _readDouble(result['riskScore'], fallback: 0),
      );

      final String verdict = _readString(
        result['verdict'],
        fallback: 'UNKNOWN',
      );

      final String category = _resolveCategory(result);
      final String details = _buildAnalysisDetails(result);

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
        riskScore: 0,
        verdict: 'ANÁLISIS NO DISPONIBLE',
        category: 'ERROR DEL MOTOR',
        details: 'No fue posible completar el análisis central de seguridad.',
        source: DiagnosticSource.phoneInterceptor,
      );
    }
  }

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
        'No fue posible mostrar overlay.',
        name: 'PhoneInterceptor',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

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
        'Error guardando historial telefónico.',
        name: 'PhoneInterceptor',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    await initialize();
    return _database.getCallHistory();
  }

  Future<void> clearHistory() async {
    await initialize();
    await _database.clearCallHistory();
  }

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

    final String heuristicReason = _readString(result['reason'], fallback: '');
    if (heuristicReason.isNotEmpty) {
      sections.add('HEURÍSTICA: $heuristicReason');
    }

    final String agentReasoning =
        _readString(result['agentReasoning'], fallback: '');
    if (agentReasoning.isNotEmpty) {
      sections.add('AGENTE: $agentReasoning');
    }

    final String action =
        _readString(result['actionRecommendation'], fallback: '');
    if (action.isNotEmpty) {
      sections.add('ACCIÓN: $action');
    }

    return sections.isEmpty
        ? 'Análisis de seguridad completado.'
        : sections.join('\n');
  }

  String _resolveCategory(Map<String, dynamic> result) {
    final String validationStatus =
        _readString(result['validation_status'], fallback: '');
    if (validationStatus.isNotEmpty) {
      return validationStatus;
    }

    final dynamic reasons = result['reasons'];
    if (reasons is List && reasons.isNotEmpty) {
      return 'ANÁLISIS TELEFÓNICO';
    }

    return 'LLAMADA TELEFÓNICA';
  }

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

    final String normalized = trimmed.replaceAll(RegExp(r'[^\d+]'), '');
    return normalized.isNotEmpty ? normalized : trimmed;
  }

  double _readDouble(dynamic value, {required double fallback}) {
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

  String _readString(dynamic value, {required String fallback}) {
    if (value == null) {
      return fallback;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  void dispose() {
    stopListening();
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
