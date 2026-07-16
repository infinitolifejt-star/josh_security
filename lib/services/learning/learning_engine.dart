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
  // Patrón Singleton para acceso global seguro
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

  /// Ajusta el Score final calculando las desviaciones globales aprendidas con acotamiento estricto (0.0 - 1.0)
  double adjustScore(double score) {
    final double adjusted = score + (_biases["global"] ?? 0.0);
    return adjusted.clamp(0.0, 1.0);
  }

  /// Actualiza dinámicamente la matriz de reputación comunitaria local según la confirmación de fraude
  void updateCommunityScore(Map<String, double> matrix, String phone, bool isFraud) {
    if (phone.trim().isEmpty) return;

    // NOTA: [MIGRACIÓN CENTINELA] Sincronización asíncrona con el cerebro en Render planificada para Fase 2.
    matrix[phone] = isFraud ? 1.0 : 0.0;
  }

  /// Registra un veredicto de llamada en el historial heurístico y retorna el score de riesgo recalculado (0.0 - 100.0)
  double registerAndEvaluatePattern(CallVerdict verdict) {
    final now = DateTime.now();
    
    // 1. Registrar únicamente eventos sospechosos o críticos
    if (verdict.riskLevel == 'ADVERTENCIA' || verdict.riskLevel == 'CRÍTICO') {
      _recentEvents.add(
        HeuristicEvent(
          timestamp: now,
          riskLevel: verdict.riskLevel,
          identifier: verdict.phoneNumber,
        ),
      );
    }

    // 2. Limpiar eventos antiguos fuera de la ventana de 5 minutos
    _recentEvents.removeWhere((event) => 
      now.difference(event.timestamp).inMinutes >= _timeWindowMinutes
    );

    // 3. Evaluar ráfagas (Análisis de Estrés)
    double anomalyMultiplier = 1.0;
    if (_recentEvents.length >= _stressThresholdEvents) {
      // Elevación exponencial por sospecha de campaña coordinada de extorsión
      anomalyMultiplier = 1.5;
    }

    // 4. Calcular el score base (0.0 - 100.0)
    double baseScore = 0.0;
    if (verdict.riskLevel == 'CRÍTICO') {
      baseScore = 80.0;
    } else if (verdict.riskLevel == 'ADVERTENCIA') {
      baseScore = 40.0;
    } else {
      baseScore = 10.0;
    }

    // 5. Aplicar multiplicador heurístico y acotar a límites lógicos
    double finalScore = baseScore * anomalyMultiplier;
    return finalScore.clamp(0.0, 100.0);
  }

  /// Retorna la cantidad de amenazas activas en la ventana de tiempo actual
  int get activeThreatsInWindow => _recentEvents.length;

  /// Limpia la sesión de aprendizaje heurístico
  void clearLearningSession() {
    _recentEvents.clear();
  }
}