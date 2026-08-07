// ====================================================================================================
// ARCHIVO: lib/services/security/agent_memory.dart
// COMPONENTE: Memoria Contextual e Historial del Agente Centinela
// OPERACIÓN: Registro de Patrones de Infracción, Frecuencia de Eventos y Caché de Reputación
// ====================================================================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AgentMemory {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'josh_agent_memory.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabla de Memoria de Frecuencia y Contexto (Teléfonos / URLs)
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

        // Tabla de Decisiones y Juicios Agénticos
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

  /// Recupera el historial de contexto de una entidad (teléfono o URL)
  static Future<Map<String, dynamic>?> getTargetContext(String target) async {
    final db = await database;
    final res = await db.query(
      'memory_context',
      where: 'target = ?',
      whereArgs: [target],
    );
    return res.isNotEmpty ? res.first : null;
  }

  /// Registra o actualiza la frecuencia con la que un objetivo interactúa con el sistema
  static Future<void> updateContextMemory(String target, String vectorType, double riskScore) async {
    final db = await database;
    final existing = await getTargetContext(target);
    final now = DateTime.now().toIso8601String();

    if (existing == null) {
      await db.insert('memory_context', {
        'target': target,
        'vector_type': vectorType,
        'occurrences': 1,
        'last_seen': now,
        'highest_risk': riskScore,
        'user_decision': 'PENDING'
      });
    } else {
      int count = (existing['occurrences'] as int) + 1;
      double maxRisk = riskScore > (existing['highest_risk'] as double) ? riskScore : (existing['highest_risk'] as double);

      await db.update(
        'memory_context',
        {
          'occurrences': count,
          'last_seen': now,
          'highest_risk': maxRisk,
        },
        where: 'target = ?',
        whereArgs: [target],
      );
    }
  }

  /// Guarda el juicio deliberado por la IA Agéntica
  static Future<void> saveAgentDecision({
    required String target,
    required double heuristicScore,
    required double agentScore,
    required String verdict,
    required String reasoning,
  }) async {
    final db = await database;
    await db.insert('agent_decisions', {
      'target': target,
      'heuristic_score': heuristicScore,
      'agent_score': agentScore,
      'verdict': verdict,
      'reasoning': reasoning,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}