// ============================================================================
// ARCHIVO: lib/services/security/apk_centinel_service.dart
// SERVICIO CENTINELA APK
// JOSH SECURITY v6.0
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ApkInstallEvent {
  final String appName;
  final String packageName;
  final String apkPath;

  const ApkInstallEvent({
    required this.appName,
    required this.packageName,
    required this.apkPath,
  });

  factory ApkInstallEvent.fromMap(Map<dynamic, dynamic> map) {
    return ApkInstallEvent(
      appName: (map['appName'] ?? 'Aplicación').toString(),
      packageName: (map['packageName'] ?? '').toString(),
      apkPath: (map['apkPath'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'appName': appName,
      'packageName': packageName,
      'apkPath': apkPath,
    };
  }
}

class ApkCentinelService {
  ApkCentinelService._();

  static final ApkCentinelService instance = ApkCentinelService._();

  static const MethodChannel _channel =
      MethodChannel('josh_security/apk_centinel');

  final StreamController<ApkInstallEvent> _controller =
      StreamController<ApkInstallEvent>.broadcast();

  Stream<ApkInstallEvent> get onApkInstalled => _controller.stream;

  bool _initialized = false;
  Future<void>? _initializationFuture;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final Future<void>? pending = _initializationFuture;

    if (pending != null) {
      return pending;
    }

    final Future<void> initialization = _performInitialization();

    _initializationFuture = initialization;

    try {
      await initialization;
      _initialized = true;
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
  }

  Future<void> _performInitialization() async {
    _channel.setMethodCallHandler(_methodHandler);

    await _loadPendingApks();
  }

  Future<dynamic> _methodHandler(MethodCall call) async {
    switch (call.method) {
      case 'onApkInstalled':
        _handleApkInstalled(call.arguments);
        return null;

      default:
        return null;
    }
  }

  void _handleApkInstalled(dynamic arguments) {
    try {
      if (arguments is! Map) {
        debugPrint(
          '[JOSH_TRACE] [ApkCentinel] '
          'Argumentos inválidos para onApkInstalled.',
        );
        return;
      }

      final ApkInstallEvent event = ApkInstallEvent.fromMap(
        Map<dynamic, dynamic>.from(arguments),
      );

      if (_controller.isClosed) {
        return;
      }

      _controller.add(event);
    } catch (error, stackTrace) {
      debugPrint(
        '[JOSH_TRACE] [ApkCentinel] Error procesando APK: $error',
      );

      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  Future<void> _loadPendingApks() async {
    try {
      final List<dynamic>? pending =
          await _channel.invokeMethod<List<dynamic>>(
        'getPendingApks',
      );

      if (pending == null || pending.isEmpty) {
        return;
      }

      for (final dynamic item in pending) {
        if (item is! Map) {
          continue;
        }

        if (_controller.isClosed) {
          return;
        }

        final ApkInstallEvent event = ApkInstallEvent.fromMap(
          Map<dynamic, dynamic>.from(item),
        );

        _controller.add(event);
      }
    } on MissingPluginException {
      debugPrint(
        '[JOSH_TRACE] [ApkCentinel] '
        'El canal nativo APK todavía no está disponible.',
      );
    } on PlatformException catch (error) {
      debugPrint(
        '[JOSH_TRACE] [ApkCentinel] '
        'Error obteniendo APK pendientes: '
        '${error.code}: ${error.message}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[JOSH_TRACE] [ApkCentinel] '
        'Error cargando APK pendientes: $error',
      );

      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);

    if (!_controller.isClosed) {
      await _controller.close();
    }

    _initialized = false;
    _initializationFuture = null;
  }
}
