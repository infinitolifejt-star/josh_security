// ====================================================================================================
// ARCHIVO: lib/services/security/database_repository.dart
// CAPA DE ABSTRACCIÓN PARA PERSISTENCIA LOCAL
// JOSH SECURITY v6.0
// ====================================================================================================

import 'database_service.dart';

class DatabaseRepository {
  DatabaseRepository._internal();

  static final DatabaseRepository instance = DatabaseRepository._internal();

  final DatabaseService _database = DatabaseService.instance;

  // =====================================================================================
  // LOGS FORENSES
  // =====================================================================================

  Future<int> insertForensicLog(Map<String, dynamic> logEntry) {
    return _database.insertForensicLog(logEntry);
  }

  Future<List<Map<String, dynamic>>> getForensicLogs() {
    return _database.getForensicLogs();
  }

  // =====================================================================================
  // HISTORIAL GENERAL
  // =====================================================================================

  Future<int> insertScanLog(Map<String, dynamic> log) {
    return _database.insertScanLog(log);
  }

  Future<List<Map<String, dynamic>>> getScanHistory() {
    return _database.getScanHistory();
  }

  Future<void> clearScanHistory() {
    return _database.clearScanHistory();
  }

  // =====================================================================================
  // HISTORIAL DE LLAMADAS
  // =====================================================================================

  Future<int> insertCallHistory({
    required String phoneNumber,
    required double riskScore,
    required String verdict,
    required String category,
    required String details,
    required String source,
    required int timestamp,
  }) {
    return _database.insertCallHistory(
      phoneNumber: phoneNumber,
      riskScore: riskScore,
      verdict: verdict,
      category: category,
      details: details,
      source: source,
      timestamp: timestamp,
    );
  }

  Future<List<Map<String, dynamic>>> getCallHistory() {
    return _database.getCallHistory();
  }

  Future<void> clearCallHistory() {
    return _database.clearCallHistory();
  }

  // =====================================================================================
  // LIMPIEZA GENERAL Y CIERRE
  // =====================================================================================

  Future<int> clearAllLogs() {
    return _database.clearAllLogs();
  }

  Future<void> close() {
    return _database.close();
  }
}