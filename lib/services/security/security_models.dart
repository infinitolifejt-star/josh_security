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
///
/// Este es el único modelo CallVerdict compartido por:
/// - CallSecurityEngine
/// - LearningEngine
/// - ForensicReportService
/// - futuras capas de persistencia y auditoría
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

  bool get isCritical =>
      riskLevel == 'CRÍTICO' || riskScore >= 80.0;

  bool get isWarning =>
      riskLevel == 'ADVERTENCIA' ||
      (riskScore >= 40.0 && riskScore < 80.0);

  bool get isSafe => !isCritical && !isWarning;

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
