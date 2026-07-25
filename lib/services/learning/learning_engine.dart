// ====================================================================================================
// ARCHIVO: lib/services/learning/learning_engine.dart
// CEREBRO HEURÍSTICO Y MOTOR DE APRENDIZAJE ADAPTATIVO EN TIEMPO REAL v4.6
// ====================================================================================================

import '../security/phone_interceptor_service.dart';

/// Modelo de evento de seguridad registrado por el motor heurístico local
class HeuristicEvent {
  final DateTime timestamp;
  final String riskLevel;
  final String identifier;

  HeuristicEvent({
    required this.timestamp,
    required this.riskLevel,
    required this.identifier,
  });
}

/// Cerebro heurístico local de Centinela para detectar patrones de ataque dirigidos
class LearningEngine {
  // Patrón Singleton para acceso global único y seguro
  static final LearningEngine _instance = LearningEngine._internal();
  factory LearningEngine() => _instance;
  LearningEngine._internal();

  // Historial en memoria volátil de eventos recientes de seguridad (Ventana Móvil)
  final List<HeuristicEvent> _recentEvents = [];

  // Configuración de la heurística local
  static const int _timeWindowMinutes = 5;
  static const int _stressThresholdEvents = 3;

  // Biases del motor de aprendizaje optimizados con inmutabilidad
  final Map<String, double> _biases = const {
    "global": 0.0,
  };

  /// Ajusta el Score final calculando las desviaciones globales aprendidas (Escala 0.0 - 100.0)
  double adjustScore(double score) {
    final double adjusted = score + (_biases["global"] ?? 0.0);
    return adjusted.clamp(0.0, 100.0);
  }

  /// Actualiza dinámicamente la matriz de reputación comunitaria local según confirmación de fraude
  void updateCommunityScore(Map<String, double> matrix, String identifier, bool isFraud) {
    final String cleanKey = identifier.trim();
    if (cleanKey.isEmpty) return;

    // Asigna 100.0 para fraude confirmado o 0.0 para limpio
    matrix[cleanKey] = isFraud ? 100.0 : 0.0;
  }

  /// Registra un veredicto en el historial heurístico y retorna el score de riesgo recalculado (0.0 - 100.0)
  double registerAndEvaluatePattern(CallVerdict verdict) {
    final DateTime now = DateTime.now();

    // 1. Limpiar primero eventos viejos fuera de la ventana táctica de 5 minutos
    _recentEvents.removeWhere((event) =>
      now.difference(event.timestamp).inMinutes >= _timeWindowMinutes
    );

    // 2. Registrar el evento actual únicamente si representa sospecha o riesgo real
    if (verdict.riskLevel == 'ADVERTENCIA' || verdict.riskLevel == 'CRÍTICO') {
      _recentEvents.add(
        HeuristicEvent(
          timestamp: now,
          riskLevel: verdict.riskLevel,
          identifier: verdict.phoneNumber,
        ),
      );
    }

    // 3. Evaluar ráfagas / Ataques coordinados (Análisis de Estrés)
    double anomalyMultiplier = 1.0;
    if (_recentEvents.length >= _stressThresholdEvents) {
      // Multiplicador de elevación por sospecha de campaña activa o extorsión masiva
      anomalyMultiplier = 1.25;
    }

    // 4. Calcular el score base en escala 0.0 - 100.0
    double baseScore = 0.0;
    if (verdict.riskLevel == 'CRÍTICO') {
      baseScore = 85.0;
    } else if (verdict.riskLevel == 'ADVERTENCIA') {
      baseScore = 45.0;
    } else {
      baseScore = 5.0;
    }

    // 5. Aplicar multiplicador y acotar estrictamente a límites de interfaz (0 - 100)
    final double finalScore = (baseScore * anomalyMultiplier);
    return adjustScore(finalScore);
  }

  /// Retorna la cantidad de amenazas activas registradas en la ventana móvil actual
  int get activeThreatsInWindow => _recentEvents.length;

  /// Reinicia la sesión de aprendizaje heurístico en memoria
  void clearLearningSession() {
    _recentEvents.clear();
  }
}