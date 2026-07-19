import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('josh_security.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Tabla para registrar eventos forenses y amenazas detectadas
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

    // Tabla para guardar reglas de interceptación o reputación dinámicas
    await db.execute('''
      CREATE TABLE security_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rule_key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  // --- MÉTODOS CRUD COMPLETOS PARA LOGS FORENSES ---

  Future<int> insertForensicLog(Map<String, dynamic> log) async {
    final db = await instance.database;
    return await db.insert('forensic_logs', log);
  }

  Future<List<Map<String, dynamic>>> fetchAllLogs() async {
    final db = await instance.database;
    return await db.query('forensic_logs', orderBy: 'timestamp DESC');
  }

  Future<int> clearAllLogs() async {
    final db = await instance.database;
    return await db.delete('forensic_logs');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}