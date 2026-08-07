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
  // INICIALIZACIÓN Y ESCUCHA DE EVENTOS NATIVOS
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

          final String phone = (args["phoneNumber"] ?? "").toString().trim();

          if (phone.isEmpty) {
            return;
          }

          // Analizar el número real dinámico
          final CallVerdict verdict = await analyzePhoneNumber(phone);

          // Guardar en la base de datos local SQLite
          await _saveCall(verdict);

          // Notificar a la UI / Streams
          _controller.add(verdict);

          // Desplegar la ventana flotante táctica
          await showOverlayIfRequired(verdict);

          break;

        case "onCallEnded":
          try {
            await OverlayService.closeOverlay();
          } catch (e) {
            developer.log(
              "Error al cerrar overlay",
              name: "PhoneInterceptor",
              error: e,
            );
          }
          break;
      }
    });
  }

  void stopListening() {
    _isListening = false;
    _channel.setMethodCallHandler(null);
  }

  // ===========================================================================================
  // DESPLIEGUE DEL OVERLAY CON DIAGNÓSTICO AGÉNTICO
  // ===========================================================================================

  Future<void> showOverlayIfRequired(CallVerdict verdict) async {
    try {
      await OverlayService.showWarningOverlay(
        phoneNumber: verdict.phoneNumber,
        riskLevel: verdict.verdict,
        message: verdict.details,
        agentReasoning: "[DIAGNÓSTICO AGÉNTICO]: ${verdict.category} — ${verdict.details}",
      );
    } catch (e) {
      developer.log(
        "Overlay no disponible o sin permisos",
        name: "PhoneInterceptor",
        error: e,
      );
    }
  }

  // ===========================================================================================
  // PERSISTENCIA LOCAL EN HISTORIAL
  // ===========================================================================================

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
    } catch (e) {
      developer.log(
        "No fue posible guardar el historial telefónico",
        name: "PhoneInterceptor",
        error: e,
      );
    }
  }

  Future<CallVerdict> analyzeIncomingCall(String phoneNumber) async {
    return analyzePhoneNumber(phoneNumber);
  }

  // ===========================================================================================
  // MOTOR HEURÍSTICO DE ANÁLISIS DE NÚMEROS REALES
  // ===========================================================================================

  Future<CallVerdict> analyzePhoneNumber(String phoneNumber) async {
    final clean = phoneNumber.trim();
    final digits = clean.replaceAll(RegExp(r"\D"), "");

    // 1. Manejo de Números Ocultos o Privados
    if (digits.isEmpty || clean.toLowerCase().contains("oculto") || clean.toLowerCase().contains("private")) {
      return CallVerdict(
        phoneNumber: clean.isEmpty ? "Número Oculto" : clean,
        riskScore: 75,
        verdict: "SOSPECHOSO",
        category: "NÚMERO PRIVADO",
        details: "Llamada sin identificador visible o número restringido.",
        source: DiagnosticSource.localHeuristics,
      );
    }

    // 2. Líneas Oficiales y de Emergencia
    if (digits == "123" ||
        digits == "112" ||
        digits == "165" ||
        digits == "116" ||
        digits.startsWith("018000")) {
      return CallVerdict(
        phoneNumber: phoneNumber,
        riskScore: 0,
        verdict: "SEGURO",
        category: "EMERGENCIA",
        details: "Número oficial o línea de asistencia pública/nacional.",
        source: DiagnosticSource.localHeuristics,
      );
    }

    // 3. Verificación de Indicativos Internacionales Sospechosos
    for (final code in _suspiciousCodes) {
      if (digits.startsWith(code) || clean.contains("+$code")) {
        return CallVerdict(
          phoneNumber: phoneNumber,
          riskScore: 92,
          verdict: "CRÍTICO",
          category: "SPAM INTERNACIONAL",
          details: "Indicativo internacional de alto riesgo registrado (+$code).",
          source: DiagnosticSource.phoneInterceptor,
        );
      }
    }

    // 4. Patrones de Spoofing o Repetición
    if (RegExp(r'(\d)\1{4,}').hasMatch(digits)) {
      return CallVerdict(
        phoneNumber: phoneNumber,
        riskScore: 85,
        verdict: "CRÍTICO",
        category: "SPOOFING",
        details: "Patrón numérico repetitivo detectado. Alta probabilidad de falsificación.",
        source: DiagnosticSource.phoneInterceptor,
      );
    }

    // 5. Números Nacionales Estándar
    if (digits.length == 10 && (digits.startsWith("3") || digits.startsWith("60"))) {
      return CallVerdict(
        phoneNumber: phoneNumber,
        riskScore: 5,
        verdict: "SEGURO",
        category: "LÍNEA NACIONAL",
        details: "Número válido compatible con operadores nacionales.",
        source: DiagnosticSource.localHeuristics,
      );
    }

    // 6. Formatos con indicativo internacional +57
    if (digits.length == 12 && digits.startsWith("57")) {
      return CallVerdict(
        phoneNumber: phoneNumber,
        riskScore: 5,
        verdict: "SEGURO",
        category: "LÍNEA NACIONAL",
        details: "Número válido verificado con código de país (+57).",
        source: DiagnosticSource.localHeuristics,
      );
    }

    // 7. Longitudes Anómalas
    if (digits.length < 7 || digits.length > 14) {
      return CallVerdict(
        phoneNumber: phoneNumber,
        riskScore: 65,
        verdict: "SOSPECHOSO",
        category: "FORMATO ANÓMALO",
        details: "La longitud del número no corresponde a la estructura habitual.",
        source: DiagnosticSource.phoneInterceptor,
      );
    }

    // 8. Resultado por defecto para números desconocidos
    return CallVerdict(
      phoneNumber: phoneNumber,
      riskScore: 10,
      verdict: "SEGURO",
      category: "DESCONOCIDO",
      details: "No se detectaron patrones maliciosos en la verificación heurística local.",
      source: DiagnosticSource.localHeuristics,
    );
  }

  // ===========================================================================================
  // CONSULTAS Y MANTENIMIENTO DE BASE DE DATOS
  // ===========================================================================================

  Future<List<Map<String, dynamic>>> getHistory() async {
    return await _database.getCallHistory();
  }

  Future<void> clearHistory() async {
    await _database.clearCallHistory();
  }

  // ===========================================================================================
  // LIBERACIÓN DE RECURSOS
  // ===========================================================================================

  void dispose() {
    stopListening();
    _controller.close();
  }
}