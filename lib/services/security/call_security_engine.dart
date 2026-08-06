// ====================================================================================================
// ARCHIVO: lib/services/security/call_security_engine.dart
// MOTOR DE SEGURIDAD PARA LLAMADAS
// JOSH SECURITY v6.0
// ====================================================================================================

import 'dart:math';

class CallSecurityEngine {
  CallSecurityEngine();

  // ================================================================================================
  // LISTAS DE PATRONES SOSPECHOSOS
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

  static final List<String> emergencyPatterns = [
    "911",
    "112",
    "123",
    "999",
  ];

  // ================================================================================================
  // ANALIZAR LLAMADA
  // ================================================================================================

  Map<String, dynamic> analyze({
    required String phoneNumber,
    String? contactName,
    String? callText,
  }) {
    int score = 0;
    List<String> reasons = [];

    final number = phoneNumber.toLowerCase().trim();
    final text = "${contactName ?? ""} ${callText ?? ""}".toLowerCase();

    // ----------------------------------------------------------------------------------------------
    // NÚMEROS OCULTOS
    // ----------------------------------------------------------------------------------------------
    if (number.isEmpty || number == "unknown" || number == "private") {
      score += 40;
      reasons.add("Número oculto o desconocido");
    }

    // ----------------------------------------------------------------------------------------------
    // LONGITUD EXTRAÑA
    // ----------------------------------------------------------------------------------------------
    if (number.length < 7 || number.length > 15) {
      score += 20;
      reasons.add("Formato de número extraño");
    }

    // ----------------------------------------------------------------------------------------------
    // PREFIJOS SOSPECHOSOS
    // ----------------------------------------------------------------------------------------------
    if (number.startsWith("+999") || number.startsWith("+000") || number.startsWith("000")) {
      score += 50;
      reasons.add("Prefijo telefónico sospechoso");
    }

    // ----------------------------------------------------------------------------------------------
    // INGENIERÍA SOCIAL
    // ----------------------------------------------------------------------------------------------
    for (final pattern in suspiciousPatterns) {
      if (text.contains(pattern)) {
        score += 15;
        reasons.add("Patrón de ingeniería social: $pattern");
      }
    }

    // ----------------------------------------------------------------------------------------------
    // NÚMEROS REPETITIVOS
    // ----------------------------------------------------------------------------------------------
    if (_hasRepeatedNumbers(number)) {
      score += 25;
      reasons.add("Número con patrón repetitivo");
    }

    // ----------------------------------------------------------------------------------------------
    // RESULTADO FINAL
    // ----------------------------------------------------------------------------------------------
    score = min(score, 100);

    String verdict;
    if (score >= 80) {
      verdict = "CRÍTICO";
    } else if (score >= 50) {
      verdict = "SOSPECHOSO";
    } else {
      verdict = "SEGURO";
    }

    return {
      "phone": phoneNumber,
      "score": score,
      "verdict": verdict,
      "reasons": reasons,
      "timestamp": DateTime.now().toIso8601String(),
    };
  }

  // ================================================================================================
  // DETECTAR REPETICIONES
  // ================================================================================================

  bool _hasRepeatedNumbers(String number) {
    if (number.length < 4) {
      return false;
    }

    final first = number.substring(0, 2);
    int count = 0;

    for (int i = 0; i < number.length - 1; i += 2) {
      if (number.substring(i, i + 2) == first) {
        count++;
      }
    }

    return count >= 3;
  }

  // ================================================================================================
  // COMPARAR NÚMEROS
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