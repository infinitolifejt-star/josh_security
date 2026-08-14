// ====================================================================================================
// ARCHIVO: lib/services/security/call_security_engine.dart
// MOTOR HEURÍSTICO DE SEGURIDAD PARA LLAMADAS
// JOSH SECURITY v6.0
//
// RESPONSABILIDAD:
// - Análisis estructural.
// - Patrones numéricos.
// - Indicadores de ingeniería social.
// - Generación de puntuación heurística.
// - NO toma la decisión agéntica final.
//
// La decisión final corresponde a SecurityCoordinator + AgentEngine.
// ====================================================================================================

import 'dart:math';

/// Estados de validación estructural del número.
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

  static const List<String> suspiciousPatterns = <String>[
    'banco',
    'seguridad',
    'soporte',
    'verificacion',
    'premio',
    'ganaste',
    'urgente',
    'bloqueo',
    'cuenta',
    'clave',
    'codigo',
    'token',
    'confirmar',
    'actualizar',
    'credito',
    'inversion',
    'oferta',
    'wallet',
    'crypto',
    'cripto',
  ];

  // ================================================================================================
  // VALIDACIÓN ESTRUCTURAL
  // ================================================================================================

  PhoneValidationStatus _evaluateValidationStatus(
    String rawNumber,
    String cleanDigits,
  ) {
    final String lowerRaw =
        rawNumber.toLowerCase().trim();

    if (
      lowerRaw.isEmpty ||
      cleanDigits.isEmpty ||
      lowerRaw.contains('unknown') ||
      lowerRaw.contains('private') ||
      lowerRaw.contains('desconocido') ||
      lowerRaw.contains('privado') ||
      lowerRaw.contains('restricted') ||
      lowerRaw.contains('restringido') ||
      lowerRaw.contains('oculto')
    ) {
      return PhoneValidationStatus.hiddenOrUnknown;
    }

    // 3 a 6 dígitos: posible código corto.
    if (
      cleanDigits.length >= 3 &&
      cleanDigits.length <= 6
    ) {
      return PhoneValidationStatus.shortCode;
    }

    // Rango estructural E.164.
    if (
      cleanDigits.length < 7 ||
      cleanDigits.length > 15
    ) {
      return PhoneValidationStatus.invalidFormat;
    }

    return PhoneValidationStatus.valid;
  }

  // ================================================================================================
  // REPETICIÓN ANÓMALA
  // ================================================================================================

  bool _hasAnomalousRepetition(
    String cleanDigits,
  ) {
    if (cleanDigits.length < 6) {
      return false;
    }

    final String firstChar =
        cleanDigits[0];

    final bool allIdentical =
        cleanDigits.runes.every(
      (int rune) =>
          String.fromCharCode(rune) ==
          firstChar,
    );

    if (allIdentical) {
      return true;
    }

    final String pattern =
        cleanDigits.substring(0, 2);

    int matches = 0;

    for (
      int i = 0;
      i <= cleanDigits.length - 2;
      i += 2
    ) {
      if (
        cleanDigits.substring(i, i + 2) ==
        pattern
      ) {
        matches++;
      } else {
        break;
      }
    }

    return matches >= 4;
  }

  // ================================================================================================
  // ANÁLISIS PRINCIPAL
  // ================================================================================================

  Map<String, dynamic> analyze({
    required String phoneNumber,
    String? contactName,
    String? callText,
  }) {
    final String rawNumber =
        phoneNumber.trim();

    final String cleanDigits =
        rawNumber.replaceAll(
      RegExp(r'\D'),
      '',
    );

    final String combinedContext =
        '${contactName ?? ''} ${callText ?? ''}'
            .toLowerCase();

    final PhoneValidationStatus validationStatus =
        _evaluateValidationStatus(
      rawNumber,
      cleanDigits,
    );

    int riskScore = 0;

    final List<String> evidence =
        <String>[];

    // ==============================================================================================
    // 1. ESTRUCTURA
    // ==============================================================================================

    switch (validationStatus) {

      case PhoneValidationStatus.hiddenOrUnknown:
        riskScore += 40;

        evidence.add(
          'Número oculto, privado o no identificado.',
        );
        break;

      case PhoneValidationStatus.invalidFormat:
        riskScore += 35;

        evidence.add(
          'Anomalía de formato: longitud incompatible con la estructura internacional esperada.',
        );
        break;

      case PhoneValidationStatus.shortCode:
        riskScore += 25;

        evidence.add(
          'Estructura correspondiente a código corto no verificado.',
        );
        break;

      case PhoneValidationStatus.valid:
        break;
    }

    // ==============================================================================================
    // 2. PREFIJOS ANÓMALOS
    // ==============================================================================================

    if (
      rawNumber.startsWith('+999') ||
      rawNumber.startsWith('+000') ||
      rawNumber.startsWith('000')
    ) {
      riskScore += 45;

      evidence.add(
        'Prefijo de red no asignado o altamente sospechoso.',
      );
    }

    // ==============================================================================================
    // 3. REPETICIÓN EXTREMA
    // ==============================================================================================

    if (
      _hasAnomalousRepetition(
        cleanDigits,
      )
    ) {
      riskScore += 50;

      evidence.add(
        'Patrón numérico altamente repetitivo detectado.',
      );
    }

    // ==============================================================================================
    // 4. INGENIERÍA SOCIAL
    // ==============================================================================================

    int socialEngineeringMatches = 0;

    for (
      final String pattern
          in suspiciousPatterns
    ) {
      if (
        combinedContext.contains(pattern)
      ) {
        socialEngineeringMatches++;

        if (
          socialEngineeringMatches <= 3
        ) {
          riskScore += 15;

          evidence.add(
            "Indicador de ingeniería social detectado: '$pattern'",
          );
        }
      }
    }

    // ==============================================================================================
    // NORMALIZACIÓN
    // ==============================================================================================

    riskScore =
        min(riskScore, 100);

    // ==============================================================================================
    // VEREDICTO HEURÍSTICO
    //
    // IMPORTANTE:
    // Este veredicto NO es todavía el veredicto agéntico final.
    // SecurityCoordinator lo pasa a AgentEngine.
    // ==============================================================================================

    String verdict;
    String statusLabel;

    if (riskScore >= 80) {

      verdict = 'AMENAZA_CONFIRMADA';

      statusLabel =
          '🔴 ALTO RIESGO / AMENAZA';

    } else if (riskScore >= 60) {

      verdict = 'ALTO_RIESGO';

      statusLabel =
          '🟠 ALTO RIESGO';

    } else if (riskScore >= 40) {

      verdict = 'ADVERTENCIA';

      statusLabel =
          '🟡 ADVERTENCIA PREVENTIVA';

    } else if (
      validationStatus ==
      PhoneValidationStatus.invalidFormat
    ) {

      verdict =
          'ANOMALIA_FORMATO';

      statusLabel =
          '🔵 ANOMALÍA DE FORMATO';

    } else if (
      validationStatus ==
      PhoneValidationStatus.shortCode
    ) {

      verdict =
          'SHORTCODE_NO_VERIFICADO';

      statusLabel =
          '🟡 CÓDIGO CORTO NO VERIFICADO';

    } else {

      verdict =
          'SIN_AMENAZAS';

      statusLabel =
          '🟢 SIN AMENAZAS DETECTADAS';
    }

    return <String, dynamic>{
      'phone': phoneNumber,
      'risk_score': riskScore,
      'validation_status':
          validationStatus.name,
      'verdict': verdict,
      'status_label': statusLabel,
      'reasons': evidence,
      'timestamp':
          DateTime.now().toIso8601String(),
    };
  }

  // ================================================================================================
  // DISTANCIA LEVENSHTEIN
  // ================================================================================================

  int similarity(
    String a,
    String b,
  ) {
    if (a == b) {
      return 0;
    }

    if (a.isEmpty) {
      return b.length;
    }

    if (b.isEmpty) {
      return a.length;
    }

    List<int> v0 =
        List<int>.generate(
      b.length + 1,
      (int i) => i,
    );

    List<int> v1 =
        List<int>.filled(
      b.length + 1,
      0,
    );

    for (
      int i = 0;
      i < a.length;
      i++
    ) {
      v1[0] = i + 1;

      for (
        int j = 0;
        j < b.length;
        j++
      ) {
        final int cost =
            a[i] == b[j]
                ? 0
                : 1;

        v1[j + 1] = min(
          v1[j] + 1,
          min(
            v0[j + 1] + 1,
            v0[j] + cost,
          ),
        );
      }

      for (
        int j = 0;
        j <= b.length;
        j++
      ) {
        v0[j] = v1[j];
      }
    }

    return v1[b.length];
  }
}
