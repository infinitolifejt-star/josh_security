import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AgentMemory {
  static const String _databaseName = 'josh_agent_memory.db';
  static const int _databaseVersion = 1;

  static Database? _database;

  static Future<Database> get database async {
    return _database ??= await _initDatabase();
  }

  static Future<Database> _initDatabase() async {
    final String databasesPath = await getDatabasesPath();
    final String path = join(databasesPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE memory_context (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target TEXT UNIQUE NOT NULL,
        vector_type TEXT NOT NULL,
        occurrences INTEGER NOT NULL DEFAULT 0,
        last_seen TEXT NOT NULL,
        highest_risk REAL NOT NULL DEFAULT 0,
        user_decision TEXT NOT NULL DEFAULT 'PENDING'
      )
    ''');

    await db.execute('''
      CREATE TABLE agent_decisions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target TEXT NOT NULL,
        heuristic_score REAL NOT NULL,
        agent_score REAL NOT NULL,
        verdict TEXT NOT NULL,
        reasoning TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_memory_context_target
      ON memory_context(target)
    ''');

    await db.execute('''
      CREATE INDEX idx_agent_decisions_target
      ON agent_decisions(target)
    ''');
  }

  static Future<Map<String, dynamic>?> getTargetContext(
    String target,
  ) async {
    final String normalizedTarget = target.trim();

    if (normalizedTarget.isEmpty) {
      return null;
    }

    final Database db = await database;

    final List<Map<String, dynamic>> rows = await db.query(
      'memory_context',
      where: 'target = ?',
      whereArgs: <dynamic>[normalizedTarget],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first;
  }

  static Future<void> updateContextMemory(
    String target,
    String vectorType,
    double riskScore,
  ) async {
    final String normalizedTarget = target.trim();

    if (normalizedTarget.isEmpty) {
      return;
    }

    final Database db = await database;

    final double safeRisk = riskScore.isFinite
        ? riskScore.clamp(0.0, 100.0)
        : 0.0;

    final String now = DateTime.now().toIso8601String();

    final Map<String, dynamic>? existing =
        await getTargetContext(normalizedTarget);

    if (existing == null) {
      await db.insert(
        'memory_context',
        <String, dynamic>{
          'target': normalizedTarget,
          'vector_type': vectorType.trim().isEmpty
              ? 'UNKNOWN'
              : vectorType.trim(),
          'occurrences': 1,
          'last_seen': now,
          'highest_risk': safeRisk,
          'user_decision': 'PENDING',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      return;
    }

    final int occurrences =
        _readInt(existing['occurrences']);

    final double previousRisk =
        _readDouble(existing['highest_risk']);

    final double highestRisk =
        safeRisk > previousRisk ? safeRisk : previousRisk;

    await db.update(
      'memory_context',
      <String, dynamic>{
        'vector_type': vectorType.trim().isEmpty
            ? 'UNKNOWN'
            : vectorType.trim(),
        'occurrences': occurrences + 1,
        'last_seen': now,
        'highest_risk': highestRisk,
      },
      where: 'target = ?',
      whereArgs: <dynamic>[normalizedTarget],
    );
  }

  static Future<void> saveAgentDecision({
    required String target,
    required double heuristicScore,
    required double agentScore,
    required String verdict,
    required String reasoning,
  }) async {
    final String normalizedTarget = target.trim();

    if (normalizedTarget.isEmpty) {
      return;
    }

    final Database db = await database;

    final double safeHeuristic = heuristicScore.isFinite
        ? heuristicScore.clamp(0.0, 100.0)
        : 0.0;

    final double safeAgentScore = agentScore.isFinite
        ? agentScore.clamp(0.0, 100.0)
        : 0.0;

    await db.insert(
      'agent_decisions',
      <String, dynamic>{
        'target': normalizedTarget,
        'heuristic_score': safeHeuristic,
        'agent_score': safeAgentScore,
        'verdict': verdict.trim().isEmpty
            ? 'UNKNOWN'
            : verdict.trim(),
        'reasoning': reasoning.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      final int result = value.toInt();
      return result < 0 ? 0 : result;
    }

    if (value is String) {
      final int? result = int.tryParse(value);
      if (result != null) {
        return result < 0 ? 0 : result;
      }
    }

    return 0;
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      final double result = value.toDouble();

      if (!result.isFinite) {
        return 0.0;
      }

      return result.clamp(0.0, 100.0);
    }

    if (value is String) {
      final double? result = double.tryParse(value);

      if (result != null && result.isFinite) {
        return result.clamp(0.0, 100.0);
      }
    }

    return 0.0;
  }
}
