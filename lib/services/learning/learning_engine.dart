// ============================================================================
// ARCHIVO: lib/services/learning/learning_engine.dart
// CEREBRO HEURÍSTICO Y MOTOR DE APRENDIZAJE ADAPTATIVO EN TIEMPO REAL
// JOSH SECURITY
// ============================================================================

import '../security/security_models.dart';

/// Evento heurístico registrado por el motor de aprendizaje local.
class HeuristicEvent {
  final DateTime timestamp;
  final String riskLevel;
  final String identifier;

  const HeuristicEvent({
    required this.timestamp,
    required this.riskLevel,
    required this.identifier,
  });
}

/// Cerebro heurístico local de JOSH Security.
///
/// Mantiene una ventana móvil de eventos sospechosos y ajusta el nivel
/// de riesgo cuando detecta una ráfaga de amenazas.
class LearningEngine {
  static final LearningEngine _instance = LearningEngine._internal();

  factory LearningEngine() => _instance;

  LearningEngine._internal();

  /// Historial volátil de eventos recientes.
  final List<HeuristicEvent> _recentEvents = <HeuristicEvent>[];

  /// Ventana temporal de aprendizaje táctico.
  static const int _timeWindowMinutes = 5;

  /// Cantidad de eventos necesarios para activar el multiplicador.
  static const int _stressThresholdEvents = 3;

  /// Ajustes globales aprendidos.
  ///
  /// Se mantiene preparado para futuras capas de aprendizaje adaptativo.
  final Map<String, double> _biases = const <String, double>{
    'global': 0.0,
  };

  /// Ajusta el score final dentro del rango 0-100.
  double adjustScore(double score) {
    final double adjusted = score + (_biases['global'] ?? 0.0);

    return adjusted.clamp(0.0, 100.0);
  }

  /// Actualiza la reputación local de un identificador.
  void updateCommunityScore(
    Map<String, double> matrix,
    String identifier,
    bool isFraud,
  ) {
    final String cleanKey = identifier.trim();

    if (cleanKey.isEmpty) {
      return;
    }

    matrix[cleanKey] = isFraud ? 100.0 : 0.0;
  }

  /// Registra un veredicto y devuelve el score heurístico resultante.
  double registerAndEvaluatePattern(
    CallVerdict verdict,
  ) {
    final DateTime now = DateTime.now();

    // ------------------------------------------------------------------------
    // 1. LIMPIEZA DE EVENTOS FUERA DE LA VENTANA MÓVIL
    // ------------------------------------------------------------------------

    _recentEvents.removeWhere(
      (HeuristicEvent event) =>
          now.difference(event.timestamp).inMinutes >= _timeWindowMinutes,
    );

    // ------------------------------------------------------------------------
    // 2. REGISTRO DE EVENTOS RELEVANTES
    // ------------------------------------------------------------------------

    if (verdict.riskLevel == 'ADVERTENCIA' || verdict.riskLevel == 'CRÍTICO') {
      _recentEvents.add(
        HeuristicEvent(
          timestamp: now,
          riskLevel: verdict.riskLevel,
          identifier: verdict.phoneNumber,
        ),
      );
    }

    // ------------------------------------------------------------------------
    // 3. DETECCIÓN DE RÁFAGA / CAMPAÑA ACTIVA
    // ------------------------------------------------------------------------

    double anomalyMultiplier = 1.0;

    if (_recentEvents.length >= _stressThresholdEvents) {
      anomalyMultiplier = 1.25;
    }

    // ------------------------------------------------------------------------
    // 4. SCORE BASE
    // ------------------------------------------------------------------------

    double baseScore;

    if (verdict.riskLevel == 'CRÍTICO') {
      baseScore = 85.0;
    } else if (verdict.riskLevel == 'ADVERTENCIA') {
      baseScore = 45.0;
    } else {
      baseScore = 5.0;
    }

    // ------------------------------------------------------------------------
    // 5. SCORE FINAL
    // ------------------------------------------------------------------------

    final double finalScore = baseScore * anomalyMultiplier;

    return adjustScore(finalScore);
  }

  /// Cantidad de amenazas activas dentro de la ventana móvil.
  int get activeThreatsInWindow => _recentEvents.length;

  /// Limpia la sesión de aprendizaje en memoria.
  void clearLearningSession() {
    _recentEvents.clear();
  }
}
