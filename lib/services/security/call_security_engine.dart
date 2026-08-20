import 'dart:math';

enum PhoneValidationStatus {
  valid,
  invalidFormat,
  shortCode,
  hiddenOrUnknown,
}

class CallSecurityEngine {
  const CallSecurityEngine();

  static const List<String> suspiciousPatterns = <String>[
    'banco',
    'seguridad',
    'soporte',
    'verificacion',
    'verificación',
    'premio',
    'ganaste',
    'urgente',
    'bloqueo',
    'cuenta',
    'clave',
    'codigo',
    'código',
    'token',
    'confirmar',
    'actualizar',
    'credito',
    'crédito',
    'inversion',
    'inversión',
    'oferta',
    'wallet',
    'crypto',
    'cripto',
  ];

  static const Set<String> _hiddenValues = <String>{
    '',
    'unknown',
    'unknown number',
    'unknown caller',
    'desconocido',
    'numero desconocido',
    'número desconocido',
    'private',
    'private number',
    'privado',
    'numero privado',
    'número privado',
    'restricted',
    'restricted number',
    'restringido',
    'oculto',
    'numero oculto',
    'número oculto',
    'hidden',
    'null',
    'n/a',
    'na',
  };

  PhoneValidationStatus _evaluateValidationStatus(
    String rawNumber,
    String cleanDigits,
  ) {
    final String normalized =
        rawNumber.trim().toLowerCase();

    if (_hiddenValues.contains(normalized) ||
        cleanDigits.isEmpty) {
      return PhoneValidationStatus.hiddenOrUnknown;
    }

    if (cleanDigits.length >= 3 &&
        cleanDigits.length <= 6) {
      return PhoneValidationStatus.shortCode;
    }

    if (cleanDigits.length < 7 ||
        cleanDigits.length > 15) {
      return PhoneValidationStatus.invalidFormat;
    }

    return PhoneValidationStatus.valid;
  }

  bool _hasAnomalousRepetition(String digits) {
    if (digits.length < 6) {
      return false;
    }

    final String firstDigit = digits[0];

    if (digits.split('').every(
          (String digit) => digit == firstDigit,
        )) {
      return true;
    }

    if (digits.length < 8) {
      return false;
    }

    final String pattern =
        digits.substring(0, 2);

    int matches = 0;

    for (
      int i = 0;
      i <= digits.length - 2;
      i += 2
    ) {
      if (digits.substring(i, i + 2) != pattern) {
        break;
      }

      matches++;
    }

    return matches >= 4;
  }

  int _suspiciousContextScore(
    String context,
    List<String> reasons,
  ) {
    int score = 0;
    int matches = 0;

    for (final String pattern in suspiciousPatterns) {
      if (!context.contains(pattern)) {
        continue;
      }

      matches++;

      if (matches <= 3) {
        score += 15;

        reasons.add(
          "Indicador de ingeniería social detectado: '$pattern'.",
        );
      }
    }

    return score;
  }

  String _normalizeForComparison(String value) {
    return value.replaceAll(
      RegExp(r'\D'),
      '',
    );
  }

  Map<String, dynamic> analyze({
    required String phoneNumber,
    String? contactName,
    String? callText,
  }) {
    final String raw = phoneNumber.trim();

    final String digits =
        _normalizeForComparison(raw);

    final String context = <String>[
      contactName ?? '',
      callText ?? '',
    ].join(' ').toLowerCase();

    final PhoneValidationStatus validation =
        _evaluateValidationStatus(
      raw,
      digits,
    );

    int score = 0;

    final List<String> reasons =
        <String>[];

    switch (validation) {
      case PhoneValidationStatus.hiddenOrUnknown:
        score += 40;

        reasons.add(
          'Número oculto, privado o no identificado.',
        );
        break;

      case PhoneValidationStatus.invalidFormat:
        score += 35;

        reasons.add(
          'Anomalía de formato: longitud incompatible con una estructura telefónica válida.',
        );
        break;

      case PhoneValidationStatus.shortCode:
        score += 25;

        reasons.add(
          'Estructura correspondiente a código corto no verificado.',
        );
        break;

      case PhoneValidationStatus.valid:
        break;
    }

    final String normalizedRaw =
        raw.replaceAll(
      RegExp(r'[\s()-]'),
      '',
    );

    if (normalizedRaw.startsWith('+999') ||
        normalizedRaw.startsWith('+000') ||
        normalizedRaw.startsWith('000')) {
      score += 45;

      reasons.add(
        'Prefijo telefónico no válido o altamente sospechoso.',
      );
    }

    if (_hasAnomalousRepetition(digits)) {
      score += 50;

      reasons.add(
        'Patrón numérico altamente repetitivo detectado.',
      );
    }

    score += _suspiciousContextScore(
      context,
      reasons,
    );

    score = min(score, 100);

    final String verdict;
    final String statusLabel;

    if (score >= 80) {
      verdict = 'RIESGO_MUY_ALTO';
      statusLabel = '🔴 RIESGO MUY ALTO';
    } else if (score >= 60) {
      verdict = 'ALTO_RIESGO';
      statusLabel = '🟠 ALTO RIESGO';
    } else if (score >= 40) {
      verdict = 'ADVERTENCIA';
      statusLabel = '🟡 ADVERTENCIA PREVENTIVA';
    } else if (validation ==
        PhoneValidationStatus.invalidFormat) {
      verdict = 'ANOMALIA_FORMATO';
      statusLabel = '🔵 ANOMALÍA DE FORMATO';
    } else if (validation ==
        PhoneValidationStatus.shortCode) {
      verdict = 'SHORTCODE_NO_VERIFICADO';
      statusLabel = '🟡 CÓDIGO CORTO NO VERIFICADO';
    } else {
      verdict = 'SIN_AMENAZAS';
      statusLabel = '🟢 SIN AMENAZAS DETECTADAS';
    }

    return <String, dynamic>{
      'phone': phoneNumber,
      'risk_score': score,
      'validation_status': validation.name,
      'verdict': verdict,
      'status_label': statusLabel,
      'reasons': reasons,
      'timestamp':
          DateTime.now().toIso8601String(),
    };
  }
}
