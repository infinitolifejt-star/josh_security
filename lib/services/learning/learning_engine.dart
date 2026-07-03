class LearningEngine {
  // Biases del motor de aprendizaje optimizados con inmutabilidad
  final Map<String, double> _biases = const {
    "global": 0.0,
  };

  /// Ajusta el Score final calculando las desviaciones globales aprendidas con acotamiento estricto
  double adjustScore(double score) {
    // Blindaje Null-Safety con operador de contingencia y restricción estricta de límites (0.0 - 1.0)
    final double adjusted = score + (_biases["global"] ?? 0.0);
    return adjusted.clamp(0.0, 1.0);
  }

  /// Actualiza dinámicamente la matriz de reputación comunitaria local según la confirmación de fraude
  void updateCommunityScore(Map<String, double> matrix, String phone, bool isFraud) {
    // Protección forense básica contra entradas vacías
    if (phone.trim().isEmpty) return;

    // TODO: [DEUDA TÉCNICA - CENTINELA] Migrar esta mutación en memoria local a un servicio de persistencia reactivo indexado o sincronizado asíncronamente con el cerebro central en Render para la Fase 2.
    matrix[phone] = isFraud ? 1.0 : 0.0;
  }
}