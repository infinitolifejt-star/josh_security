// ====================================================================================================
// ARCHIVO: lib/services/analytics/entropy_engine.dart
// MOTOR MATEMÁTICO DE ENTROPÍA DE SHANNON Y ANÁLISIS PATRÓN TEMPORAL v4.6
// ====================================================================================================

import '../core/models.dart';
import '../core/math_utils.dart';

class EntropyEngine {
  /// Analiza la estructura entrópica de un texto (números de teléfono o URLs)
  /// Retorna un puntaje normalizado de 0.0 a 100.0
  double analyzeNumberStructure(String input) {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return 0.0;

    // Calculamos la entropía pura de Shannon mediante MathUtils
    final double rawEntropy = MathUtils.shannonEntropy(cleanInput);

    if (rawEntropy.isNaN || rawEntropy.isInfinite || rawEntropy <= 0.0) {
      return 0.0;
    }

    // Normalizamos la entropía (donde > 3.8 suele indicar alta aleatoriedad/phishing/botnet)
    // convirtiéndola a una escala de riesgo de 0.0 a 100.0
    final double normalizedRisk = (rawEntropy / 4.5) * 100.0;
    return normalizedRisk.clamp(0.0, 100.0);
  }

  /// Evalúa la frecuencia de llamadas o conexiones en las últimas 24 horas
  double analyzeFrequency(List<CallRecord> history) {
    if (history.isEmpty) return 0.0;

    // Anclaje inmutable de tiempo
    final DateTime frozenNow = DateTime.now();

    final int recentCalls = history.where((call) {
      return frozenNow.difference(call.timestamp).inHours < 24;
    }).length;

    // Normalización: 50 o más llamadas en 24h representa el 100% de riesgo de spam
    final double normalized = MathUtils.normalize(recentCalls.toDouble(), 0.0, 50.0);
    return (normalized * 100.0).clamp(0.0, 100.0);
  }

  /// Mide la densidad de riesgo según eventos entrantes en horarios vulnerables/nocturnos (0-5 AM)
  double analyzeTimeRiskDensity(List<CallRecord> history) {
    if (history.isEmpty) return 0.0;

    final int nightCalls = history.where((call) {
      final int hour = call.timestamp.hour;
      return hour >= 0 && hour <= 5;
    }).length;

    // Normalización: 20 llamadas nocturnas en el historial representan el riesgo máximo
    final double normalized = MathUtils.normalize(nightCalls.toDouble(), 0.0, 20.0);
    return (normalized * 100.0).clamp(0.0, 100.0);
  }

  /// Analiza si los eventos corresponden a ráfagas automatizadas (Duración < 10s)
  double analyzeDurationPattern(List<CallRecord> history) {
    final int historyCount = history.length;
    if (historyCount == 0) return 0.0;

    final int totalDuration = history.fold(0, (sum, call) => sum + call.durationSeconds);
    final double avgDuration = totalDuration / historyCount;

    // Retorna 100.0 de riesgo si el promedio de llamada es una ráfaga perdida (< 10 seg)
    return avgDuration < 10.0 ? 100.0 : 0.0;
  }
}