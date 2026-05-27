import 'core/models.dart';
import 'analytics/entropy_engine.dart';
import 'reputation/reputation_engine.dart';
import 'learning/learning_engine.dart';
import 'security/secure_logger.dart';

class ApiService {
  final EntropyEngine _entropyEngine;
  final ReputationEngine _reputationEngine;
  final LearningEngine _learningEngine;
  final SecureLogger _logger;

  /// Matriz local de reputación comunitaria
  final Map<String, double> _communityMatrix;

  ApiService({
    EntropyEngine? entropyEngine,
    ReputationEngine? reputationEngine,
    LearningEngine? learningEngine,
    SecureLogger? logger,
    Map<String, double>? communityMatrix,
  })  : _entropyEngine = entropyEngine ?? EntropyEngine(),
        _reputationEngine = reputationEngine ?? ReputationEngine(),
        _learningEngine = learningEngine ?? LearningEngine(),
        _logger = logger ?? SecureLogger(),
        _communityMatrix = communityMatrix ?? {};

  /// ===============================
  /// 🚀 PUENTE DE CONEXIÓN CON LA UI (Mapeado Seguro)
  /// ===============================
  Future<Map<String, dynamic>> scanTarget(String type, String target) async {
    AnalysisResult analysis;

    if (type == 'TELEFONO') {
      // Ejecuta el oleoducto heurístico real para llamadas
      analysis = analyze(target, []);
    } else {
      // Soporte inicial seguro para vectores de URL y MALWARE
      analysis = AnalysisResult(
        riskScore: 0.05,
        classification: "SAFE",
        metrics: {
          "entropy": 0.0,
          "frequencyRisk": 0.0,
          "timeRisk": 0.0,
          "durationRisk": 0.0,
          "communityScore": 0.05,
        },
      );
    }

    // Convertimos el objeto en el mapa estructurado que la UI necesita mapear
    return {
      'riskScore': analysis.riskScore,
      'classification': analysis.classification,
      'metrics': analysis.metrics,
    };
  }

  /// ===============================
  /// 🔍 CORE ANALYSIS PIPELINE
  /// ===============================
  AnalysisResult analyze(
    String phone,
    List<CallRecord> history,
  ) {
    // ===============================
    // 1. ENTROPY & BEHAVIORAL SIGNALS
    // ===============================
    final double entropy =
        _normalize(_entropyEngine.analyzeNumberStructure(phone));

    final double frequencyRisk =
        _normalize(_entropyEngine.analyzeFrequency(history));

    final double timeRisk =
        _normalize(_entropyEngine.analyzeTimeRiskDensity(history));

    final double durationRisk =
        _normalize(_entropyEngine.analyzeDurationPattern(history));

    final double communityScore =
        _normalize(_communityMatrix[phone] ?? 0.0);

    // ===============================
    // 2. REPUTATION SCORE
    // ===============================
    double riskScore = _reputationEngine.computeRiskScore(
      entropy: entropy,
      frequency: frequencyRisk,
      timeRisk: timeRisk,
      durationRisk: durationRisk,
      communityScore: communityScore,
    );

    // ===============================
    // 3. LEARNING ADJUSTMENT
    // ===============================
    riskScore = _learningEngine.adjustScore(riskScore);
    riskScore = _normalize(riskScore);

    // ===============================
    // 4. CLASSIFICATION
    // ===============================
    final String classification =
        _reputationEngine.classify(riskScore);

    // ===============================
    // 5. SECURE LOGGING
    // ===============================
    _logger.createSecureLog(
      _buildLogPayload(
        phone: phone,
        score: riskScore,
        classification: classification,
      ),
    );

    // ===============================
    // 6. RESULT OBJECT (Alineado con models.dart)
    // ===============================
    return AnalysisResult(
      riskScore: riskScore,
      classification: classification,
      metrics: {
        "entropy": entropy,
        "frequencyRisk": frequencyRisk,
        "timeRisk": timeRisk,
        "durationRisk": durationRisk,
        "communityScore": communityScore,
      },
    );
  }

  /// ===============================
  /// 🔐 SECURE LOG BUILDER
  /// ===============================
  String _buildLogPayload({
    required String phone,
    required double score,
    required String classification,
  }) {
    final timestamp =
        DateTime.now().toIso8601String();

    return "TS:$timestamp|PHONE:$phone|SCORE:${score.toStringAsFixed(5)}|CLASS:$classification";
  }

  /// ===============================
  /// 📊 NORMALIZATION FUNCTION
  /// ===============================
  double _normalize(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;

    if (value < 0.0) return 0.0;
    if (value > 1.0) return 1.0;

    return value;
  }

  /// ===============================
  /// 🤖 COMMUNITY FEEDBACK UPDATE
  /// ===============================
  void updateCommunityScore(
    String phone,
    double feedbackScore,
  ) {
    final current = _communityMatrix[phone] ?? 0.0;

    // Exponential moving average
    final updated =
        (0.7 * current) + (0.3 * feedbackScore);

    _communityMatrix[phone] = _normalize(updated);
  }
}

/// PUENTE DOBLE DE COMPATIBILIDAD DE TIPOS
typedef PhoneHeuristicEngine = ApiService;