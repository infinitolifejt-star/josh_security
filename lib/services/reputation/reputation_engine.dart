import '../core/math_utils.dart';

class ReputationEngine {
  /// Computa el Score de Riesgo final aplicando pesos ponderados y normalización Sigmoide
  double computeRiskScore({
    required double entropy,
    required double frequency,
    required double timeRisk,
    required double durationRisk,
    required double communityScore,
  }) {
    final double rawScore =
        (entropy * 0.25) +
        (frequency * 0.20) +
        (timeRisk * 0.20) +
        (durationRisk * 0.15) +
        (communityScore * 0.20);

    // Multiplicador de escala corregido a flotante para optimización del compilador
    return MathUtils.sigmoid(rawScore * 5.0);
  }

  /// Clasifica el nivel de amenaza en tres umbrales de criticidad adaptados a la UX Humana de Centinela
  String classify(double score) {
    // TODO: [DEUDA TÉCNICA - CENTINELA] Migrar estos umbrales estáticos a una configuración dinámica inyectada desde Render en la Fase 2 de Telemetría Táctica.
    if (score < 0.3) return "SEGURO";
    if (score < 0.6) return "SOSPECHOSO";
    return "CRÍTICO";
  }
}