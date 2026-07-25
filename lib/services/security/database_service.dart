// ====================================================================================================
// ARCHIVO: lib/services/security/database_service.dart
// PERSISTENCIA RELACIONAL LOCAL CON CAPACIDAD DE LECTURA FORENSE v4.6
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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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

    await db.execute('''
      CREATE TABLE whitelist_domains (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT UNIQUE NOT NULL,
        category TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS whitelist_domains (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          domain TEXT UNIQUE NOT NULL,
          category TEXT NOT NULL
        )
      ''');
    }
  }

  /// Inserta un log forense de forma asíncrona
  Future<int> insertForensicLog(Map<String, dynamic> logEntry) async {
    final Database db = await database;
    return await db.insert(
      'forensic_logs',
      logEntry,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Recupera todos los logs forenses ordenados cronológicamente
  Future<List<Map<String, dynamic>>> getForensicLogs() async {
    final Database db = await database;
    return await db.query(
      'forensic_logs',
      orderBy: 'timestamp DESC',
    );
  }

  /// Limpia registros forenses antiguos superados los 30 días
  Future<int> clearOldLogs() async {
    final Database db = await database;
    final String cutoffDate = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    return await db.delete(
      'forensic_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate],
    );
  }
}