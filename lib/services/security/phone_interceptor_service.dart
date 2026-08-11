// ====================================================================================================
// ARCHIVO: lib/services/security/phone_interceptor_service.dart
// JOSH SECURITY v6.0
// MOTOR DE INTERCEPTOR TELEFÓNICO + REPUTACIÓN + PERSISTENCIA LOCAL
// ====================================================================================================

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'database_service.dart';
import 'overlay_service.dart';

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
  PhoneInterceptorService();

  static const MethodChannel _channel =
      MethodChannel('josh_security/phone_interceptor');

  final DatabaseService _database = DatabaseService();

  final StreamController<CallVerdict> _controller =
      StreamController<CallVerdict>.broadcast();

  Stream<CallVerdict> get onCallIntercepted =>
      _controller.stream;

  bool _isListening = false;

  bool get isListening => _isListening;

  // ==================================================================================================
  // INDICATIVOS INTERNACIONALES DE RIESGO
  // ==================================================================================================

  static const List<String> _suspiciousCodes = <String>[
    '234',
    '254',
    '381',
    '216',
    '225',
    '233',
    '92',
    '880',
    '371',
    '370',
    '881',
    '882',
    '883',
    '870',
  ];

  // ==================================================================================================
  // INICIO
  // ==================================================================================================

  void startListening() {
    if (_isListening) {
      developer.log(
        'El interceptor ya estaba escuchando.',
        name: 'PhoneInterceptor',
      );

      return;
    }

    _isListening = true;

    _channel.setMethodCallHandler(
      _handleNativeMethodCall,
    );

    developer.log(
      'Interceptor telefónico iniciado.',
      name: 'PhoneInterceptor',
    );
  }

  // ==================================================================================================
  // EVENTOS NATIVOS
  // ==================================================================================================

  Future<dynamic> _handleNativeMethodCall(
    MethodCall call,
  ) async {
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

  // ==================================================================================================
  // LLAMADA ENTRANTE
  // ==================================================================================================

  Future<void> _handleIncomingCall(
    dynamic rawArguments,
  ) async {
    if (rawArguments is! Map) {
      developer.log(
        'Payload telefónico inválido: $rawArguments',
        name: 'PhoneInterceptor',
      );

      return;
    }

    final Map<String, dynamic> args =
        Map<String, dynamic>.from(rawArguments);

    final String phone = _extractPhoneNumber(args);

    if (phone.isEmpty) {
      developer.log(
        'Evento telefónico recibido sin número.',
        name: 'PhoneInterceptor',
      );

      return;
    }

    developer.log(
      'Número recibido desde Android: $phone',
      name: 'PhoneInterceptor',
    );

    final CallVerdict verdict =
        await analyzePhoneNumber(phone);

    await _saveCall(verdict);

    if (!_controller.isClosed) {
      _controller.add(verdict);
    }

    await showOverlayIfRequired(verdict);
  }

  // ==================================================================================================
  // EXTRACCIÓN FLEXIBLE DEL NÚMERO
  // ==================================================================================================

  String _extractPhoneNumber(
    Map<String, dynamic> args,
  ) {
    const List<String> possibleKeys = <String>[
      'phoneNumber',
      'phone_number',
      'number',
      'incomingNumber',
      'incoming_number',
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

  // ==================================================================================================
  // FINALIZACIÓN
  // ==================================================================================================

  Future<void> _handleCallEnded() async {
    try {
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

  // ==================================================================================================
  // STOP
  // ==================================================================================================

  void stopListening() {
    if (!_isListening) {
      return;
    }

    _isListening = false;

    _channel.setMethodCallHandler(null);

    developer.log(
      'Interceptor telefónico detenido.',
      name: 'PhoneInterceptor',
    );
  }

  // ==================================================================================================
  // OVERLAY
  // ==================================================================================================

  Future<void> showOverlayIfRequired(
    CallVerdict verdict,
  ) async {
    try {
      await OverlayService.showWarningOverlay(
        phoneNumber: verdict.phoneNumber,
        riskLevel: verdict.verdict,
        message: verdict.details,
        agentReasoning:
            '[DIAGNÓSTICO LOCAL]: '
            '${verdict.category} — ${verdict.details}',
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

  // ==================================================================================================
  // PERSISTENCIA
  // ==================================================================================================

  Future<void> _saveCall(
    CallVerdict verdict,
  ) async {
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
        'No fue posible guardar el historial telefónico.',
        name: 'PhoneInterceptor',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ==================================================================================================
  // API PÚBLICA
  // ==================================================================================================

  Future<CallVerdict> analyzeIncomingCall(
    String phoneNumber,
  ) async {
    return analyzePhoneNumber(phoneNumber);
  }

  // ==================================================================================================
  // MOTOR HEURÍSTICO
  // ==================================================================================================

  Future<CallVerdict> analyzePhoneNumber(
    String phoneNumber,
  ) async {
    final String clean = phoneNumber.trim();

    final String lower = clean.toLowerCase();

    final String digits =
        clean.replaceAll(RegExp(r'\D'), '');

    // -----------------------------------------------------------------------------------------------
    // 1. NÚMERO OCULTO / PRIVADO
    // -----------------------------------------------------------------------------------------------

    final bool isPrivateNumber =
        digits.isEmpty ||
        lower.contains('oculto') ||
        lower.contains('privado') ||
        lower.contains('private') ||
        lower.contains('unknown') ||
        lower.contains('desconocido') ||
        lower.contains('restricted') ||
        lower.contains('restringido');

    if (isPrivateNumber) {
      return CallVerdict(
        phoneNumber:
            clean.isEmpty ? 'Número Oculto' : clean,
        riskScore: 75,
        verdict: 'SOSPECHOSO',
        category: 'NÚMERO PRIVADO',
        details:
            'Llamada sin identificador visible o número restringido.',
        source: DiagnosticSource.localHeuristics,
      );
    }

    // -----------------------------------------------------------------------------------------------
    // 2. LÍNEAS OFICIALES / EMERGENCIA
    // -----------------------------------------------------------------------------------------------

    if (digits == '123' ||
        digits == '112' ||
        digits == '165' ||
        digits == '116' ||
        digits.startsWith('018000')) {
      return CallVerdict(
        phoneNumber: clean,
        riskScore: 0,
        verdict: 'SEGURO',
        category: 'LÍNEA OFICIAL',
        details:
            'Número oficial o línea de asistencia pública/nacional.',
        source: DiagnosticSource.localHeuristics,
      );
    }

    // -----------------------------------------------------------------------------------------------
    // 3. INDICATIVOS INTERNACIONALES SOSPECHOSOS
    // -----------------------------------------------------------------------------------------------

    for (final String code in _suspiciousCodes) {
      final bool startsWithInternationalCode =
          clean.startsWith('+$code');

      final bool startsWithDigitsCode =
          digits.startsWith(code) &&
          digits.length >= code.length + 7;

      if (startsWithInternationalCode ||
          startsWithDigitsCode) {
        return CallVerdict(
          phoneNumber: clean,
          riskScore: 92,
          verdict: 'CRÍTICO',
          category: 'SPAM INTERNACIONAL',
          details:
              'Indicativo internacional de alto riesgo detectado (+$code).',
          source: DiagnosticSource.phoneInterceptor,
        );
      }
    }

    // -----------------------------------------------------------------------------------------------
    // 4. PATRONES NUMÉRICOS REPETITIVOS
    // -----------------------------------------------------------------------------------------------

    if (RegExp(r'(\d)\1{4,}').hasMatch(digits)) {
      return CallVerdict(
        phoneNumber: clean,
        riskScore: 85,
        verdict: 'CRÍTICO',
        category: 'SPOOFING',
        details:
            'Patrón numérico repetitivo detectado. '
            'El formato presenta características anómalas.',
        source: DiagnosticSource.phoneInterceptor,
      );
    }

    // -----------------------------------------------------------------------------------------------
    // 5. COLOMBIA - MÓVIL / FIJO
    // -----------------------------------------------------------------------------------------------

    if (digits.length == 10 &&
        digits.startsWith('3')) {
      return CallVerdict(
        phoneNumber: clean,
        riskScore: 5,
        verdict: 'SEGURO',
        category: 'LÍNEA NACIONAL',
        details:
            'Número móvil colombiano con formato nacional válido.',
        source: DiagnosticSource.localHeuristics,
      );
    }

    if (digits.length == 10 &&
        digits.startsWith('60')) {
      return CallVerdict(
        phoneNumber: clean,
        riskScore: 5,
        verdict: 'SEGURO',
        category: 'LÍNEA NACIONAL',
        details:
            'Número fijo colombiano con formato nacional válido.',
        source: DiagnosticSource.localHeuristics,
      );
    }

    // -----------------------------------------------------------------------------------------------
    // 6. COLOMBIA +57
    // -----------------------------------------------------------------------------------------------

    if (digits.length == 12 &&
        digits.startsWith('57')) {
      return CallVerdict(
        phoneNumber: clean,
        riskScore: 5,
        verdict: 'SEGURO',
        category: 'LÍNEA NACIONAL',
        details:
            'Número colombiano detectado mediante código de país +57.',
        source: DiagnosticSource.localHeuristics,
      );
    }

    // -----------------------------------------------------------------------------------------------
    // 7. LONGITUD ANÓMALA
    // -----------------------------------------------------------------------------------------------

    if (digits.length < 7 ||
        digits.length > 15) {
      return CallVerdict(
        phoneNumber: clean,
        riskScore: 65,
        verdict: 'SOSPECHOSO',
        category: 'FORMATO ANÓMALO',
        details:
            'La longitud del número no corresponde a una estructura telefónica habitual.',
        source: DiagnosticSource.phoneInterceptor,
      );
    }

    // -----------------------------------------------------------------------------------------------
    // 8. DESCONOCIDO
    // -----------------------------------------------------------------------------------------------

    return CallVerdict(
      phoneNumber: clean,
      riskScore: 10,
      verdict: 'SEGURO',
      category: 'DESCONOCIDO',
      details:
          'No se detectaron patrones maliciosos en la verificación heurística local.',
      source: DiagnosticSource.localHeuristics,
    );
  }

  // ==================================================================================================
  // HISTORIAL
  // ==================================================================================================

  Future<List<Map<String, dynamic>>> getHistory() async {
    return _database.getCallHistory();
  }

  Future<void> clearHistory() async {
    await _database.clearCallHistory();
  }

  // ==================================================================================================
  // DISPOSE
  // ==================================================================================================

  void dispose() {
    stopListening();

    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
