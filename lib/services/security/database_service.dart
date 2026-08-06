// ====================================================================================================
// ARCHIVO: lib/services/security/database_service.dart
// MOTOR DE PERSISTENCIA LOCAL - JOSH SECURITY v5.0
// Compatible con SecurityProvider, PhoneInterceptor y Centinela APK
// ====================================================================================================

import 'dart:developer' as developer;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService instance = DatabaseService._internal();

  factory DatabaseService() => instance;

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(
      await getDatabasesPath(),
      "josh_security_centinela.db",
    );

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {

    //----------------------------------------------------------
    // REGISTROS FORENSES
    //----------------------------------------------------------

    await db.execute('''
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

    //----------------------------------------------------------
    // HISTORIAL GENERAL DEL MOTOR
    //----------------------------------------------------------

    await db.execute('''
      CREATE TABLE scan_history(
        id TEXT PRIMARY KEY,
        timestamp TEXT,
        target TEXT,
        score REAL,
        verdict TEXT,
        vector TEXT
      )
    ''');

    //----------------------------------------------------------
    // HISTORIAL DE LLAMADAS
    //----------------------------------------------------------

    await db.execute('''
      CREATE TABLE call_history(
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

    //----------------------------------------------------------
    // WHITELIST
    //----------------------------------------------------------

    await db.execute('''
      CREATE TABLE whitelist_domains(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT UNIQUE,
        category TEXT
      )
    ''');

    //----------------------------------------------------------
    // ÍNDICES
    //----------------------------------------------------------

    await db.execute(
      'CREATE INDEX idx_scan_time ON scan_history(timestamp);',
    );

    await db.execute(
      'CREATE INDEX idx_call_time ON call_history(timestamp);',
    );
  }

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
        phone_number TEXT,
        risk_score REAL,
        verdict TEXT,
        category TEXT,
        details TEXT,
        source TEXT,
        timestamp INTEGER
      )
      ''');
    }
  } 
 // =====================================================================================
  // LOGS FORENSES
  // =====================================================================================

  Future<int> insertForensicLog(Map<String, dynamic> logEntry) async {
    try {
      final db = await database;

      return await db.insert(
        "forensic_logs",
        {
          "timestamp": logEntry["timestamp"] ?? "",
          "service": logEntry["service"] ?? "JOSH",
          "activity": logEntry["activity"] ?? "",
          "verdict": logEntry["verdict"] ?? "",
          "matched_rule": logEntry["matched_rule"] ?? "",
          "extra_data": logEntry["extra_data"]?.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      developer.log(
        "insertForensicLog",
        error: e,
        name: "DatabaseService",
      );
      return -1;
    }
  }

  // =====================================================================================
  // HISTORIAL GENERAL (COMPATIBLE CON SECURITY PROVIDER)
  // =====================================================================================

  Future<int> insertScanLog(Map<String, dynamic> log) async {
    try {
      final db = await database;

      return await db.insert(
        "scan_history",
        {
          "id": log["id"],
          "timestamp": log["timestamp"],
          "target": log["target"],
          "score": log["score"],
          "verdict": log["verdict"],
          "vector": log["vector"],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      developer.log(
        "insertScanLog",
        error: e,
        name: "DatabaseService",
      );
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getScanHistory() async {
    final db = await database;

    return await db.query(
      "scan_history",
      orderBy: "timestamp DESC",
    );
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
  }) async {
    try {
      final db = await database;

      return await db.insert(
        "call_history",
        {
          "phone_number": phoneNumber,
          "risk_score": riskScore,
          "verdict": verdict,
          "category": category,
          "details": details,
          "source": source,
          "timestamp": timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      developer.log(
        "insertCallHistory",
        error: e,
        name: "DatabaseService",
      );
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getCallHistory() async {
    final db = await database;

    return await db.query(
      "call_history",
      orderBy: "timestamp DESC",
    );
  }

  // =====================================================================================
  // MÉTODOS DE LIMPIEZA
  // =====================================================================================

  Future<void> clearCallHistory() async {
    final db = await database;
    await db.delete("call_history");
  }

  Future<void> clearScanHistory() async {
    final db = await database;
    await db.delete("scan_history");
  }

  Future<int> clearAllLogs() async {
    final db = await database;

    await db.delete("scan_history");
    await db.delete("call_history");

    return await db.delete("forensic_logs");
  }

  // =====================================================================================
  // MÉTODOS DE CONSULTA
  // =====================================================================================

  Future<List<Map<String, dynamic>>> getForensicLogs() async {
    final db = await database;

    return await db.query(
      "forensic_logs",
      orderBy: "timestamp DESC",
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
