import 'database_service.dart';
import '../core/phone_threat_intelligence.dart';

class DatabaseRepository {
  DatabaseRepository._internal();

  static final DatabaseRepository instance =
      DatabaseRepository._internal();

  factory DatabaseRepository() {
    return instance;
  }

  final DatabaseService _database =
      DatabaseService.instance;

  // =====================================================================================
  // INTELIGENCIA DE AMENAZAS TELEFÓNICAS
  // =====================================================================================

  Future<int> saveThreatIntelligence(
    PhoneThreatIntelligence threat,
  ) async {
    return _database.insertCallHistory(
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

  Future<List<PhoneThreatIntelligence>> getRecentThreats() async {
    final List<Map<String, dynamic>> rawLogs =
        await _database.getCallHistory();

    return rawLogs.map(
      (Map<String, dynamic> row) {
        final String reasonsString =
            row['details']?.toString() ?? '';

        final double riskScore =
            _readDouble(row['risk_score']);

        final double ipqsScore =
            _readDouble(row['ipqs_score']);

        final int timestamp =
            _readInt(row['timestamp']);

        return PhoneThreatIntelligence(
          phoneNumber:
              row['phone_number']?.toString() ?? '',

          riskScore: riskScore,

          ipqsScore: ipqsScore,

          verdict:
              row['verdict']?.toString() ??
              'SIN_AMENAZAS',

          statusLabel:
              row['category']?.toString() ??
              'SIN AMENAZAS DETECTADAS',

          confidence:
              row['confidence']?.toString() ??
              'MEDIA',

          isVoip: false,

          recentAbuse:
              riskScore >= 80.0,

          carrier:
              row['source']?.toString() ??
              'Desconocido',

          reasons:
              reasonsString.isNotEmpty
                  ? reasonsString
                      .split(' | ')
                      .where(
                        (String value) =>
                            value.trim().isNotEmpty,
                      )
                      .map(
                        (String value) =>
                            value.trim(),
                      )
                      .toList()
                  : <String>[],

          timestamp:
              timestamp > 0
                  ? DateTime.fromMillisecondsSinceEpoch(
                      timestamp,
                    )
                  : DateTime.now(),
        );
      },
    ).toList();
  }

  // =====================================================================================
  // CACHÉ IPQS
  // =====================================================================================

  Future<int> saveIpqsCache(
    Map<String, dynamic> data,
  ) {
    return _database.saveIpqsCache(data);
  }

  Future<Map<String, dynamic>?> getIpqsCache(
    String phoneNumber,
  ) {
    return _database.getIpqsCache(phoneNumber);
  }

  // =====================================================================================
  // LOGS FORENSES
  // =====================================================================================

  Future<int> insertForensicLog(
    Map<String, dynamic> logEntry,
  ) {
    return _database.insertForensicLog(logEntry);
  }

  Future<List<Map<String, dynamic>>> getForensicLogs() {
    return _database.getForensicLogs();
  }

  // =====================================================================================
  // HISTORIAL GENERAL
  // =====================================================================================

  Future<int> insertScanLog(
    Map<String, dynamic> log,
  ) {
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
  // LIMPIEZA GENERAL
  // =====================================================================================

  Future<int> clearAllLogs() {
    return _database.clearAllLogs();
  }

  Future<void> close() {
    return _database.close();
  }

  // =====================================================================================
  // CONVERSIONES
  // =====================================================================================

  double _readDouble(
    dynamic value,
  ) {
    if (value is num) {
      final double result = value.toDouble();

      if (result.isFinite) {
        return result.clamp(
          0.0,
          100.0,
        );
      }

      return 0.0;
    }

    if (value is String) {
      final double? result =
          double.tryParse(value);

      if (result != null && result.isFinite) {
        return result.clamp(
          0.0,
          100.0,
        );
      }
    }

    return 0.0;
  }

  int _readInt(
    dynamic value,
  ) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      final int result = value.toInt();
      return result < 0 ? 0 : result;
    }

    if (value is String) {
      final int? result =
          int.tryParse(value);

      if (result != null) {
        return result < 0 ? 0 : result;
      }
    }

    return 0;
  }
}
