// ====================================================================================================
// ARCHIVO: lib/services/security/security_coordinator.dart
// COORDINADOR CENTRAL DE SEGURIDAD
// JOSH SECURITY v6.0
// ====================================================================================================

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
  // ANÁLISIS DE URL / PHISHING
  // ================================================================================================

  Future<Map<String, dynamic>> scanUrl(String url) async {
    final result = _phishingEngine.analyze(url);

    await _telemetryService.incrementLinksChecked();

    await _telemetryService.registerEvent(
      type: "URL_SCAN",
      message: "Análisis de URL ejecutado",
      metadata: {
        "url": url,
        "result": result,
      },
    );

    await _telemetryService.addForensicLog(
      event: "PHISHING_SCAN",
      severity: result["verdict"] ?? "UNKNOWN",
      details: result["reason"] ?? "",
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
    final result = _callSecurityEngine.analyze(
      phoneNumber: phoneNumber,
      contactName: contactName,
      callText: text,
    );

    await _telemetryService.incrementCallsChecked();

    await _telemetryService.registerEvent(
      type: "CALL_SCAN",
      message: "Análisis de llamada ejecutado",
      metadata: result,
    );

    await _telemetryService.addForensicLog(
      event: "CALL_SECURITY",
      severity: result["verdict"] ?? "UNKNOWN",
      details: (result["reasons"] ?? []).toString(),
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