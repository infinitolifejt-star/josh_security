import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'agent_engine.dart';
import 'call_security_engine.dart';
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

  void _trace(String message) {
    debugPrint('[JOSH_TRACE] [SecurityCoordinator] $message');
    developer.log(message, name: 'josh.security.coordinator');
  }

  Future<void> initialize() async {
    _trace('Inicializando Coordinador Central de Seguridad...');
    await _telemetryService.initialize();
  }

  double _extractRiskScore(Map<String, dynamic> result) {
    final dynamic raw = result['score'] ??
        result['risk_score'] ??
        result['riskScore'] ??
        result['agentRiskScore'];
    if (raw is num) return raw.toDouble().clamp(0.0, 100.0);
    if (raw is String) {
      final double? parsed = double.tryParse(raw);
      if (parsed != null) return parsed.clamp(0.0, 100.0);
    }
    return 0.0;
  }

  double _resolveFinalRiskScore({
    required double heuristicRisk,
    required double agentRisk,
  }) {
    if (agentRisk.isFinite && agentRisk >= 0.0 && agentRisk <= 100.0) {
      return agentRisk;
    }
    return heuristicRisk.clamp(0.0, 100.0);
  }

  String _safeString(dynamic value) {
    if (value == null) return 'UNKNOWN';
    final String text = value.toString().trim();
    return text.isEmpty ? 'UNKNOWN' : text;
  }

  Future<Map<String, dynamic>> scanUrl(String url) async {
    final String target = url.trim();
    _trace('Iniciando escaneo de URL: $target');

    final Map<String, dynamic> heuristic = Map<String, dynamic>.from(
      _phishingEngine.analyze(target),
    );
    final double heuristicRisk = _extractRiskScore(heuristic);

    final AgentVerdict agent = await AgentEngine.evaluateThreat(
      target: target,
      vectorType: 'PHISHING',
      heuristicRiskScore: heuristicRisk,
    );

    final double finalRisk = _resolveFinalRiskScore(
      heuristicRisk: heuristicRisk,
      agentRisk: agent.finalRiskScore,
    );

    final Map<String, dynamic> result = <String, dynamic>{
      ...heuristic,
      'target': target,
      'vector': 'PHISHING',
      'score': finalRisk,
      'riskScore': finalRisk,
      'heuristicRiskScore': heuristicRisk,
      'verdict': agent.statusText,
      'agentRiskScore': agent.finalRiskScore,
      'agentReasoning': agent.reasoning,
      'requiresExternalLookup': agent.requiresExternalLookup,
      'actionRecommendation': agent.actionRecommendation,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _telemetryService.incrementLinksChecked();
    await _telemetryService.registerEvent(
      type: 'URL_SCAN',
      message: 'Análisis de URL agéntico ejecutado',
      metadata: result,
    );
    await _telemetryService.addForensicLog(
      event: 'PHISHING_SCAN',
      severity: _safeString(result['verdict']),
      details: agent.reasoning,
    );
    return result;
  }

  Future<Map<String, dynamic>> scanCall({
    required String phoneNumber,
    String? contactName,
    String? text,
  }) async {
    final String target = phoneNumber.trim();
    _trace('Procesando llamada entrante -> Número: $target | Contacto: $contactName');

    final Map<String, dynamic> heuristic = Map<String, dynamic>.from(
      _callSecurityEngine.analyze(
        phoneNumber: target,
        contactName: contactName,
        callText: text,
      ),
    );
    final double heuristicRisk = _extractRiskScore(heuristic);
    _trace('Score Heurístico: $heuristicRisk');

    final AgentVerdict agent = await AgentEngine.evaluateThreat(
      target: target,
      vectorType: 'PHONE',
      heuristicRiskScore: heuristicRisk,
    );

    final double finalRisk = _resolveFinalRiskScore(
      heuristicRisk: heuristicRisk,
      agentRisk: agent.finalRiskScore,
    );

    final Map<String, dynamic> result = <String, dynamic>{
      ...heuristic,
      'phone': target,
      'target': target,
      'vector': 'PHONE',
      'heuristicRiskScore': heuristicRisk,
      'score': finalRisk,
      'riskScore': finalRisk,
      'agentRiskScore': agent.finalRiskScore,
      'verdict': agent.statusText,
      'agentReasoning': agent.reasoning,
      'requiresExternalLookup': agent.requiresExternalLookup,
      'actionRecommendation': agent.actionRecommendation,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _telemetryService.incrementCallsChecked();
    await _telemetryService.registerEvent(
      type: 'CALL_SCAN',
      message: 'Análisis de llamada agéntico ejecutado',
      metadata: result,
    );
    await _telemetryService.addForensicLog(
      event: 'CALL_SECURITY',
      severity: _safeString(result['verdict']),
      details: agent.reasoning,
    );

    return result;
  }

  Map<String, dynamic> get statistics => _telemetryService.statistics;
  List<Map<String, dynamic>> get forensicLogs => _telemetryService.forensicLogs;
  List<Map<String, dynamic>> get masterBitacora => _telemetryService.masterBitacora;

  Future<void> saveSecurityEvent(Map<String, dynamic> event) {
    return _telemetryService.registerEvent(
      type: 'SECURITY_EVENT',
      message: 'Evento de seguridad registrado',
      metadata: event,
    );
  }
}
