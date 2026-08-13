// ====================================================================================================
// ARCHIVO: lib/services/security/database_repository.dart
// CAPA DE ABSTRACCIÓN PARA PERSISTENCIA LOCAL - JOSH SECURITY v6.0
// ====================================================================================================

import 'database_service.dart';
import '../core/phone_threat_intelligence.dart';

class DatabaseRepository {
  DatabaseRepository._internal();

  static final DatabaseRepository instance = DatabaseRepository._internal();

  final DatabaseService _database = DatabaseService.instance;

  // =====================================================================================
  // INTELIGENCIA DE AMENAZAS TELEFÓNICAS (PHONE THREAT INTELLIGENCE)
  // =====================================================================================

  /// Persiste una evaluación completa de inteligencia telefónica en la base de datos local
  Future<int> saveThreatIntelligence(PhoneThreatIntelligence threat) async {
    return await _database.insertCallHistory(
      phoneNumber: threat.phoneNumber,
      riskScore: threat.riskScore,
      ipqsScore: threat.ipqsScore,
      confidence: threat.confidence,
      verdict: threat.verdict,
      category: threat.statusLabel,
      details: threat.reasons.join(' | '),
      source: threat.carrier,
      timestamp: threat.timestamp.millisecondsSinceEpoch,
    );
  }

  /// Recupera el historial de llamadas mapeado a modelos PhoneThreatIntelligence
  Future<List<PhoneThreatIntelligence>> getRecentThreats() async {
    final rawLogs = await _database.getCallHistory();
    return rawLogs.map((map) {
      final reasonsString = map['details'] as String? ?? '';
      return PhoneThreatIntelligence(
        phoneNumber: map['phoneNumber'] as String? ?? '',
        riskScore: (map['riskScore'] as num?)?.toDouble() ?? 0.0,
        ipqsScore: (map['ipqsScore'] as num?)?.toDouble() ?? 0.0,
        verdict: map['verdict'] as String? ?? 'SIN_AMENAZAS',
        statusLabel: map['category'] as String? ?? '🟢 SIN AMENAZAS DETECTADAS',
        confidence: map['confidence'] as String? ?? 'MEDIA',
        isVoip: false,
        recentAbuse: (map['riskScore'] as num? ?? 0) >= 80,
        carrier: map['source'] as String? ?? 'Desconocido',
        reasons: reasonsString.isNotEmpty ? reasonsString.split(' | ') : [],
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }).toList();
  }

  // =====================================================================================
  // CACHÉ IPQS
  // =====================================================================================

  Future<int> saveIpqsCache(Map<String, dynamic> data) {
    return _database.saveIpqsCache(data);
  }

  Future<Map<String, dynamic>?> getIpqsCache(String phoneNumber) {
    return _database.getIpqsCache(phoneNumber);
  }

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
  // HISTORIAL DE LLAMADAS (MÉTODOS RAW)
  // =====================================================================================

  Future<int> insertCallHistory({
    required String phoneNumber,
    required double riskScore,
    double? ipqsScore,
    String? confidence,
    required String verdict,
    required String category,
    required String details,
    required String source,
    required int timestamp,
  }) {
    return _database.insertCallHistory(
      phoneNumber: phoneNumber,
      riskScore: riskScore,
      ipqsScore: ipqsScore,
      confidence: confidence,
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
