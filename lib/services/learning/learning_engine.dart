// lib/services/learning/learning_engine.dart

class LearningEngine {
  final Map<String, double> weights = {
    "entropy": 0.25,
    "frequency": 0.20,
    "timeRisk": 0.20,
    "duration": 0.15,
    "community": 0.20,
  };

  final Map<String, double> biases = {
    "global": 0.0,
  };

  double adjustScore(double score) {
    return score + biases["global"]!;
  }

  void updateCommunityScore(Map<String, double> matrix, String phone, bool isFraud) {
    matrix[phone] = isFraud ? 1.0 : 0.0;
  }
}