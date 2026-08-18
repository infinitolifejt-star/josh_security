// ====================================================================================================
// ARCHIVO: lib/services/security/agent_memory.dart
// COMPONENTE: Memoria Contextual e Historial del Agente Centinela
// ====================================================================================================

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AgentMemory {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final String dbPath = await getDatabasesPath();
    final String path = join(dbPath, 'josh_agent_memory.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
CREATE TABLE memory_context (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  target TEXT UNIQUE,
  vector_type TEXT,
  occurrences INTEGER,
  last_seen TEXT,
  highest_risk REAL,
  user_decision TEXT
)
''');

        await db.execute('''
CREATE TABLE agent_decisions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  target TEXT,
  heuristic_score REAL,
  agent_score REAL,
  verdict TEXT,
  reasoning TEXT,
  timestamp TEXT
)
''');
      },
    );
  }

  static Future<Map<String, dynamic>?> getTargetContext(
    String target,
  ) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'memory_context',
      where: 'target = ?',
      whereArgs: <dynamic>[target],
      limit: 1,
    );

    return result.isEmpty ? null : result.first;
  }

  static Future<void> updateContextMemory(
    String target,
    String vectorType,
    double riskScore,
  ) async {
    final Database db = await database;
    final Map<String, dynamic>? existing =
        await getTargetContext(target);
    final String now = DateTime.now().toIso8601String();
    final double safeRisk = riskScore.clamp(0.0, 100.0);

    if (existing == null) {
      await db.insert(
        'memory_context',
        <String, dynamic>{
          'target': target,
          'vector_type': vectorType,
          'occurrences': 1,
          'last_seen': now,
          'highest_risk': safeRisk,
          'user_decision': 'PENDING',
        },
      );
      return;
    }

    final int occurrences = _readInt(existing['occurrences']);
    final double previousRisk = _readDouble(existing['highest_risk']);
    final double highestRisk =
        previousRisk > safeRisk ? previousRisk : safeRisk;

    await db.update(
      'memory_context',
      <String, dynamic>{
        'vector_type': vectorType,
        'occurrences': occurrences + 1,
        'last_seen': now,
        'highest_risk': highestRisk,
      },
      where: 'target = ?',
      whereArgs: <dynamic>[target],
    );
  }

  static Future<void> saveAgentDecision({
    required String target,
    required double heuristicScore,
    required double agentScore,
    required String verdict,
    required String reasoning,
  }) async {
    final Database db = await database;

    await db.insert(
      'agent_decisions',
      <String, dynamic>{
        'target': target,
        'heuristic_score': heuristicScore.clamp(0.0, 100.0),
        'agent_score': agentScore.clamp(0.0, 100.0),
        'verdict': verdict,
        'reasoning': reasoning,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      return value.toInt() < 0 ? 0 : value.toInt();
    }

    if (value is String) {
      final int? parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed < 0 ? 0 : parsed;
      }
    }

    return 0;
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble().clamp(0.0, 100.0);
    }

    if (value is String) {
      final double? parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed.clamp(0.0, 100.0);
      }
    }

    return 0.0;
  }
}
