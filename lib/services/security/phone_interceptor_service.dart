// ====================================================================================================
// ARCHIVO: lib/services/security/phone_interceptor_service.dart
// JOSH SECURITY v5.0
// MOTOR DE INTERCEPTOR TELEFÓNICO + REPUTACIÓN + PERSISTENCIA LOCAL
// PARTE 1/2
// ====================================================================================================

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'database_service.dart';
import 'overlay_service.dart';

enum DiagnosticSource {
  local,
  cloud,
  localHeuristics,
  phoneInterceptor,
  cloudDatabase,
  fileSystem,
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
    return {
      "phoneNumber": phoneNumber,
      "riskScore": riskScore,
      "verdict": verdict,
      "category": category,
      "details": details,
      "source": source.name,
    };
  }
}

class PhoneInterceptorService {

  PhoneInterceptorService();

  static const MethodChannel _channel =
      MethodChannel("josh_security/phone_interceptor");

  final DatabaseService _database = DatabaseService();

  final StreamController<CallVerdict> _controller =
      StreamController<CallVerdict>.broadcast();

  Stream<CallVerdict> get onCallIntercepted => _controller.stream;

  bool _isListening = false;

  bool get isListening => _isListening;

  static const List<String> _suspiciousCodes = [

    "234",
    "254",
    "381",
    "216",
    "225",
    "233",
    "92",
    "880",
    "371",
    "370",
    "881",
    "882",
    "883",
    "870",

  ];

  // ===========================================================================================
  // INICIALIZACIÓN
  // ===========================================================================================

  void startListening() {

    if (_isListening) {
      return;
    }

    _isListening = true;

    _channel.setMethodCallHandler((call) async {

      switch (call.method) {

        case "onCallIntercepted":

          final Map<String, dynamic> args =
              Map<String, dynamic>.from(call.arguments);

          final String phone =
              (args["phoneNumber"] ?? "").toString();

          if (phone.isEmpty) {
            return;
          }

          final CallVerdict verdict =
              await analyzePhoneNumber(phone);

          await _saveCall(verdict);

          _controller.add(verdict);

          await showOverlayIfRequired(verdict);

          break;

        case "onCallEnded":

          try {

            await OverlayService.closeOverlay();

          } catch (_) {}

          break;

      }

    });

  }

  void stopListening() {

    _isListening = false;

    _channel.setMethodCallHandler(null);

  }

  // ===========================================================================================
  // OVERLAY
  // ===========================================================================================

  Future<void> showOverlayIfRequired(
      CallVerdict verdict,
      ) async {

    try {

      await OverlayService.showWarningOverlay(

        phoneNumber: verdict.phoneNumber,
        riskLevel: verdict.verdict,
        message: verdict.details,

      );

    } catch (e) {

      developer.log(

        "Overlay no disponible",
        name: "PhoneInterceptor",
        error: e,

      );

    }

  }

  // ===========================================================================================
  // PERSISTENCIA
  // ===========================================================================================

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

    } catch (e) {

      developer.log(

        "No fue posible guardar historial telefónico",
        name: "PhoneInterceptor",
        error: e,

      );

    }

  }

  Future<CallVerdict> analyzeIncomingCall(
      String phoneNumber,
      ) async {

    return analyzePhoneNumber(phoneNumber);

  }

  // ===========================================================================================
  // MOTOR HEURÍSTICO
  // ===========================================================================================

  Future<CallVerdict> analyzePhoneNumber(
      String phoneNumber,
      ) async {

    final clean =
        phoneNumber.trim().toLowerCase();

    final digits =
        clean.replaceAll(RegExp(r"\D"), "");

    if (digits.isEmpty) {

      return const CallVerdict(

        phoneNumber: "",
        riskScore: 50,
        verdict: "SOSPECHOSO",
        category: "NÚMERO INVÁLIDO",
        details: "No fue posible obtener el número.",

      );

    }

    if (digits == "123" ||
        digits == "112" ||
        digits == "165" ||
        digits.startsWith("018000")) {

      return CallVerdict(

        phoneNumber: phoneNumber,
        riskScore: 0,
        verdict: "SEGURO",
        category: "EMERGENCIA",
        details:
            "Número oficial o línea de asistencia.",

        source: DiagnosticSource.localHeuristics,

      );

    }

    for (final code in _suspiciousCodes) {

      if (digits.startsWith(code) ||
          clean.contains("+$code")) {

        return CallVerdict(

          phoneNumber: phoneNumber,
          riskScore: 92,
          verdict: "CRÍTICO",
          category: "SPAM INTERNACIONAL",
          details:
              "Indicativo internacional considerado de alto riesgo (+$code).",

          source: DiagnosticSource.phoneInterceptor,

        );

      }

    }
    if (RegExp(r'(\d)\1{4,}').hasMatch(digits)) {

      return CallVerdict(

        phoneNumber: phoneNumber,
        riskScore: 85,
        verdict: "CRÍTICO",
        category: "SPOOFING",

        details:
            "Patrón repetitivo detectado. Posible falsificación del identificador.",

        source: DiagnosticSource.phoneInterceptor,

      );

    }

    if (digits.length == 10 &&
        (digits.startsWith("3") ||
            digits.startsWith("60"))) {

      return CallVerdict(

        phoneNumber: phoneNumber,
        riskScore: 5,

        verdict: "SEGURO",

        category: "LÍNEA NACIONAL",

        details:
            "Número compatible con operadores nacionales.",

        source: DiagnosticSource.localHeuristics,

      );

    }

    if (digits.length < 7 ||
        digits.length > 14) {

      return CallVerdict(

        phoneNumber: phoneNumber,

        riskScore: 65,

        verdict: "SOSPECHOSO",

        category: "FORMATO ANÓMALO",

        details:
            "La longitud del número no corresponde a un formato telefónico habitual.",

        source: DiagnosticSource.phoneInterceptor,

      );

    }

    return CallVerdict(

      phoneNumber: phoneNumber,

      riskScore: 10,

      verdict: "SEGURO",

      category: "DESCONOCIDO",

      details:
          "No se detectaron patrones maliciosos mediante heurísticas locales.",

      source: DiagnosticSource.localHeuristics,

    );

  }

  // ===========================================================================================
  // CONSULTAS
  // ===========================================================================================

  Future<List<Map<String, dynamic>>> getHistory() async {

    return await _database.getCallHistory();

  }

  Future<void> clearHistory() async {

    await _database.clearCallHistory();

  }

  // ===========================================================================================
  // LIBERACIÓN
  // ===========================================================================================

  void dispose() {

    stopListening();

    _controller.close();

  }

}
