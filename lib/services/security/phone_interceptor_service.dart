// ====================================================================================================
// ARCHIVO: lib/services/security/phone_interceptor_service.dart
// REEMPLAZO TOTAL — SERVICIO DE INTERCEPTOR Y REPUTACIÓN TELEFÓNICA (CONTRATO UNIFICADO v4.6)
// COMPONENTE: PhoneInterceptorService - JOSH Security
// ====================================================================================================

import 'dart:async';
import 'package:flutter/services.dart';
import 'overlay_service.dart';

/// Enum global para identificar la fuente del diagnóstico en llamadas, archivos y red.
enum DiagnosticSource {
  local,
  cloud,
  localHeuristics,
  phoneInterceptor,
  cloudDatabase,
  fileSystem,
}

/// Estructura de resultado para el dictamen de llamadas interceptadas.
class CallVerdict {
  final String phoneNumber;
  final double riskScore;
  final String verdict;
  final String category;
  final String details;
  final DiagnosticSource source;

  CallVerdict({
    required this.phoneNumber,
    required this.riskScore,
    required this.verdict,
    required this.category,
    required this.details,
    this.source = DiagnosticSource.phoneInterceptor,
  });

  // --- Getters de compatibilidad ---
  String get riskLevel => verdict;
  String get analysisMessage => details;

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'riskScore': riskScore,
      'verdict': verdict,
      'riskLevel': riskLevel,
      'category': category,
      'details': details,
      'analysisMessage': analysisMessage,
      'source': source.toString(),
    };
  }
}

class PhoneInterceptorService {
  static const MethodChannel _channel = MethodChannel('josh_security/phone_interceptor');

  bool _isListening = false;
  bool get isListening => _isListening;

  final StreamController<CallVerdict> _callVerdictController =
      StreamController<CallVerdict>.broadcast();

  Stream<CallVerdict> get onCallIntercepted => _callVerdictController.stream;

  /// Inicializa la escucha de eventos desde la capa nativa Android/Kotlin.
  void startListening() {
    if (_isListening) return;
    _isListening = true;

    _channel.setMethodCallHandler((call) async {
      // 🚨 CORRECCIÓN CLAVE: Emparejado con "onCallIntercepted" enviado desde PhoneCallReceiver.kt
      if (call.method == "onCallIntercepted") {
        final Map<String, dynamic> args = Map<String, dynamic>.from(call.arguments);
        final String number = (args['phoneNumber'] ?? '').toString();

        if (number.isNotEmpty) {
          // 1. Correr la heurística antifraude
          final verdict = await analyzePhoneNumber(number);
          
          // 2. Transmitir el veredicto al Stream interno de la app
          _callVerdictController.add(verdict);

          // 3. 🚀 DESPLEGAR EL POP-UP FLOTANTE (OVERLAY) EN PANTALLA
          await OverlayService.showWarningOverlay(
            phoneNumber: verdict.phoneNumber,
            riskLevel: verdict.verdict,
            message: verdict.details,
          );
        }
      }
    });
  }

  /// Detiene la escucha activa del interceptor.
  void stopListening() {
    _isListening = false;
    _channel.setMethodCallHandler(null);
  }

  /// Método de compatibilidad para llamadas entrantes desde background_shield.
  Future<CallVerdict> analyzeIncomingCall(String phoneNumber) async {
    return await analyzePhoneNumber(phoneNumber);
  }

  /// Evalúa un número telefónico analizando indicativos de alto riesgo y patrones de entropía.
  Future<CallVerdict> analyzePhoneNumber(String phoneNumber) async {
    final String clean = phoneNumber.trim().toLowerCase();
    final String digitsOnly = clean.replaceAll(RegExp(r'\D'), '');

    // 1. Números de emergencia / Líneas directas gubernamentales
    if (digitsOnly == "123" ||
        digitsOnly == "112" ||
        digitsOnly == "165" ||
        digitsOnly.startsWith("018000")) {
      return CallVerdict(
        phoneNumber: phoneNumber,
        riskScore: 0.0,
        verdict: "SEGURO",
        category: "OFICIAL / EMERGENCIA",
        details: "Línea oficial de asistencia o emergencia verificada.",
        source: DiagnosticSource.localHeuristics,
      );
    }

    // 2. Prefijos internacionales de alto riesgo (VoIP masivo, Spam, Tarifa Especial)
    final suspiciousCodes = [
      '234', '254', '381', '216', '225', '233', '92', '880', '371', '370', '881', '882', '883', '870'
    ];

    for (var code in suspiciousCodes) {
      if (digitsOnly.startsWith(code) || clean.contains("+$code")) {
        return CallVerdict(
          phoneNumber: phoneNumber,
          riskScore: 92.0,
          verdict: "CRÍTICO",
          category: "VOIP / SPAM INTERNACIONAL",
          details: "Número proveniente de indicativo internacional de alto riesgo (+$code).",
          source: DiagnosticSource.phoneInterceptor,
        );
      }
    }

    // 3. Patrones repetición / Entropía de dígitos (Ej: 999999, 123456)
    if (RegExp(r'(\d)\1{4,}').hasMatch(digitsOnly)) {
      return CallVerdict(
        phoneNumber: phoneNumber,
        riskScore: 85.0,
        verdict: "CRÍTICO",
        category: "MÁSCARA / SPOOFING",
        details: "Secuencia repetitiva anómala en el número telefónico.",
        source: DiagnosticSource.phoneInterceptor,
      );
    }

    // 4. Formato Estándar Móvil o Fijo Colombia (+57 3xx / 60x)
    if (digitsOnly.length == 10 && (digitsOnly.startsWith("3") || digitsOnly.startsWith("60"))) {
      return CallVerdict(
        phoneNumber: phoneNumber,
        riskScore: 5.0,
        verdict: "SEGURO",
        category: "LÍNEA NACIONAL CONFIABLE",
        details: "Número con estructura válida de operador local.",
        source: DiagnosticSource.localHeuristics,
      );
    }

    // 5. Longitud inusual (Líneas recortadas o sobreextendidas)
    if (digitsOnly.isNotEmpty && (digitsOnly.length < 7 || digitsOnly.length > 14)) {
      return CallVerdict(
        phoneNumber: phoneNumber,
        riskScore: 65.0,
        verdict: "SOSPECHOSO",
        category: "ESTRUCTURA ANÓMALA",
        details: "Longitud no estándar para tráfico telefónico convencional.",
        source: DiagnosticSource.phoneInterceptor,
      );
    }

    return CallVerdict(
      phoneNumber: phoneNumber,
      riskScore: 10.0,
      verdict: "SEGURO",
      category: "DESCONOCIDO ESTÁNDAR",
      details: "Sin patrones maliciosos evidentes.",
      source: DiagnosticSource.localHeuristics,
    );
  }

  void dispose() {
    stopListening();
    _callVerdictController.close();
  }
}