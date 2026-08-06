// ====================================================================================================
// ARCHIVO: lib/services/security/security_repository.dart
// REPOSITORIO CENTRAL DE PERSISTENCIA
// JOSH SECURITY v6.0
// ====================================================================================================

import 'package:josh_security/services/security/database_service.dart';

class SecurityRepository {
  SecurityRepository._();

  static final SecurityRepository instance = SecurityRepository._();

  final DatabaseService _database = DatabaseService.instance;

  // ============================================================================================
  // HISTORIAL GENERAL
  // ============================================================================================

  Future<void> saveScan(Map<String, dynamic> log) async {
    await _database.insertScanLog({
      "id": log["id"],
      "timestamp": log["timestamp"],
      "target": log["target"],
      "score": log["score"],
      "verdict": log["verdict"],
      "vector": log["vector"],
    });
  }

  Future<List<Map<String, dynamic>>> loadHistory() async {
    return await _database.getScanHistory();
  }

  Future<void> clearHistory() async {
    await _database.clearScanHistory();
  }

  // ============================================================================================
  // HISTORIAL TELEFÓNICO
  // ============================================================================================

  Future<void> saveCall({
    required String phone,
    required double score,
    required String verdict,
    required String category,
    required String details,
    required String source,
    required int timestamp,
  }) async {
    await _database.insertCallHistory(
      phoneNumber: phone,
      riskScore: score,
      verdict: verdict,
      category: category,
      details: details,
      source: source,
      timestamp: timestamp,
    );
  }

  Future<List<Map<String, dynamic>>> loadCalls() async {
    return await _database.getCallHistory();
  }

  Future<void> clearCalls() async {
    await _database.clearCallHistory();
  }

  // ============================================================================================
  // LOGS FORENSES
  // ============================================================================================

  Future<void> saveForensic(Map<String, dynamic> log) async {
    await _database.insertForensicLog(log);
  }

  Future<List<Map<String, dynamic>>> loadForensicLogs() async {
    return await _database.getForensicLogs();
  }

  // ============================================================================================
  // LIMPIEZA TOTAL
  // ============================================================================================

  Future<void> clearEverything() async {
    await _database.clearAllLogs();
  }

  Future<void> close() async {
    await _database.close();
  }
}