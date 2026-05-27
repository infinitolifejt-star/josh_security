// lib/services/analytics/entropy_engine.dart

import '../core/models.dart';
import '../core/math_utils.dart';

class EntropyEngine {
  double analyzeNumberStructure(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return MathUtils.shannonEntropy(normalized);
  }

  double analyzeFrequency(List<CallRecord> history) {
    if (history.isEmpty) return 0;

    final now = DateTime.now();
    int recentCalls = history.where((call) {
      return now.difference(call.timestamp).inHours < 24;
    }).length;

    return MathUtils.normalize(recentCalls.toDouble(), 0, 50);
  }

  double analyzeTimeRiskDensity(List<CallRecord> history) {
    int nightCalls = history.where((call) {
      int hour = call.timestamp.hour;
      return hour >= 0 && hour <= 5;
    }).length;

    return MathUtils.normalize(nightCalls.toDouble(), 0, 20);
  }

  double analyzeDurationPattern(List<CallRecord> history) {
    if (history.isEmpty) return 0;

    double avg = history
            .map((c) => c.durationSeconds)
            .reduce((a, b) => a + b) /
        history.length;

    return avg < 10 ? 1.0 : 0.0; // llamadas cortas = sospechoso
  }
}