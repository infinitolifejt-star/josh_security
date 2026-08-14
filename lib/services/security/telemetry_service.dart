// ====================================================================================================
// ARCHIVO: lib/services/security/telemetry_service.dart
// SERVICIO DE TELEMETRÍA, ESTADÍSTICAS Y BITÁCORA
// JOSH SECURITY v6.0
// ====================================================================================================

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TelemetryService {
  TelemetryService();

  static const String _statsKey =
      'security_statistics';

  static const String _logsKey =
      'security_forensic_logs';

  static const String _bitacoraKey =
      'security_master_bitacora';

  int _linksChecked = 0;
  int _callsChecked = 0;
  int _malwarePrevented = 0;

  final List<Map<String, dynamic>> _forensicLogs =
      <Map<String, dynamic>>[];

  final List<Map<String, dynamic>> _masterBitacora =
      <Map<String, dynamic>>[];

  Future<void>? _initializationFuture;

  Future<void> _writeQueue = Future<void>.value();

  // ================================================================================================
  // GETTERS
  // ================================================================================================

  int get linksChecked => _linksChecked;

  int get callsChecked => _callsChecked;

  int get malwarePrevented => _malwarePrevented;

  List<Map<String, dynamic>> get forensicLogs =>
      List.unmodifiable(_forensicLogs);

  List<Map<String, dynamic>> get masterBitacora =>
      List.unmodifiable(_masterBitacora);

  // ================================================================================================
  // INICIALIZACIÓN
  // ================================================================================================

  Future<void> initialize() {
    return _initializationFuture ??=
        _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    _loadStatistics(prefs);
    _loadLogs(prefs);
    _loadBitacora(prefs);
  }

  // ================================================================================================
  // ESTADÍSTICAS
  // ================================================================================================

  Future<void> incrementLinksChecked() async {
    await initialize();

    _linksChecked++;

    await _saveStatistics();
  }

  Future<void> incrementCallsChecked() async {
    await initialize();

    _callsChecked++;

    await _saveStatistics();
  }

  Future<void> incrementMalwarePrevented() async {
    await initialize();

    _malwarePrevented++;

    await _saveStatistics();
  }

  Map<String, dynamic> get statistics {
    return <String, dynamic>{
      'linksChecked': _linksChecked,
      'callsChecked': _callsChecked,
      'malwarePrevented': _malwarePrevented,
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
    await initialize();

    final Map<String, dynamic> log =
        <String, dynamic>{
      'event': event,
      'severity': severity,
      'details': details ?? '',
      'timestamp':
          DateTime.now().toIso8601String(),
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
    await initialize();

    final Map<String, dynamic> entry =
        <String, dynamic>{
      'type': type,
      'message': message,
      'metadata': metadata ?? <String, dynamic>{},
      'timestamp':
          DateTime.now().toIso8601String(),
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

  List<Map<String, dynamic>> searchLogs(
    String query,
  ) {
    final String text =
        query.trim().toLowerCase();

    if (text.isEmpty) {
      return List<Map<String, dynamic>>.from(
        _masterBitacora,
      );
    }

    return _masterBitacora.where(
      (Map<String, dynamic> log) {
        final String content =
            jsonEncode(log).toLowerCase();

        return content.contains(text);
      },
    ).toList();
  }

  // ================================================================================================
  // LIMPIEZA
  // ================================================================================================

  Future<void> clearLogs() async {
    await initialize();

    _forensicLogs.clear();

    await _saveLogs();
  }

  Future<void> clearBitacora() async {
    await initialize();

    _masterBitacora.clear();

    await _saveBitacora();
  }

  // ================================================================================================
  // PERSISTENCIA SERIALIZADA
  // ================================================================================================

  Future<void> _queueWrite(
    Future<void> Function(
      SharedPreferences prefs,
    ) operation,
  ) {
    final Future<void> next =
        _writeQueue.then(
      (_) async {
        final SharedPreferences prefs =
            await SharedPreferences.getInstance();

        await operation(prefs);
      },
    );

    _writeQueue = next.catchError(
      (_) {},
    );

    return next;
  }

  Future<void> _saveStatistics() {
    return _queueWrite(
      (SharedPreferences prefs) async {
        await prefs.setString(
          _statsKey,
          jsonEncode(
            <String, dynamic>{
              'linksChecked': _linksChecked,
              'callsChecked': _callsChecked,
              'malwarePrevented': _malwarePrevented,
            },
          ),
        );
      },
    );
  }

  Future<void> _saveLogs() {
    return _queueWrite(
      (SharedPreferences prefs) async {
        await prefs.setString(
          _logsKey,
          jsonEncode(_forensicLogs),
        );
      },
    );
  }

  Future<void> _saveBitacora() {
    return _queueWrite(
      (SharedPreferences prefs) async {
        await prefs.setString(
          _bitacoraKey,
          jsonEncode(_masterBitacora),
        );
      },
    );
  }

  // ================================================================================================
  // CARGA DE ESTADÍSTICAS
  // ================================================================================================

  void _loadStatistics(
    SharedPreferences prefs,
  ) {
    final String? data =
        prefs.getString(_statsKey);

    if (data == null) {
      return;
    }

    try {
      final dynamic decoded =
          jsonDecode(data);

      if (decoded is! Map) {
        throw const FormatException(
          'Formato de estadísticas inválido.',
        );
      }

      _linksChecked =
          _readInt(decoded['linksChecked']);

      _callsChecked =
          _readInt(decoded['callsChecked']);

      _malwarePrevented =
          _readInt(decoded['malwarePrevented']);
    } catch (_) {
      _linksChecked = 0;
      _callsChecked = 0;
      _malwarePrevented = 0;
    }
  }

  // ================================================================================================
  // CARGA DE LOGS
  // ================================================================================================

  void _loadLogs(
    SharedPreferences prefs,
  ) {
    final String? data =
        prefs.getString(_logsKey);

    if (data == null) {
      return;
    }

    try {
      final dynamic decoded =
          jsonDecode(data);

      if (decoded is! List) {
        throw const FormatException(
          'Formato de logs inválido.',
        );
      }

      _forensicLogs.clear();

      for (final dynamic item in decoded) {
        if (item is Map) {
          _forensicLogs.add(
            Map<String, dynamic>.from(item),
          );
        }
      }

      if (_forensicLogs.length > 500) {
        _forensicLogs.removeRange(
          500,
          _forensicLogs.length,
        );
      }
    } catch (_) {
      _forensicLogs.clear();
    }
  }

  // ================================================================================================
  // CARGA DE BITÁCORA
  // ================================================================================================

  void _loadBitacora(
    SharedPreferences prefs,
  ) {
    final String? data =
        prefs.getString(_bitacoraKey);

    if (data == null) {
      return;
    }

    try {
      final dynamic decoded =
          jsonDecode(data);

      if (decoded is! List) {
        throw const FormatException(
          'Formato de bitácora inválido.',
        );
      }

      _masterBitacora.clear();

      for (final dynamic item in decoded) {
        if (item is Map) {
          _masterBitacora.add(
            Map<String, dynamic>.from(item),
          );
        }
      }

      if (_masterBitacora.length > 1000) {
        _masterBitacora.removeRange(
          1000,
          _masterBitacora.length,
        );
      }
    } catch (_) {
      _masterBitacora.clear();
    }
  }

  // ================================================================================================
  // CONVERSIÓN SEGURA
  // ================================================================================================

  int _readInt(dynamic value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      return value.toInt().clamp(0, 1 << 30);
    }

    if (value is String) {
      final int? parsed =
          int.tryParse(value);

      if (parsed != null) {
        return parsed.clamp(0, 1 << 30);
      }
    }

    return 0;
  }
}
