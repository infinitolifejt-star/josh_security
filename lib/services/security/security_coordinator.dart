// ====================================================================================================
// ARCHIVO: lib/services/security/security_coordinator.dart
// COORDINADOR CENTRAL DE SEGURIDAD CON INTEGRACIÓN AGÉNTICA
// JOSH SECURITY v6.0
// ====================================================================================================

import 'agent_engine.dart';
import 'call_security_engine.dart';
import 'phishing_engine.dart';
import 'telemetry_service.dart';

class SecurityCoordinator {
  final PhishingEngine _phishingEngine;
  final CallSecurityEngine _callSecurityEngine;
  final TelemetryService _telemetryService;

  SecurityCoordinator({
    required PhishingEngine phishingEngine,
    required CallSecurityEngine callSecurityEngine,
    required TelemetryService telemetryService,
  })  : _phishingEngine = phishingEngine,
        _callSecurityEngine = callSecurityEngine,
        _telemetryService = telemetryService;

  // ================================================================================================
  // INICIALIZACIÓN
  // ================================================================================================

  Future<void> initialize() async {
    await _telemetryService.initialize();
  }

  // ================================================================================================
  // UTILIDADES INTERNAS
  // ================================================================================================

  double _extractRiskScore(
    Map<String, dynamic> result,
  ) {
    final dynamic raw =
        result['score'] ??
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

  double _resolveFinalRiskScore({
    required double heuristicRisk,
    required double agentRisk,
  }) {
    if (agentRisk.isFinite &&
        agentRisk >= 0.0 &&
        agentRisk <= 100.0) {
      return agentRisk;
    }

    return heuristicRisk.clamp(0.0, 100.0);
  }

  String _safeString(
    dynamic value, {
    String fallback = 'UNKNOWN',
  }) {
    if (value == null) {
      return fallback;
    }

    final String result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  // ================================================================================================
  // ANÁLISIS DE URL / PHISHING
  // ================================================================================================

  Future<Map<String, dynamic>> scanUrl(
    String url,
  ) async {
    final String target = url.trim();

    final Map<String, dynamic> heuristicResult =
        Map<String, dynamic>.from(
      _phishingEngine.analyze(target),
    );

    final double heuristicRisk =
        _extractRiskScore(heuristicResult);

    final AgentVerdict agentVerdict =
        await AgentEngine.evaluateThreat(
      target: target,
      vectorType: 'PHISHING',
      heuristicRiskScore: heuristicRisk,
    );

    final double finalRiskScore =
        _resolveFinalRiskScore(
      heuristicRisk: heuristicRisk,
      agentRisk: agentVerdict.finalRiskScore,
    );

    final Map<String, dynamic> result =
        <String, dynamic>{
      ...heuristicResult,
      'target': target,
      'vector': 'PHISHING',
      'score': finalRiskScore,
      'heuristicRiskScore': heuristicRisk,
      'verdict': agentVerdict.statusText,
      'agentRiskScore': agentVerdict.finalRiskScore,
      'agentReasoning': agentVerdict.reasoning,
      'requiresExternalLookup':
          agentVerdict.requiresExternalLookup,
      'actionRecommendation':
          agentVerdict.actionRecommendation,
      'timestamp':
          DateTime.now().toIso8601String(),
    };

    await _telemetryService.incrementLinksChecked();

    await _telemetryService.registerEvent(
      type: 'URL_SCAN',
      message: 'Análisis de URL agéntico ejecutado',
      metadata: result,
    );

    await _telemetryService.addForensicLog(
      event: 'PHISHING_SCAN',
      severity: _safeString(
        result['verdict'],
      ),
      details: agentVerdict.reasoning,
    );

    return result;
  }

  // ================================================================================================
  // ANÁLISIS DE LLAMADAS
  // ================================================================================================

  Future<Map<String, dynamic>> scanCall({
    required String phoneNumber,
    String? contactName,
    String? text,
  }) async {
    final String target = phoneNumber.trim();

    final Map<String, dynamic> heuristicResult =
        Map<String, dynamic>.from(
      _callSecurityEngine.analyze(
        phoneNumber: target,
        contactName: contactName,
        callText: text,
      ),
    );

    final double heuristicRisk =
        _extractRiskScore(heuristicResult);

    final AgentVerdict agentVerdict =
        await AgentEngine.evaluateThreat(
      target: target,
      vectorType: 'PHONE',
      heuristicRiskScore: heuristicRisk,
    );

    final double finalRiskScore =
        _resolveFinalRiskScore(
      heuristicRisk: heuristicRisk,
      agentRisk: agentVerdict.finalRiskScore,
    );

    final Map<String, dynamic> result =
        <String, dynamic>{
      ...heuristicResult,

      'phone': target,
      'target': target,
      'vector': 'PHONE',

      // Puntuación original del motor heurístico.
      'heuristicRiskScore': heuristicRisk,

      // Puntuación definitiva después del agente.
      'score': finalRiskScore,
      'riskScore': finalRiskScore,
      'agentRiskScore': agentVerdict.finalRiskScore,

      'verdict': agentVerdict.statusText,
      'agentReasoning': agentVerdict.reasoning,

      'requiresExternalLookup':
          agentVerdict.requiresExternalLookup,

      'actionRecommendation':
          agentVerdict.actionRecommendation,

      'timestamp':
          DateTime.now().toIso8601String(),
    };

    await _telemetryService.incrementCallsChecked();

    await _telemetryService.registerEvent(
      type: 'CALL_SCAN',
      message: 'Análisis de llamada agéntico ejecutado',
      metadata: result,
    );

    await _telemetryService.addForensicLog(
      event: 'CALL_SECURITY',
      severity: _safeString(
        result['verdict'],
      ),
      details: agentVerdict.reasoning,
    );

    return result;
  }

  // ================================================================================================
  // ESTADÍSTICAS Y LOGS
  // ================================================================================================

  Map<String, dynamic> get statistics =>
      _telemetryService.statistics;

  List<Map<String, dynamic>> get forensicLogs =>
      _telemetryService.forensicLogs;

  List<Map<String, dynamic>> get masterBitacora =>
      _telemetryService.masterBitacora;

  // ================================================================================================
  // REGISTRO DE EVENTOS
  // ================================================================================================

  Future<void> saveSecurityEvent(
    Map<String, dynamic> event,
  ) async {
    await _telemetryService.registerEvent(
      type: 'SECURITY_EVENT',
      message: 'Evento de seguridad registrado',
      metadata: event,
    );
  }
}
