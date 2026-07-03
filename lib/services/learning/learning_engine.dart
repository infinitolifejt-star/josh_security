// lib/services/learning/learning_engine.dart

class LearningEngine {
  // Biases del motor de aprendizaje optimizados con inmutabilidad
  final Map<String, double> _biases = const {
    "global": 0.0,
  };

  /// Ajusta el Score final calculando las desviaciones y desviaciones globales aprendidas
  double adjustScore(double score) {
    // Blindaje Null-Safety con operador de contingencia en lugar de forzado !
    return score + (_biases["global"] ?? 0.0);
  }

  /// Actualiza dinámicamente la matriz de reputación comunitaria local según la confirmación de fraude
  void updateCommunityScore(Map<String, double> matrix, String phone, bool isFraud) {
    matrix[phone] = isFraud ? 1.0 : 0.0;
  }
}