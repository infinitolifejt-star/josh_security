// ============================================================================
// ARCHIVO: lib/services/security/call_security_engine.dart
// MOTOR CENTRAL DE ANÃLISIS TELEFÃ“NICO
// JOSH SECURITY
// ============================================================================

import 'dart:math';

import 'security_models.dart';

/// Estado de validaciÃ³n del nÃºmero telefÃ³nico.
enum PhoneValidationStatus {
  valid,
  invalidFormat,
  shortCode,
  hiddenOrUnknown,
}

/// Motor central de anÃ¡lisis telefÃ³nico de JOSH Security.
class CallSecurityEngine {
  const CallSecurityEngine();

  static const List<String> suspiciousPatterns = <String>[
    'banco',
    'seguridad',
    'soporte',
    'verificacion',
    'verificaciÃ³n',
    'premio',
    'ganaste',
    'urgente',
    'bloqueo',
    'cuenta',
    'clave',
    'codigo',
    'cÃ³digo',
    'token',
    'confirmar',
    'actualizar',
    'credito',
    'crÃ©dito',
    'transferencia',
    'pago',
    'contraseÃ±a',
    'password',
    'otp',
    'pin',
    'tarjeta',
    'inversion',
    'inversiÃ³n',
    'deuda',
    'cobro',
    'embargo',
    'policia',
    'policÃ­a',
    'fiscalia',
    'fiscalÃ­a',
  ];

  PhoneValidationStatus _validatePhone(
    String phoneNumber,
  ) {
    final String normalized = phoneNumber.trim();
    if (normalized.isEmpty) {
      return PhoneValidationStatus.hiddenOrUnknown;
    }

    final String digitsOnly = normalized.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (digitsOnly.isEmpty) {
      return PhoneValidationStatus.invalidFormat;
    }

    if (digitsOnly.length <= 6) {
      return PhoneValidationStatus.shortCode;
    }

    if (digitsOnly.length < 7) {
      return PhoneValidationStatus.invalidFormat;
    }

    return PhoneValidationStatus.valid;
  }

  List<String> _findSuspiciousPatterns({
    String? contactName,
    String? callText,
  }) {
    final String combined = [
      contactName ?? '',
      callText ?? '',
    ].join(' ').toLowerCase();
    if (combined.trim().isEmpty) {
      return <String>[];
    }

    final List<String> matches = <String>[];

    for (final String pattern in suspiciousPatterns) {
      if (combined.contains(pattern) && !matches.contains(pattern)) {
        matches.add(pattern);
      }
    }

    return matches;
  }

  Map<String, dynamic> analyze({
    required String phoneNumber,
    String? contactName,
    String? callText,
  }) {
    final String normalized = phoneNumber.trim();
    final PhoneValidationStatus validation = _validatePhone(
      normalized,
    );

    final List<String> reasons = <String>[];

    final List<String> patternMatches = _findSuspiciousPatterns(
      contactName: contactName,
      callText: callText,
    );

    double score = 0.0;

    switch (validation) {
      case PhoneValidationStatus.hiddenOrUnknown:
        score = 45.0;
        reasons.add(
          'NÃºmero oculto o no disponible.',
        );
        break;

      case PhoneValidationStatus.invalidFormat:
        score = 35.0;
        reasons.add(
          'Formato telefÃ³nico no vÃ¡lido.',
        );
        break;

      case PhoneValidationStatus.shortCode:
        score = 30.0;
        reasons.add(
          'CÃ³digo corto no verificado.',
        );
        break;

      case PhoneValidationStatus.valid:
        break;
    }

    if (patternMatches.isNotEmpty) {
      score += min(
        patternMatches.length * 10.0,
        45.0,
      );

      reasons.add(
        'Se detectaron patrones lingÃ¼Ã­sticos '
        'asociados con solicitudes sensibles.',
      );
    }

    if (validation == PhoneValidationStatus.valid &&
        (contactName == null || contactName.trim().isEmpty)) {
      score += 10.0;

      reasons.add(
        'La llamada no estÃ¡ asociada a un contacto identificado.',
      );
    }

    score = score.clamp(0.0, 100.0);

    String verdict;
    String statusLabel;

    if (score >= 80.0) {
      verdict = 'CRÃTICO';
      statusLabel = 'RIESGO CRÃTICO DETECTADO';
    } else if (score >= 40.0) {
      verdict = 'ADVERTENCIA';
      statusLabel = 'LLAMADA POTENCIALMENTE SOSPECHOSA';
    } else if (validation == PhoneValidationStatus.shortCode) {
      verdict = 'SHORTCODE_NO_VERIFICADO';
      statusLabel = 'CÃ“DIGO CORTO NO VERIFICADO';
    } else {
      verdict = 'SIN_AMENAZAS';
      statusLabel = 'SIN AMENAZAS DETECTADAS';
    }

    if (reasons.isEmpty) {
      reasons.add(
        'No se detectaron indicadores heurÃ­sticos relevantes.',
      );
    }

    return <String, dynamic>{
      'phone': normalized,
      'phoneNumber': normalized,
      'risk_score': score,
      'riskScore': score,
      'validation_status': validation.name,
      'verdict': verdict,
      'riskLevel': verdict,
      'status_label': statusLabel,
      'reasons': reasons,
      'timestamp': DateTime.now().toIso8601String(),
      'source': DiagnosticSource.local.name,
    };
  }

  /// Convierte el resultado del motor al modelo compartido.
  CallVerdict buildVerdict({
    required String phoneNumber,
    String? contactName,
    String? callText,
  }) {
    final Map<String, dynamic> result = analyze(
      phoneNumber: phoneNumber,
      contactName: contactName,
      callText: callText,
    );
    final double score = (result['riskScore'] as num?)?.toDouble() ?? 0.0;

    final String riskLevel = result['riskLevel']?.toString() ??
        result['verdict']?.toString() ??
        'SIN_AMENAZAS';

    final String analysisMessage = result['status_label']?.toString() ??
        'AnÃ¡lisis telefÃ³nico completado.';

    final String timestamp =
        result['timestamp']?.toString() ?? DateTime.now().toIso8601String();

    return CallVerdict(
      phoneNumber: phoneNumber,
      riskScore: score,
      riskLevel: riskLevel,
      analysisMessage: analysisMessage,
      source: DiagnosticSource.local,
      timestamp: timestamp,
    );
  }
}
