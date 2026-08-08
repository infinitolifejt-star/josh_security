// ====================================================================================================
// ARCHIVO: lib/services/security/security_coordinator.dart
// COORDINADOR CENTRAL DE SEGURIDAD CON INTEGRACIÓN AGÉNTICA
// JOSH SECURITY v6.0
// ====================================================================================================

import 'call_security_engine.dart';
import 'phishing_engine.dart';
import 'telemetry_service.dart';
import 'agent_engine.dart';

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
  // ANÁLISIS DE URL / PHISHING CON EVALUACIÓN AGÉNTICA
  // ================================================================================================

  Future<Map<String, dynamic>> scanUrl(String url) async {
    final heuristicResult = _phishingEngine.analyze(url);
    
    // Extraer puntuación de riesgo heurístico probando las claves habituales ('score', 'agentRiskScore', 'riskScore')
    double heuristicRisk = (heuristicResult["score"] ?? 
                            heuristicResult["agentRiskScore"] ?? 
                            heuristicResult["riskScore"] ?? 0.0).toDouble();

    // Deliberación agéntica con memoria contextual
    final AgentVerdict agentVerdict = await AgentEngine.evaluateThreat(
      target: url,
      vectorType: 'PHISHING',
      heuristicRiskScore: heuristicRisk,
    );

    // Mapeo unificado con decisión del agente
    final Map<String, dynamic> result = {
      ...heuristicResult,
      "target": url,
      "vector": "PHISHING",
      "score": agentVerdict.finalRiskScore > 0 ? agentVerdict.finalRiskScore : heuristicRisk,
      "verdict": agentVerdict.statusText,
      "agentRiskScore": agentVerdict.finalRiskScore,
      "agentReasoning": agentVerdict.reasoning,
      "requiresExternalLookup": agentVerdict.requiresExternalLookup,
      "actionRecommendation": agentVerdict.actionRecommendation,
      "timestamp": DateTime.now().toString().split('.')[0],
    };

    await _telemetryService.incrementLinksChecked();

    await _telemetryService.registerEvent(
      type: "URL_SCAN",
      message: "Análisis de URL agéntico ejecutado",
      metadata: {
        "url": url,
        "result": result,
      },
    );

    await _telemetryService.addForensicLog(
      event: "PHISHING_SCAN",
      severity: result["verdict"] ?? "UNKNOWN",
      details: agentVerdict.reasoning,
    );

    return result;
  }

  // ================================================================================================
  // ANÁLISIS DE LLAMADAS CON EVALUACIÓN AGÉNTICA
  // ================================================================================================

  Future<Map<String, dynamic>> scanCall({
    required String phoneNumber,
    String? contactName,
    String? text,
  }) async {
    final heuristicResult = _callSecurityEngine.analyze(
      phoneNumber: phoneNumber,
      contactName: contactName,
      callText: text,
    );

    // Extraer puntuación de riesgo heurístico probando las claves habituales ('score', 'agentRiskScore', 'riskScore')
    double heuristicRisk = (heuristicResult["score"] ?? 
                            heuristicResult["agentRiskScore"] ?? 
                            heuristicResult["riskScore"] ?? 0.0).toDouble();

    // Deliberación agéntica con memoria contextual
    final AgentVerdict agentVerdict = await AgentEngine.evaluateThreat(
      target: phoneNumber,
      vectorType: 'PHONE',
      heuristicRiskScore: heuristicRisk,
    );

    // Mapeo unificado con decisión del agente
    final Map<String, dynamic> result = {
      ...heuristicResult,
      "target": phoneNumber,
      "vector": "PHONE",
      "score": agentVerdict.finalRiskScore > 0 ? agentVerdict.finalRiskScore : heuristicRisk,
      "verdict": agentVerdict.statusText,
      "agentRiskScore": agentVerdict.finalRiskScore,
      "agentReasoning": agentVerdict.reasoning,
      "requiresExternalLookup": agentVerdict.requiresExternalLookup,
      "actionRecommendation": agentVerdict.actionRecommendation,
      "timestamp": DateTime.now().toString().split('.')[0],
    };

    await _telemetryService.incrementCallsChecked();

    await _telemetryService.registerEvent(
      type: "CALL_SCAN",
      message: "Análisis de llamada agéntico ejecutado",
      metadata: result,
    );

    await _telemetryService.addForensicLog(
      event: "CALL_SECURITY",
      severity: result["verdict"] ?? "UNKNOWN",
      details: agentVerdict.reasoning,
    );

    return result;
  }

  // ================================================================================================
  // ESTADÍSTICAS Y LOGS
  // ================================================================================================

  Map<String, dynamic> get statistics => _telemetryService.statistics;

  List<Map<String, dynamic>> get forensicLogs => _telemetryService.forensicLogs;

  List<Map<String, dynamic>> get masterBitacora => _telemetryService.masterBitacora;

  // ================================================================================================
  // REGISTRO DE EVENTOS
  // ================================================================================================

  Future<void> saveSecurityEvent(Map<String, dynamic> event) async {
    await _telemetryService.registerEvent(
      type: "SECURITY_EVENT",
      message: "Evento de seguridad registrado",
      metadata: event,
    );
  }
}