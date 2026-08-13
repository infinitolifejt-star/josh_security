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
      version: 4, // Incrementado a v4 para soportar IPQS y campos unificados
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ----------------------------------------------------------
    // REGISTROS FORENSES
    // ----------------------------------------------------------
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

    // ----------------------------------------------------------
    // HISTORIAL GENERAL DEL MOTOR
    // ----------------------------------------------------------
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

    // ----------------------------------------------------------
    // HISTORIAL DE LLAMADAS (Actualizado v4)
    // ----------------------------------------------------------
    await db.execute('''
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

    // ----------------------------------------------------------
    // TABLA DE CACHÉ PARA IPQS (Evita consumo excesivo de API)
    // ----------------------------------------------------------
    await db.execute('''
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

    // ----------------------------------------------------------
    // WHITELIST
    // ----------------------------------------------------------
    await db.execute('''
      CREATE TABLE whitelist_domains(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT UNIQUE,
        category TEXT
      )
    ''');

    // ----------------------------------------------------------
    // ÍNDICES
    // ----------------------------------------------------------
    await db.execute('CREATE INDEX idx_scan_time ON scan_history(timestamp);');
    await db.execute('CREATE INDEX idx_call_time ON call_history(timestamp);');
    await db.execute('CREATE INDEX idx_ipqs_phone ON ipqs_cache(phone_number);');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
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

    if (oldVersion < 4) {
      // Migración a versión 4: Añadir columnas a call_history y crear ipqs_cache
      try {
        await db.execute('ALTER TABLE call_history ADD COLUMN ipqs_score REAL;');
        await db.execute('ALTER TABLE call_history ADD COLUMN confidence TEXT;');
      } catch (_) {
        // Silenciar si la columna ya existía por despliegues previos
      }

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
    }
  }

  // =====================================================================================
  // MÉTODOS PARA CACHÉ IPQS
  // =====================================================================================

  Future<int> saveIpqsCache(Map<String, dynamic> data) async {
    try {
      final db = await database;
      return await db.insert(
        "ipqs_cache",
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      developer.log("saveIpqsCache Error", error: e, name: "DatabaseService");
      return -1;
    }
  }

  Future<Map<String, dynamic>?> getIpqsCache(String phoneNumber) async {
    try {
      final db = await database;
      final results = await db.query(
        "ipqs_cache",
        where: "phone_number = ?",
        whereArgs: [phoneNumber],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return results.first;
      }
    } catch (e) {
      developer.log("getIpqsCache Error", error: e, name: "DatabaseService");
    }
    return null;
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
      developer.log("insertForensicLog Error", error: e, name: "DatabaseService");
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
          "score": log["score"] ?? log["risk_score"], // Normalización de score
          "verdict": log["verdict"],
          "vector": log["vector"],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      developer.log("insertScanLog Error", error: e, name: "DatabaseService");
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
    double? ipqsScore,
    String? confidence,
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
          "ipqs_score": ipqsScore ?? 0.0,
          "confidence": confidence ?? "MEDIA",
          "verdict": verdict,
          "category": category,
          "details": details,
          "source": source,
          "timestamp": timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      developer.log("insertCallHistory Error", error: e, name: "DatabaseService");
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
  // MÉTODOS DE LIMPIEZA Y CONSULTA
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
    await db.delete("ipqs_cache");
    return await db.delete("forensic_logs");
  }

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
