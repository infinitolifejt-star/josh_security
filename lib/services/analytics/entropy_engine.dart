import '../core/models.dart';
import '../core/math_utils.dart';

class EntropyEngine {
  /// Analiza la estructura del número telefónico calculando su entropía de Shannon con salvaguarda
  double analyzeNumberStructure(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) return 0.0;
    
    final double score = MathUtils.shannonEntropy(normalized);
    return (score.isNaN || score.isInfinite || score < 0.0) ? 0.0 : score;
  }

  /// Evalúa la frecuencia de llamadas en las últimas 24 horas mitigando condiciones de carrera
  double analyzeFrequency(List<CallRecord> history) {
    if (history.isEmpty) return 0.0;

    // Anclaje de tiempo inmutable para el hilo de ejecución asíncrono
    final DateTime frozenNow = DateTime.now();
    
    final int recentCalls = history.where((call) {
      return frozenNow.difference(call.timestamp).inHours < 24;
    }).length;

    return MathUtils.normalize(recentCalls.toDouble(), 0.0, 50.0);
  }

  /// Mide la densidad de riesgo según llamadas entrantes en horarios no laborales o nocturnos (0-5 AM)
  double analyzeTimeRiskDensity(List<CallRecord> history) {
    if (history.isEmpty) return 0.0;

    final int nightCalls = history.where((call) {
      final int hour = call.timestamp.hour;
      return hour >= 0 && hour <= 5;
    }).length;

    return MathUtils.normalize(nightCalls.toDouble(), 0.0, 20.0);
  }

  /// Analiza si las llamadas son ráfagas automatizadas (Duración menor a 10 segundos) con protección contra división por cero
  double analyzeDurationPattern(List<CallRecord> history) {
    if (history.isEmpty) return 0.0;

    final int totalDuration = history.fold(0, (sum, call) => sum + call.durationSeconds);
    
    // Protección forense contra listas corruptas de longitud cero
    final int historyCount = history.length;
    if (historyCount == 0) return 0.0;
    
    final double avg = totalDuration / historyCount;

    return avg < 10.0 ? 1.0 : 0.0; // Llamadas demasiado cortas delatan posible bot o spam automatizado
  }
}