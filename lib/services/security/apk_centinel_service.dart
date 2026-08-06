// ====================================================================================================
// ARCHIVO: lib/services/security/apk_centinel_service.dart
// SERVICIO CENTINELA APK
// JOSH SECURITY v6.0
// ====================================================================================================

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
}

class ApkCentinelService {
  ApkCentinelService._();

  static final ApkCentinelService instance = ApkCentinelService._();

  static const MethodChannel _channel = MethodChannel('josh_security/apk_centinel');

  final StreamController<ApkInstallEvent> _controller = StreamController<ApkInstallEvent>.broadcast();

  Stream<ApkInstallEvent> get onApkInstalled => _controller.stream;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_methodHandler);
    await _loadPendingApks();
  }

  Future<dynamic> _methodHandler(MethodCall call) async {
    switch (call.method) {
      case 'onApkInstalled':
        try {
          final event = ApkInstallEvent.fromMap(
            Map<dynamic, dynamic>.from(call.arguments),
          );
          _controller.add(event);
        } catch (e) {
          debugPrint("APK Centinel error: $e");
        }
        break;
    }
  }

  Future<void> _loadPendingApks() async {
    try {
      final pending = await _channel.invokeMethod<List<dynamic>>('getPendingApks');
      if (pending == null) return;

      for (final item in pending) {
        if (item is Map) {
          _controller.add(ApkInstallEvent.fromMap(item));
        }
      }
    } catch (e) {
      debugPrint("APK Pending Error: $e");
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}