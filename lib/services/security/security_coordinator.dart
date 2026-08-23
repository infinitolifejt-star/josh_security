import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../learning/learning_engine.dart';
import 'agent_engine.dart';
import 'call_security_engine.dart';
import 'security_models.dart';
import 'phishing_engine.dart';
import 'telemetry_service.dart';

class SecurityCoordinator {
  SecurityCoordinator({
    required PhishingEngine phishingEngine,
    required CallSecurityEngine callSecurityEngine,
    required TelemetryService telemetryService,
  })  : _phishingEngine = phishingEngine,
        _callSecurityEngine = callSecurityEngine,
        _telemetryService = telemetryService;

  final PhishingEngine _phishingEngine;
  final CallSecurityEngine _callSecurityEngine;
  final TelemetryService _telemetryService;

  final LearningEngine _learningEngine = LearningEngine();

  bool _initialized = false;

  // ==========================================================================
  // TRAZA
  // ==========================================================================

  void _trace(String message) {
    if (kDebugMode) {
      debugPrint(
        '[JOSH_TRACE] [SecurityCoordinator] $message',
      );
    }

    developer.log(
      message,
      name: 'josh.security.coordinator',
    );
  }

  // ==========================================================================
  // INICIALIZACIÓN
  // ==========================================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _trace(
      'Inicializando Coordinador Central de Seguridad...',
    );

    await _telemetryService.initialize();

    _initialized = true;

    _trace(
      'Coordinador Central de Seguridad operativo.',
    );
  }

  // ==========================================================================
  // EXTRACCIÓN SEGURA DE SCORE
  // ==========================================================================

  double _extractRiskScore(
    Map<String, dynamic> result,
  ) {
    final dynamic raw = result['score'] ??
        result['risk_score'] ??
        result['riskScore'] ??
        result['agentRiskScore'];

    if (raw is num) {
      return raw.toDouble().clamp(0.0, 100.0);
    }

    if (raw is String) {
      final double? parsed = double.tryParse(raw);

      if (parsed != null) {
        return parsed.clamp(0.0, 100.0);
      }
    }

    return 0.0;
  }

  // ==========================================================================
  // COMBINACIÓN DE MOTORES
  //
  // Heurística local -> 50 %
  // Aprendizaje      -> 20 %
  // Agente           -> 30 %
  // ==========================================================================

  double _resolveFinalRiskScore({
    required double heuristicRisk,
    required double learningRisk,
    required double agentRisk,
  }) {
    final double heuristic = heuristicRisk.clamp(0.0, 100.0);
    final double learning = learningRisk.clamp(0.0, 100.0);

    if (!agentRisk.isFinite) {
      return ((heuristic * 0.70) + (learning * 0.30)).clamp(0.0, 100.0);
    }

    final double agent = agentRisk.clamp(0.0, 100.0);

    final double combined =
        (heuristic * 0.50) + (learning * 0.20) + (agent * 0.30);

    if (heuristic >= 80.0 && combined < 60.0) {
      return 60.0;
    }

    if (learning >= 80.0 && combined < 60.0) {
      return 60.0;
    }

    return combined.clamp(0.0, 100.0);
  }

  // ==========================================================================
  // NORMALIZACIÓN DE NIVEL DE RIESGO
  // ==========================================================================

  String _resolveRiskLevel(
    double score,
  ) {
    if (score >= 80.0) {
      return 'CRÍTICO';
    }

    if (score >= 40.0) {
      return 'ADVERTENCIA';
    }

    return 'SEGURO';
  }

  // ==========================================================================
  // TEXTO SEGURO
  // ==========================================================================

  String _safeString(
    dynamic value,
  ) {
    if (value == null) {
      return 'UNKNOWN';
    }

    final String text = value.toString().trim();

    return text.isEmpty ? 'UNKNOWN' : text;
  }

  // ==========================================================================
  // VECTOR 1 - PHISHING / URL
  // ==========================================================================

  Future<Map<String, dynamic>> scanUrl(
    String url,
  ) async {
    await initialize();

    final String target = url.trim();

    _trace(
      'Iniciando escaneo de URL: $target',
    );

    final Map<String, dynamic> heuristic = Map<String, dynamic>.from(
      _phishingEngine.analyze(target),
    );

    final double heuristicRisk = _extractRiskScore(heuristic);

    _trace(
      'Score heurístico URL: $heuristicRisk',
    );

    final AgentVerdict agent = await AgentEngine.evaluateThreat(
      target: target,
      vectorType: 'PHISHING',
      heuristicRiskScore: heuristicRisk,
    );

    final double finalRisk = _resolveFinalRiskScore(
      heuristicRisk: heuristicRisk,
      learningRisk: heuristicRisk,
      agentRisk: agent.finalRiskScore,
    );

    final String finalRiskLevel = _resolveRiskLevel(finalRisk);

    final Map<String, dynamic> result = <String, dynamic>{
      ...heuristic,
      'target': target,
      'vector': 'PHISHING',
      'score': finalRisk,
      'riskScore': finalRisk,
      'riskLevel': finalRiskLevel,
      'heuristicRiskScore': heuristicRisk,
      'learningRiskScore': heuristicRisk,
      'agentRiskScore': agent.finalRiskScore,
      'verdict': finalRiskLevel,
      'agentStatus': agent.statusText,
      'agentReasoning': agent.reasoning,
      'requiresExternalLookup': agent.requiresExternalLookup,
      'actionRecommendation': agent.actionRecommendation,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _telemetryService.incrementLinksChecked();

    await _telemetryService.registerEvent(
      type: 'URL_SCAN',
      message: 'Análisis de URL ejecutado',
      metadata: result,
    );

    await _telemetryService.addForensicLog(
      event: 'PHISHING_SCAN',
      severity: _safeString(
        result['verdict'],
      ),
      details: agent.reasoning,
    );

    return result;
  }

  // ==========================================================================
  // VECTOR 0 - LLAMADAS
  // ==========================================================================

  Future<Map<String, dynamic>> scanCall({
    required String phoneNumber,
    String? contactName,
    String? text,
  }) async {
    await initialize();

    final String target = phoneNumber.trim();

    _trace(
      'Procesando llamada entrante -> '
      'Número: $target | '
      'Contacto: ${contactName ?? "N/A"}',
    );

    // ------------------------------------------------------------------------
    // MOTOR 1: HEURÍSTICA TELEFÓNICA
    // ------------------------------------------------------------------------

    final Map<String, dynamic> heuristic = Map<String, dynamic>.from(
      _callSecurityEngine.analyze(
        phoneNumber: target,
        contactName: contactName,
        callText: text,
      ),
    );

    final double heuristicRisk = _extractRiskScore(heuristic);

    _trace(
      'Score heurístico: $heuristicRisk',
    );

    // ------------------------------------------------------------------------
    // MOTOR 2: APRENDIZAJE ADAPTATIVO
    // ------------------------------------------------------------------------

    final CallVerdict learningVerdict = _callSecurityEngine.buildVerdict(
      phoneNumber: target,
      contactName: contactName,
      callText: text,
    );

    final double learningRisk = _learningEngine.registerAndEvaluatePattern(
      learningVerdict,
    );

    _trace(
      'Score de aprendizaje: $learningRisk',
    );

    // ------------------------------------------------------------------------
    // MOTOR 3: AGENTE
    // ------------------------------------------------------------------------

    final AgentVerdict agent = await AgentEngine.evaluateThreat(
      target: target,
      vectorType: 'PHONE',
      heuristicRiskScore: heuristicRisk,
    );

    _trace(
      'Score del agente: ${agent.finalRiskScore}',
    );

    // ------------------------------------------------------------------------
    // FUSIÓN FINAL
    // ------------------------------------------------------------------------

    final double finalRisk = _resolveFinalRiskScore(
      heuristicRisk: heuristicRisk,
      learningRisk: learningRisk,
      agentRisk: agent.finalRiskScore,
    );

    final String finalRiskLevel = _resolveRiskLevel(finalRisk);

    _trace(
      'Score final de llamada: $finalRisk',
    );

    _trace(
      'Nivel final de llamada: $finalRiskLevel',
    );

    // ------------------------------------------------------------------------
    // RESULTADO NORMALIZADO
    // ------------------------------------------------------------------------

    final Map<String, dynamic> result = <String, dynamic>{
      ...heuristic,
      'phone': target,
      'phoneNumber': target,
      'target': target,
      'vector': 'PHONE',
      'heuristicRiskScore': heuristicRisk,
      'learningRiskScore': learningRisk,
      'agentRiskScore': agent.finalRiskScore,
      'score': finalRisk,
      'riskScore': finalRisk,
      'riskLevel': finalRiskLevel,
      'verdict': finalRiskLevel,
      'agentStatus': agent.statusText,
      'agentReasoning': agent.reasoning,
      'requiresExternalLookup': agent.requiresExternalLookup,
      'actionRecommendation': agent.actionRecommendation,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // ------------------------------------------------------------------------
    // TELEMETRÍA
    // ------------------------------------------------------------------------

    await _telemetryService.incrementCallsChecked();

    await _telemetryService.registerEvent(
      type: 'CALL_SCAN',
      message: 'Análisis de llamada ejecutado',
      metadata: result,
    );

    await _telemetryService.addForensicLog(
      event: 'CALL_SECURITY',
      severity: _safeString(
        result['verdict'],
      ),
      details: agent.reasoning,
    );

    return result;
  }

  // ==========================================================================
  // ESTADÍSTICAS
  // ==========================================================================

  Map<String, dynamic> get statistics => _telemetryService.statistics;

  List<Map<String, dynamic>> get forensicLogs => _telemetryService.forensicLogs;

  List<Map<String, dynamic>> get masterBitacora =>
      _telemetryService.masterBitacora;

  // ==========================================================================
  // EVENTO DE SEGURIDAD
  // ==========================================================================

  Future<void> saveSecurityEvent(
    Map<String, dynamic> event,
  ) {
    return _telemetryService.registerEvent(
      type: 'SECURITY_EVENT',
      message: 'Evento de seguridad registrado',
      metadata: event,
    );
  }
}
