// ====================================================================================================
// ARCHIVO: lib/services/security/database_service.dart
// MOTOR DE PERSISTENCIA LOCAL - JOSH SECURITY v6.0
// Soporte de Caché IPQS, Historial Unificado y Migración v4
// ====================================================================================================

import 'dart:developer' as developer;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService instance =
      DatabaseService._internal();

  factory DatabaseService() => instance;

  static const String _databaseName =
      'josh_security_centinela.db';

  static const int _databaseVersion = 4;

  Database? _database;
  Future<Database>? _initializationFuture;

  // ================================================================================================
  // DATABASE
  // ================================================================================================

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    return _initializationFuture ??= _initializeDatabase();
  }

  Future<Database> _initializeDatabase() async {
    try {
      final String dbPath = await getDatabasesPath();

      final String path = join(
        dbPath,
        _databaseName,
      );

      final Database db = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      _database = db;

      return db;
    } catch (e, stackTrace) {
      developer.log(
        'Error inicializando base de datos.',
        name: 'DatabaseService',
        error: e,
        stackTrace: stackTrace,
      );

      _initializationFuture = null;
      rethrow;
    }
  }

  // ================================================================================================
  // CREACIÓN
  // ================================================================================================

  Future<void> _onCreate(
    Database db,
    int version,
  ) async {
    await db.transaction(
      (Transaction txn) async {
        // ------------------------------------------------------------------------------------------
        // REGISTROS FORENSES
        // ------------------------------------------------------------------------------------------

        await txn.execute('''
          CREATE TABLE forensic_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            service TEXT NOT NULL,
            activity TEXT NOT NULL,
            verdict TEXT NOT NULL,
            matched_rule TEXT NOT NULL,
            extra_data TEXT
          )
        ''');

        // ------------------------------------------------------------------------------------------
        // HISTORIAL GENERAL DEL MOTOR
        // ------------------------------------------------------------------------------------------

        await txn.execute('''
          CREATE TABLE scan_history(
            id TEXT PRIMARY KEY,
            timestamp TEXT,
            target TEXT,
            score REAL,
            verdict TEXT,
            vector TEXT
          )
        ''');

        // ------------------------------------------------------------------------------------------
        // HISTORIAL DE LLAMADAS
        // ------------------------------------------------------------------------------------------

        await txn.execute('''
          CREATE TABLE call_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_number TEXT NOT NULL,
            risk_score REAL,
            ipqs_score REAL,
            confidence TEXT,
            verdict TEXT,
            category TEXT,
            details TEXT,
            source TEXT,
            timestamp INTEGER
          )
        ''');

        // ------------------------------------------------------------------------------------------
        // CACHÉ IPQS
        // ------------------------------------------------------------------------------------------

        await txn.execute('''
          CREATE TABLE ipqs_cache(
            phone_number TEXT PRIMARY KEY,
            fraud_score REAL,
            is_voip INTEGER,
            recent_abuse INTEGER,
            carrier TEXT,
            raw_response TEXT,
            cached_at INTEGER
          )
        ''');

        // ------------------------------------------------------------------------------------------
        // WHITELIST
        // ------------------------------------------------------------------------------------------

        await txn.execute('''
          CREATE TABLE whitelist_domains(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            domain TEXT UNIQUE,
            category TEXT
          )
        ''');

        // ------------------------------------------------------------------------------------------
        // ÍNDICES
        // ------------------------------------------------------------------------------------------

        await txn.execute(
          'CREATE INDEX idx_scan_time '
          'ON scan_history(timestamp);',
        );

        await txn.execute(
          'CREATE INDEX idx_call_time '
          'ON call_history(timestamp);',
        );

        await txn.execute(
          'CREATE INDEX idx_ipqs_phone '
          'ON ipqs_cache(phone_number);',
        );
      },
    );
  }

  // ================================================================================================
  // MIGRACIONES
  // ================================================================================================

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS whitelist_domains(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          domain TEXT UNIQUE,
          category TEXT
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS scan_history(
          id TEXT PRIMARY KEY,
          timestamp TEXT,
          target TEXT,
          score REAL,
          verdict TEXT,
          vector TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS call_history(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          phone_number TEXT NOT NULL,
          risk_score REAL,
          verdict TEXT,
          category TEXT,
          details TEXT,
          source TEXT,
          timestamp INTEGER
        )
      ''');
    }

    if (oldVersion < 4) {
      await _ensureColumn(
        db,
        table: 'call_history',
        column: 'ipqs_score',
        definition: 'REAL',
      );

      await _ensureColumn(
        db,
        table: 'call_history',
        column: 'confidence',
        definition: 'TEXT',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ipqs_cache(
          phone_number TEXT PRIMARY KEY,
          fraud_score REAL,
          is_voip INTEGER,
          recent_abuse INTEGER,
          carrier TEXT,
          raw_response TEXT,
          cached_at INTEGER
        )
      ''');

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ipqs_phone '
        'ON ipqs_cache(phone_number);',
      );
    }
  }

  Future<void> _ensureColumn(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final List<Map<String, dynamic>> columns =
        await db.rawQuery(
      'PRAGMA table_info($table)',
    );

    final bool exists = columns.any(
      (Map<String, dynamic> item) =>
          item['name']?.toString() == column,
    );

    if (exists) {
      return;
    }

    await db.execute(
      'ALTER TABLE $table '
      'ADD COLUMN $column $definition',
    );
  }

  // ================================================================================================
  // IPQS CACHE
  // ================================================================================================

  Future<int> saveIpqsCache(
    Map<String, dynamic> data,
  ) async {
    try {
      final Database db = await database;

      final Map<String, dynamic> normalized =
          _normalizeIpqsData(data);

      return await db.insert(
        'ipqs_cache',
        normalized,
        conflictAlgorithm:
            ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      _logError(
        'saveIpqsCache',
        e,
        stackTrace,
      );

      return -1;
    }
  }

  Future<Map<String, dynamic>?> getIpqsCache(
    String phoneNumber,
  ) async {
    try {
      final Database db = await database;

      final String phone =
          phoneNumber.trim();

      if (phone.isEmpty) {
        return null;
      }

      final List<Map<String, dynamic>> results =
          await db.query(
        'ipqs_cache',
        where: 'phone_number = ?',
        whereArgs: <dynamic>[phone],
        limit: 1,
      );

      if (results.isEmpty) {
        return null;
      }

      return Map<String, dynamic>.from(
        results.first,
      );
    } catch (e, stackTrace) {
      _logError(
        'getIpqsCache',
        e,
        stackTrace,
      );

      return null;
    }
  }

  Map<String, dynamic> _normalizeIpqsData(
    Map<String, dynamic> data,
  ) {
    return <String, dynamic>{
      'phone_number':
          data['phone_number'] ??
              data['phoneNumber'] ??
              '',
      'fraud_score':
          _readDouble(
            data['fraud_score'] ??
                data['fraudScore'],
          ),
      'is_voip':
          _readBoolInt(
            data['is_voip'] ??
                data['isVoip'],
          ),
      'recent_abuse':
          _readBoolInt(
            data['recent_abuse'] ??
                data['recentAbuse'],
          ),
      'carrier':
          data['carrier']?.toString(),
      'raw_response':
          data['raw_response']?.toString() ??
              data['rawResponse']?.toString(),
      'cached_at':
          _readInt(
            data['cached_at'] ??
                data['cachedAt'],
          ),
    };
  }

  // ================================================================================================
  // FORENSIC LOGS
  // ================================================================================================

  Future<int> insertForensicLog(
    Map<String, dynamic> logEntry,
  ) async {
    try {
      final Database db = await database;

      return await db.insert(
        'forensic_logs',
        <String, dynamic>{
          'timestamp':
              logEntry['timestamp']?.toString() ??
                  '',
          'service':
              logEntry['service']?.toString() ??
                  'JOSH',
          'activity':
              logEntry['activity']?.toString() ??
                  '',
          'verdict':
              logEntry['verdict']?.toString() ??
                  '',
          'matched_rule':
              logEntry['matched_rule']?.toString() ??
                  '',
          'extra_data':
              logEntry['extra_data']?.toString(),
        },
        conflictAlgorithm:
            ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      _logError(
        'insertForensicLog',
        e,
        stackTrace,
      );

      return -1;
    }
  }

  // ================================================================================================
  // HISTORIAL GENERAL
  // ================================================================================================

  Future<int> insertScanLog(
    Map<String, dynamic> log,
  ) async {
    try {
      final Database db = await database;

      final String id =
          log['id']?.toString() ??
              '${DateTime.now().microsecondsSinceEpoch}';

      return await db.insert(
        'scan_history',
        <String, dynamic>{
          'id': id,
          'timestamp':
              log['timestamp']?.toString(),
          'target':
              log['target']?.toString(),
          'score':
              _readDouble(
                log['score'] ??
                    log['risk_score'] ??
                    log['riskScore'],
              ),
          'verdict':
              log['verdict']?.toString(),
          'vector':
              log['vector']?.toString(),
        },
        conflictAlgorithm:
            ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      _logError(
        'insertScanLog',
        e,
        stackTrace,
      );

      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getScanHistory() async {
    final Database db = await database;

    final List<Map<String, dynamic>> rows =
        await db.query(
      'scan_history',
      orderBy: 'timestamp DESC',
    );

    return rows
        .map(
          (Map<String, dynamic> row) =>
              Map<String, dynamic>.from(row),
        )
        .toList();
  }

  // ================================================================================================
  // HISTORIAL DE LLAMADAS
  // ================================================================================================

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
  }) async {
    try {
      final Database db = await database;

      final String phone =
          phoneNumber.trim();

      if (phone.isEmpty) {
        return -1;
      }

      return await db.insert(
        'call_history',
        <String, dynamic>{
          'phone_number': phone,
          'risk_score':
              _clampScore(riskScore),
          'ipqs_score':
              ipqsScore == null
                  ? null
                  : _clampScore(ipqsScore),
          'confidence':
              confidence?.trim().isNotEmpty == true
                  ? confidence!.trim()
                  : 'MEDIA',
          'verdict':
              verdict.trim(),
          'category':
              category.trim(),
          'details':
              details.trim(),
          'source':
              source.trim(),
          'timestamp':
              timestamp > 0
                  ? timestamp
                  : DateTime.now()
                      .millisecondsSinceEpoch,
        },
        conflictAlgorithm:
            ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      _logError(
        'insertCallHistory',
        e,
        stackTrace,
      );

      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getCallHistory() async {
    final Database db = await database;

    final List<Map<String, dynamic>> rows =
        await db.query(
      'call_history',
      orderBy: 'timestamp DESC',
    );

    return rows
        .map(
          (Map<String, dynamic> row) =>
              Map<String, dynamic>.from(row),
        )
        .toList();
  }

  // ================================================================================================
  // LIMPIEZA
  // ================================================================================================

  Future<void> clearCallHistory() async {
    final Database db = await database;

    await db.delete(
      'call_history',
    );
  }

  Future<void> clearScanHistory() async {
    final Database db = await database;

    await db.delete(
      'scan_history',
    );
  }

  Future<int> clearAllLogs() async {
    final Database db = await database;

    return await db.transaction(
      (Transaction txn) async {
        await txn.delete('scan_history');
        await txn.delete('call_history');
        await txn.delete('ipqs_cache');

        return txn.delete(
          'forensic_logs',
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> getForensicLogs() async {
    final Database db = await database;

    final List<Map<String, dynamic>> rows =
        await db.query(
      'forensic_logs',
      orderBy: 'timestamp DESC',
    );

    return rows
        .map(
          (Map<String, dynamic> row) =>
              Map<String, dynamic>.from(row),
        )
        .toList();
  }

  // ================================================================================================
  // CIERRE
  // ================================================================================================

  Future<void> close() async {
    final Database? db = _database;

    if (db == null) {
      _initializationFuture = null;
      return;
    }

    try {
      if (db.isOpen) {
        await db.close();
      }
    } finally {
      _database = null;
      _initializationFuture = null;
    }
  }

  // ================================================================================================
  // CONVERSIONES SEGURAS
  // ================================================================================================

  double _readDouble(dynamic value) {
    double result = 0.0;

    if (value is num) {
      result = value.toDouble();
    } else if (value is String) {
      result = double.tryParse(value) ?? 0.0;
    }

    if (!result.isFinite) {
      return 0.0;
    }

    return _clampScore(result);
  }

  double _clampScore(double value) {
    if (!value.isFinite) {
      return 0.0;
    }

    return value.clamp(0.0, 100.0).toDouble();
  }

  int _readInt(dynamic value) {
    int result = 0;

    if (value is int) {
      result = value;
    } else if (value is num) {
      result = value.toInt();
    } else if (value is String) {
      result = int.tryParse(value) ?? 0;
    }

    return result < 0 ? 0 : result;
  }

  int _readBoolInt(dynamic value) {
    if (value is bool) {
      return value ? 1 : 0;
    }

    if (value is num) {
      return value != 0 ? 1 : 0;
    }

    if (value is String) {
      final String normalized =
          value.trim().toLowerCase();

      if (normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes') {
        return 1;
      }
    }

    return 0;
  }

  // ================================================================================================
  // LOGGING
  // ================================================================================================

  void _logError(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      '$operation Error',
      name: 'DatabaseService',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
