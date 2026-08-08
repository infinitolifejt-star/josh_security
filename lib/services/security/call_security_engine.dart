// ====================================================================================================
// ARCHIVO: lib/services/security/call_security_engine.dart
// MOTOR DE SEGURIDAD PARA LLAMADAS Y TELEFONÍA
// JOSH SECURITY v6.0 - ARQUITECTURA DE DECISIÓN UNIFICADA
// ====================================================================================================

import 'dart:math';

/// Estados de Validación Estructural según E.164 / Google libphonenumber
enum PhoneValidationStatus {
  valid,
  invalidFormat,
  shortCode,
  hiddenOrUnknown,
}

class CallSecurityEngine {
  CallSecurityEngine();

  // ================================================================================================
  // PATRONES DE RIESGO E INGENIERÍA SOCIAL
  // ================================================================================================

  static final List<String> suspiciousPatterns = [
    "banco",
    "seguridad",
    "soporte",
    "verificacion",
    "premio",
    "ganaste",
    "urgente",
    "bloqueo",
    "cuenta",
    "clave",
    "codigo",
    "token",
    "confirmar",
    "actualizar",
    "credito",
    "inversion",
    "oferta",
    "wallet",
    "crypto",
    "cripto",
  ];

  // ================================================================================================
  // MÉTODOS DE EVALUACIÓN ESTRUCTURAL
  // ================================================================================================

  /// Determina el estado de validación según longitud y tipo de marcado
  PhoneValidationStatus _evaluateValidationStatus(String cleanNumber) {
    if (cleanNumber.isEmpty || cleanNumber == "unknown" || cleanNumber == "private") {
      return PhoneValidationStatus.hiddenOrUnknown;
    }

    // Estándar ITU-T E.164: Un número telefónico internacional válido tiene entre 7 y 15 dígitos.
    if (cleanNumber.length > 15) {
      return PhoneValidationStatus.invalidFormat;
    }

    // Estructuras de 3 a 6 dígitos corresponden a Códigos Cortos (Shortcodes / Servicios)
    if (cleanNumber.length >= 3 && cleanNumber.length <= 6) {
      return PhoneValidationStatus.shortCode;
    }

    if (cleanNumber.length < 7) {
      return PhoneValidationStatus.invalidFormat;
    }

    return PhoneValidationStatus.valid;
  }

  /// Evalúa repeticiones anómalas en la cadena numérica (ej. 9999999999 o 88888888)
  bool _hasAnomalousRepetition(String number) {
    if (number.length < 4) return false;

    // Detectar si todos los dígitos son idénticos
    final firstChar = number[0];
    if (number.runes.every((r) => String.fromCharCode(r) == firstChar)) {
      return true;
    }

    // Detectar patrones repetitivos en pares (ej. 88889999)
    final firstTwo = number.substring(0, 2);
    int count = 0;
    for (int i = 0; i < number.length - 1; i += 2) {
      if (number.substring(i, min(i + 2, number.length)) == firstTwo) {
        count++;
      }
    }
    return count >= 4;
  }

  // ================================================================================================
  // ANÁLISIS PRINCIPAL
  // ================================================================================================

  Map<String, dynamic> analyze({
    required String phoneNumber,
    String? contactName,
    String? callText,
  }) {
    final rawNumber = phoneNumber.toLowerCase().trim();
    final cleanDigits = rawNumber.replaceAll(RegExp(r'\D'), '');
    final combinedContext = "${contactName ?? ""} ${callText ?? ""}".toLowerCase();

    final validationStatus = _evaluateValidationStatus(rawNumber.isEmpty ? rawNumber : cleanDigits);

    int riskScore = 0;
    List<String> evidence = [];

    // 1. Evaluación Estructural
    switch (validationStatus) {
      case PhoneValidationStatus.hiddenOrUnknown:
        riskScore += 40;
        evidence.add("Número oculto, privado o no identificado.");
        break;

      case PhoneValidationStatus.invalidFormat:
        riskScore += 35;
        evidence.add("Anomalía de formato: Longitud incompatible con el estándar internacional ITU-T E.164.");
        break;

      case PhoneValidationStatus.shortCode:
        riskScore += 25;
        evidence.add("Estructura correspondiente a código corto no verificado.");
        break;

      case PhoneValidationStatus.valid:
        // Formato numérico estándar
        break;
    }

    // 2. Prefijos Anómalos
    if (rawNumber.startsWith("+999") || rawNumber.startsWith("+000") || rawNumber.startsWith("000")) {
      riskScore += 45;
      evidence.add("Prefijo de red no asignado o altamente sospechoso.");
    }

    // 3. Patrones de Repetición Extrema
    if (_hasAnomalousRepetition(cleanDigits)) {
      riskScore += 50;
      evidence.add("Patrón numérico altamente repetitivo detectado.");
    }

    // 4. Análisis de Ingeniería Social en Contexto de Texto/Contacto
    int socialEngineeringMatches = 0;
    for (final pattern in suspiciousPatterns) {
      if (combinedContext.contains(pattern)) {
        socialEngineeringMatches++;
        if (socialEngineeringMatches <= 3) {
          riskScore += 15;
          evidence.add("Indicador de ingeniería social detectado: '$pattern'");
        }
      }
    }

    // Normalizar score al rango 0 - 100
    riskScore = min(riskScore, 100);

    // 5. Mapeo Semántico del Veredicto
    String verdict;
    String statusLabel;

    if (riskScore >= 80) {
      verdict = "AMENAZA_CONFIRMADA";
      statusLabel = "🔴 ALTO RIESGO / AMENAZA";
    } else if (riskScore >= 60) {
      verdict = "ALTO_RIESGO";
      statusLabel = "🟠 ALTO RIESGO";
    } else if (riskScore >= 40) {
      verdict = "ADVERTENCIA";
      statusLabel = "🟡 ADVERTENCIA PREVENTIVA";
    } else if (validationStatus == PhoneValidationStatus.invalidFormat) {
      verdict = "ANOMALIA_FORMATO";
      statusLabel = "🔵 ANOMALÍA DE FORMATO";
    } else if (validationStatus == PhoneValidationStatus.shortCode) {
      verdict = "SHORTCODE_NO_VERIFICADO";
      statusLabel = "🟡 CÓDIGO CORTO NO VERIFICADO";
    } else {
      verdict = "SIN_AMENAZAS";
      statusLabel = "🟢 SIN AMENAZAS DETECTADAS";
    }

    return {
      "phone": phoneNumber,
      "risk_score": riskScore,
      "validation_status": validationStatus.toString().split('.').last,
      "verdict": verdict,
      "status_label": statusLabel,
      "reasons": evidence,
      "timestamp": DateTime.now().toIso8601String(),
    };
  }

  // ================================================================================================
  // COMPARACIÓN DE NÚMEROS (Distancia de Levenshtein simplificada)
  // ================================================================================================

  int similarity(String a, String b) {
    int distance = 0;
    final length = min(a.length, b.length);

    for (int i = 0; i < length; i++) {
      if (a[i] != b[i]) {
        distance++;
      }
    }

    distance += (a.length - b.length).abs();
    return distance;
  }
}