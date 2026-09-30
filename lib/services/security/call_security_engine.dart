// ============================================================================
// ARCHIVO: lib/services/security/call_security_engine.dart
// MOTOR CENTRAL DE ANÁLISIS TELEFÓNICO
// JOSH SECURITY
// ============================================================================

import 'dart:math';

import 'security_models.dart';

/// Estado de validación del número telefónico.
enum PhoneValidationStatus {
  valid,
  invalidFormat,
  shortCode,
  hiddenOrUnknown,
}

/// Motor central de análisis telefónico de JOSH Security.
class CallSecurityEngine {
  const CallSecurityEngine();

  static final RegExp _nonDigitsRegex = RegExp(r'[^0-9]');

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
    'transferencia',
    'pago',
    'contraseña',
    'password',
    'otp',
    'pin',
    'tarjeta',
    'inversion',
    'inversión',
    'deuda',
    'cobro',
    'embargo',
    'policia',
    'policía',
    'fiscalia',
    'fiscalía',
  ];

  PhoneValidationStatus _validatePhone(
    String phoneNumber,
  ) {
    final String normalized = phoneNumber.trim();
    if (normalized.isEmpty) {
      return PhoneValidationStatus.hiddenOrUnknown;
    }

    final String digitsOnly = normalized.replaceAll(_nonDigitsRegex, '');

    if (digitsOnly.isEmpty || digitsOnly.length < 3) {
      return PhoneValidationStatus.invalidFormat;
    }

    if (digitsOnly.length <= 6) {
      return PhoneValidationStatus.shortCode;
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
    final PhoneValidationStatus validation = _validatePhone(normalized);

    final List<String> reasons = <String>[];

    final List<String> patternMatches = _findSuspiciousPatterns(
      contactName: contactName,
      callText: callText,
    );

    double score = 0.0;

    switch (validation) {
      case PhoneValidationStatus.hiddenOrUnknown:
        score = 45.0;
        reasons.add('Número oculto o no disponible.');
        break;

      case PhoneValidationStatus.invalidFormat:
        score = 35.0;
        reasons.add('Formato telefónico no válido.');
        break;

      case PhoneValidationStatus.shortCode:
        score = 30.0;
        reasons.add('Código corto no verificado.');
        break;

      case PhoneValidationStatus.valid:
        break;
    }

    if (patternMatches.isNotEmpty) {
      score += min(patternMatches.length * 10.0, 45.0);

      reasons.add(
        'Se detectaron patrones lingüísticos asociados con solicitudes sensibles.',
      );
    }

    if (validation == PhoneValidationStatus.valid &&
        (contactName == null || contactName.trim().isEmpty)) {
      score += 10.0;

      reasons.add(
        'La llamada no está asociada a un contacto identificado.',
      );
    }

    score = score.clamp(0.0, 100.0);

    String verdict;
    String statusLabel;

    if (score >= 80.0) {
      verdict = 'CRÍTICO';
      statusLabel = 'RIESGO CRÍTICO DETECTADO';
    } else if (score >= 40.0) {
      verdict = 'ADVERTENCIA';
      statusLabel = 'LLAMADA POTENCIALMENTE SOSPECHOSA';
    } else if (validation == PhoneValidationStatus.shortCode) {
      verdict = 'SHORTCODE_NO_VERIFICADO';
      statusLabel = 'CÓDIGO CORTO NO VERIFICADO';
    } else {
      verdict = 'SIN_AMENAZAS';
      statusLabel = 'SIN AMENAZAS DETECTADAS';
    }

    if (reasons.isEmpty) {
      reasons.add(
        'No se detectaron indicadores heurísticos relevantes.',
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
        'Análisis telefónico completado.';

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
