// ====================================================================================================
// ARCHIVO: lib/services/security/database_service.dart
// REEMPLAZO TOTAL — ENTORNO SÍNCRONIZADO CENTINELA v4.5.1
// OP-HEURÍSTICA: Persistencia Relacional Local con Capacidad de Lectura Forense
// ====================================================================================================

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  factory DatabaseService() => instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'josh_security_centinela.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE forensic_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        service TEXT NOT NULL,
        activity TEXT NOT NULL,
        verdict TEXT NOT NULL,
        matched_rule TEXT NOT NULL,
        extra_data TEXT
      )
    ''');
  }

  /// Inserta un log forense de forma asíncrona en la base de datos
  Future<int> insertForensicLog(Map<String, dynamic> logEntry) async {
    final Database db = await database;
    return await db.insert(
      'forensic_logs',
      logEntry,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// SOLUCIÓN AL ERROR: Recupera todos los logs forenses ordenados cronológicamente (Últimos primero)
  Future<List<Map<String, dynamic>>> getForensicLogs() async {
    final Database db = await database;
    return await db.query(
      'forensic_logs',
      orderBy: 'timestamp DESC',
    );
  }
}