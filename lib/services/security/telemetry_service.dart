// ====================================================================================================
// ARCHIVO: lib/services/security/telemetry_service.dart
// SERVICIO DE TELEMETRÍA, ESTADÍSTICAS Y BITÁCORA
// JOSH SECURITY v6.0
// ====================================================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TelemetryService {
  TelemetryService();

  static const String _statsKey = 'security_statistics';
  static const String _logsKey = 'security_forensic_logs';
  static const String _bitacoraKey = 'security_master_bitacora';

  int _linksChecked = 0;
  int _callsChecked = 0;
  int _malwarePrevented = 0;

  final List<Map<String, dynamic>> _forensicLogs = [];
  final List<Map<String, dynamic>> _masterBitacora = [];

  int get linksChecked => _linksChecked;
  int get callsChecked => _callsChecked;
  int get malwarePrevented => _malwarePrevented;

  List<Map<String, dynamic>> get forensicLogs => List.unmodifiable(_forensicLogs);
  List<Map<String, dynamic>> get masterBitacora => List.unmodifiable(_masterBitacora);

  // ================================================================================================
  // INICIALIZACIÓN
  // ================================================================================================

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _loadStatistics(prefs);
    _loadLogs(prefs);
    _loadBitacora(prefs);
  }

  // ================================================================================================
  // ESTADÍSTICAS
  // ================================================================================================

  Future<void> incrementLinksChecked() async {
    _linksChecked++;
    await _saveStatistics();
  }

  Future<void> incrementCallsChecked() async {
    _callsChecked++;
    await _saveStatistics();
  }

  Future<void> incrementMalwarePrevented() async {
    _malwarePrevented++;
    await _saveStatistics();
  }

  Map<String, dynamic> get statistics {
    return {
      "linksChecked": _linksChecked,
      "callsChecked": _callsChecked,
      "malwarePrevented": _malwarePrevented,
    };
  }

  // ================================================================================================
  // FORENSIC LOGS
  // ================================================================================================

  Future<void> addForensicLog({
    required String event,
    required String severity,
    String? details,
  }) async {
    final log = {
      "event": event,
      "severity": severity,
      "details": details ?? "",
      "timestamp": DateTime.now().toIso8601String(),
    };

    _forensicLogs.insert(0, log);

    if (_forensicLogs.length > 500) {
      _forensicLogs.removeLast();
    }

    await _saveLogs();
  }

  // ================================================================================================
  // MASTER BITÁCORA
  // ================================================================================================

  Future<void> registerEvent({
    required String type,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    final entry = {
      "type": type,
      "message": message,
      "metadata": metadata ?? {},
      "timestamp": DateTime.now().toIso8601String(),
    };

    _masterBitacora.insert(0, entry);

    if (_masterBitacora.length > 1000) {
      _masterBitacora.removeLast();
    }

    await _saveBitacora();
  }

  // ================================================================================================
  // CONSULTAS
  // ================================================================================================

  List<Map<String, dynamic>> searchLogs(String query) {
    final text = query.toLowerCase();

    return _masterBitacora.where((log) {
      final content = jsonEncode(log).toLowerCase();
      return content.contains(text);
    }).toList();
  }

  Future<void> clearLogs() async {
    _forensicLogs.clear();
    await _saveLogs();
  }

  Future<void> clearBitacora() async {
    _masterBitacora.clear();
    await _saveBitacora();
  }

  // ================================================================================================
  // PERSISTENCIA
  // ================================================================================================

  Future<void> _saveStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _statsKey,
      jsonEncode({
        "linksChecked": _linksChecked,
        "callsChecked": _callsChecked,
        "malwarePrevented": _malwarePrevented,
      }),
    );
  }

  Future<void> _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _logsKey,
      jsonEncode(_forensicLogs),
    );
  }

  Future<void> _saveBitacora() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _bitacoraKey,
      jsonEncode(_masterBitacora),
    );
  }

  // ================================================================================================
  // CARGA DE DATOS
  // ================================================================================================

  void _loadStatistics(SharedPreferences prefs) {
    final data = prefs.getString(_statsKey);
    if (data == null) return;

    try {
      final decoded = jsonDecode(data);

      _linksChecked = decoded["linksChecked"] ?? 0;
      _callsChecked = decoded["callsChecked"] ?? 0;
      _malwarePrevented = decoded["malwarePrevented"] ?? 0;
    } catch (_) {
      _linksChecked = 0;
      _callsChecked = 0;
      _malwarePrevented = 0;
    }
  }

  void _loadLogs(SharedPreferences prefs) {
    final data = prefs.getString(_logsKey);
    if (data == null) return;

    try {
      final json = jsonDecode(data);

      if (json is List) {
        _forensicLogs.clear();

        for (final item in json) {
          if (item is Map) {
            _forensicLogs.add(
              Map<String, dynamic>.from(item),
            );
          }
        }
      }
    } catch (_) {
      _forensicLogs.clear();
    }
  }

  void _loadBitacora(SharedPreferences prefs) {
    final data = prefs.getString(_bitacoraKey);
    if (data == null) return;

    try {
      final json = jsonDecode(data);

      if (json is List) {
        _masterBitacora.clear();

        for (final item in json) {
          if (item is Map) {
            _masterBitacora.add(
              Map<String, dynamic>.from(item),
            );
          }
        }
      }
    } catch (_) {
      _masterBitacora.clear();
    }
  }
}