// lib/services/reputation/reputation_engine.dart

import '../core/math_utils.dart';

class ReputationEngine {
  double computeRiskScore({
    required double entropy,
    required double frequency,
    required double timeRisk,
    required double durationRisk,
    required double communityScore,
  }) {
    double rawScore =
        (entropy * 0.25) +
        (frequency * 0.20) +
        (timeRisk * 0.20) +
        (durationRisk * 0.15) +
        (communityScore * 0.20);

    return MathUtils.sigmoid(rawScore * 5);
  }

  String classify(double score) {
    if (score < 0.3) return "SAFE";
    if (score < 0.6) return "SUSPICIOUS";
    return "CRITICAL";
  }
}