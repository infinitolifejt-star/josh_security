// ====================================================================================================
// ARCHIVO: lib/services/security/telemetry_service.dart
// SERVICIO DE TELEMETRÍA, ESTADÍSTICAS Y BITÁCORA
// JOSH SECURITY v6.0
// ====================================================================================================

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TelemetryService {
  TelemetryService();

  static const String _statsKey = 'security_statistics';
  static const String _logsKey = 'security_forensic_logs';
  static const String _bitacoraKey = 'security_master_bitacora';

  static const int _maxForensicLogs = 500;
  static const int _maxBitacoraEntries = 1000;
  static const int _maxCounterValue = 1 << 30;

  int _linksChecked = 0;
  int _callsChecked = 0;
  int _malwarePrevented = 0;

  final List<Map<String, dynamic>> _forensicLogs =
      <Map<String, dynamic>>[];

  final List<Map<String, dynamic>> _masterBitacora =
      <Map<String, dynamic>>[];

  Future<void>? _initializationFuture;

  Future<void> _writeQueue = Future<void>.value();

  bool _initialized = false;

  // ================================================================================================
  // GETTERS
  // ================================================================================================

  int get linksChecked => _linksChecked;

  int get callsChecked => _callsChecked;

  int get malwarePrevented => _malwarePrevented;

  List<Map<String, dynamic>> get forensicLogs {
    return List<Map<String, dynamic>>.unmodifiable(
      _forensicLogs.map(
        (Map<String, dynamic> entry) =>
            Map<String, dynamic>.from(entry),
      ),
    );
  }

  List<Map<String, dynamic>> get masterBitacora {
    return List<Map<String, dynamic>>.unmodifiable(
      _masterBitacora.map(
        (Map<String, dynamic> entry) =>
            Map<String, dynamic>.from(entry),
      ),
    );
  }

  Map<String, dynamic> get statistics {
    return <String, dynamic>{
      'linksChecked': _linksChecked,
      'callsChecked': _callsChecked,
      'malwarePrevented': _malwarePrevented,
    };
  }

  // ================================================================================================
  // INICIALIZACIÓN
  // ================================================================================================

  Future<void> initialize() {
    if (_initialized) {
      return Future<void>.value();
    }

    return _initializationFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    try {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      _loadStatistics(prefs);
      _loadLogs(prefs);
      _loadBitacora(prefs);

      _initialized = true;
    } catch (_) {
      _linksChecked = 0;
      _callsChecked = 0;
      _malwarePrevented = 0;
      _forensicLogs.clear();
      _masterBitacora.clear();

      _initialized = true;
    }
  }

  // ================================================================================================
  // ESTADÍSTICAS
  // ================================================================================================

  Future<void> incrementLinksChecked() async {
    await initialize();

    if (_linksChecked < _maxCounterValue) {
      _linksChecked++;
    }

    await _saveStatistics();
  }

  Future<void> incrementCallsChecked() async {
    await initialize();

    if (_callsChecked < _maxCounterValue) {
      _callsChecked++;
    }

    await _saveStatistics();
  }

  Future<void> incrementMalwarePrevented() async {
    await initialize();

    if (_malwarePrevented < _maxCounterValue) {
      _malwarePrevented++;
    }

    await _saveStatistics();
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

    final Map<String, dynamic> log = <String, dynamic>{
      'event': _safeText(event),
      'severity': _safeText(severity),
      'details': _safeText(details),
      'timestamp': DateTime.now().toIso8601String(),
    };

    _forensicLogs.insert(0, log);

    _trimList(
      _forensicLogs,
      _maxForensicLogs,
    );

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

    final Map<String, dynamic> entry = <String, dynamic>{
      'type': _safeText(type),
      'message': _safeText(message),
      'metadata': _sanitizeMap(metadata),
      'timestamp': DateTime.now().toIso8601String(),
    };

    _masterBitacora.insert(0, entry);

    _trimList(
      _masterBitacora,
      _maxBitacoraEntries,
    );

    await _saveBitacora();
  }

  // ================================================================================================
  // CONSULTAS
  // ================================================================================================

  List<Map<String, dynamic>> searchLogs(String query) {
    final String text = query.trim().toLowerCase();

    if (text.isEmpty) {
      return List<Map<String, dynamic>>.from(
        _masterBitacora.map(
          (Map<String, dynamic> entry) =>
              Map<String, dynamic>.from(entry),
        ),
      );
    }

    return _masterBitacora
        .where(
          (Map<String, dynamic> log) {
            final String content =
                jsonEncode(log).toLowerCase();

            return content.contains(text);
          },
        )
        .map(
          (Map<String, dynamic> entry) =>
              Map<String, dynamic>.from(entry),
        )
        .toList();
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

  Future<void> clearStatistics() async {
    await initialize();

    _linksChecked = 0;
    _callsChecked = 0;
    _malwarePrevented = 0;

    await _saveStatistics();
  }

  Future<void> clearAllTelemetry() async {
    await initialize();

    _linksChecked = 0;
    _callsChecked = 0;
    _malwarePrevented = 0;

    _forensicLogs.clear();
    _masterBitacora.clear();

    await _queueWrite(
      (SharedPreferences prefs) async {
        await Future.wait(<Future<bool>>[
          prefs.remove(_statsKey),
          prefs.remove(_logsKey),
          prefs.remove(_bitacoraKey),
        ]);
      },
    );
  }

  // ================================================================================================
  // PERSISTENCIA SERIALIZADA
  // ================================================================================================

  Future<void> _queueWrite(
    Future<void> Function(
      SharedPreferences prefs,
    ) operation,
  ) {
    final Future<void> next = _writeQueue.then(
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

  void _loadStatistics(SharedPreferences prefs) {
    final String? data = prefs.getString(_statsKey);

    if (data == null || data.trim().isEmpty) {
      return;
    }

    try {
      final dynamic decoded = jsonDecode(data);

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

  void _loadLogs(SharedPreferences prefs) {
    final String? data = prefs.getString(_logsKey);

    if (data == null || data.trim().isEmpty) {
      return;
    }

    try {
      final dynamic decoded = jsonDecode(data);

      if (decoded is! List) {
        throw const FormatException(
          'Formato de logs inválido.',
        );
      }

      _forensicLogs.clear();

      for (final dynamic item in decoded) {
        if (item is Map) {
          _forensicLogs.add(
            _sanitizeMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }

      _trimList(
        _forensicLogs,
        _maxForensicLogs,
      );
    } catch (_) {
      _forensicLogs.clear();
    }
  }

  // ================================================================================================
  // CARGA DE BITÁCORA
  // ================================================================================================

  void _loadBitacora(SharedPreferences prefs) {
    final String? data = prefs.getString(_bitacoraKey);

    if (data == null || data.trim().isEmpty) {
      return;
    }

    try {
      final dynamic decoded = jsonDecode(data);

      if (decoded is! List) {
        throw const FormatException(
          'Formato de bitácora inválido.',
        );
      }

      _masterBitacora.clear();

      for (final dynamic item in decoded) {
        if (item is Map) {
          _masterBitacora.add(
            _sanitizeMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }

      _trimList(
        _masterBitacora,
        _maxBitacoraEntries,
      );
    } catch (_) {
      _masterBitacora.clear();
    }
  }

  // ================================================================================================
  // NORMALIZACIÓN Y SEGURIDAD DE DATOS
  // ================================================================================================

  Map<String, dynamic> _sanitizeMap(
    Map<String, dynamic>? source,
  ) {
    if (source == null || source.isEmpty) {
      return <String, dynamic>{};
    }

    final Map<String, dynamic> result =
        <String, dynamic>{};

    source.forEach(
      (String key, dynamic value) {
        result[key] = _sanitizeValue(value);
      },
    );

    return result;
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value == null ||
        value is String ||
        value is num ||
        value is bool) {
      return value;
    }

    if (value is Map) {
      return _sanitizeMap(
        Map<String, dynamic>.from(value),
      );
    }

    if (value is Iterable) {
      return value
          .map(_sanitizeValue)
          .toList();
    }

    return value.toString();
  }

  String _safeText(String? value) {
    return value?.trim() ?? '';
  }

  void _trimList(
    List<Map<String, dynamic>> list,
    int maximum,
  ) {
    if (list.length <= maximum) {
      return;
    }

    list.removeRange(
      maximum,
      list.length,
    );
  }

  // ================================================================================================
  // CONVERSIÓN SEGURA
  // ================================================================================================

  int _readInt(dynamic value) {
    int result = 0;

    if (value is int) {
      result = value;
    } else if (value is num) {
      result = value.toInt();
    } else if (value is String) {
      result = int.tryParse(value) ?? 0;
    }

    if (result < 0) {
      return 0;
    }

    if (result > _maxCounterValue) {
      return _maxCounterValue;
    }

    return result;
  }
}
