// lib/services/core/models.dart

class CallRecord {
  final String phone;
  final DateTime timestamp;
  final int durationSeconds;

  CallRecord({
    required this.phone,
    required this.timestamp,
    required this.durationSeconds,
  });
}

class AnalysisResult {
  final double riskScore; // 0.0 - 1.0
  final String classification;
  final Map<String, double> metrics;

  AnalysisResult({
    required this.riskScore,
    required this.classification,
    required this.metrics,
  });
}