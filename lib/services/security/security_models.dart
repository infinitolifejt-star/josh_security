// ============================================================================
// ARCHIVO: lib/services/security/security_models.dart
// MODELOS COMPARTIDOS DE SEGURIDAD
// JOSH SECURITY
// ============================================================================

/// Origen del diagnóstico realizado por JOSH Security.
enum DiagnosticSource {
  local,
  cloud,
}

/// Veredicto normalizado para análisis telefónico.
class CallVerdict {
  final String phoneNumber;
  final double riskScore;
  final String riskLevel;
  final String analysisMessage;
  final DiagnosticSource source;
  final List<String> reasons;
  final String timestamp;

  const CallVerdict({
    required this.phoneNumber,
    required this.riskScore,
    required this.riskLevel,
    required this.analysisMessage,
    required this.source,
    this.reasons = const <String>[],
    required this.timestamp,
  });

  bool get isCritical => riskLevel == 'CRÍTICO' || riskScore >= 80.0;

  bool get isWarning =>
      riskLevel == 'ADVERTENCIA' || (riskScore >= 40.0 && riskScore < 80.0);

  bool get isSafe => !isCritical && !isWarning;

  factory CallVerdict.fromMap(Map<String, dynamic> map) {
    final String rawSource = map['source']?.toString() ?? 'local';
    final DiagnosticSource parsedSource = DiagnosticSource.values.firstWhere(
      (DiagnosticSource e) => e.name == rawSource,
      orElse: () => DiagnosticSource.local,
    );

    List<String> parsedReasons = <String>[];
    if (map['reasons'] is List) {
      parsedReasons = (map['reasons'] as List)
          .map((dynamic e) => e.toString())
          .toList();
    }

    return CallVerdict(
      phoneNumber: map['phoneNumber']?.toString() ?? map['phone']?.toString() ?? '',
      riskScore: (map['riskScore'] as num?)?.toDouble() ??
          (map['risk_score'] as num?)?.toDouble() ??
          0.0,
      riskLevel: map['riskLevel']?.toString() ??
          map['verdict']?.toString() ??
          'SIN_AMENAZAS',
      analysisMessage: map['analysisMessage']?.toString() ??
          map['status_label']?.toString() ??
          'Análisis completado.',
      source: parsedSource,
      reasons: parsedReasons,
      timestamp: map['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'phone': phoneNumber,
      'phoneNumber': phoneNumber,
      'riskScore': riskScore,
      'risk_score': riskScore,
      'riskLevel': riskLevel,
      'verdict': riskLevel,
      'analysisMessage': analysisMessage,
      'source': source.name,
      'reasons': reasons,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() {
    return 'CallVerdict('
        'phoneNumber: $phoneNumber, '
        'riskScore: $riskScore, '
        'riskLevel: $riskLevel, '
        'analysisMessage: $analysisMessage, '
        'source: ${source.name}, '
        'reasons: $reasons, '
        'timestamp: $timestamp'
        ')';
  }
}
