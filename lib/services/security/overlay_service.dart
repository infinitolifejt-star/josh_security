import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  OverlayService._();

  static const Duration _startupDelay =
      Duration(milliseconds: 400);

  static const Duration _retryDelay =
      Duration(milliseconds: 250);

  static Future<void> _operationLock =
      Future<void>.value();

  static void _trace(String message) {
    if (kDebugMode) {
      debugPrint(
        '[JOSH_TRACE] [OverlayService] $message',
      );
    }

    developer.log(
      message,
      name: 'josh.security.overlay',
    );
  }

  static Future<T> _serialized<T>(
    Future<T> Function() action,
  ) async {
    final Future<void> previous =
        _operationLock;

    final Completer<void> current =
        Completer<void>();

    _operationLock = current.future;

    try {
      await previous;
      return await action();
    } finally {
      if (!current.isCompleted) {
        current.complete();
      }
    }
  }

  static Future<bool> requestPermission() async {
    try {
      final bool granted =
          await FlutterOverlayWindow
              .isPermissionGranted();

      if (granted) {
        return true;
      }

      final bool? result =
          await FlutterOverlayWindow
              .requestPermission();

      return result ?? false;
    } catch (error, stackTrace) {
      _trace(
        'Error solicitando permiso overlay: $error',
      );

      developer.log(
        'Error solicitando permiso overlay.',
        name: 'josh.security.overlay',
        error: error,
        stackTrace: stackTrace,
      );

      return false;
    }
  }

  static Future<bool> isPermissionGranted() async {
    try {
      return await FlutterOverlayWindow
          .isPermissionGranted();
    } catch (error) {
      _trace(
        'Error comprobando permiso overlay: $error',
      );

      return false;
    }
  }

  static Future<bool> isActive() async {
    try {
      return await FlutterOverlayWindow
          .isActive();
    } catch (error) {
      _trace(
        'Error comprobando estado overlay: $error',
      );

      return false;
    }
  }

  static Future<void> showWarningOverlay({
    required String phoneNumber,
    required String riskLevel,
    required String message,
    String? agentReasoning,
  }) async {
    await _serialized<void>(
      () => _showInternal(
        phoneNumber: phoneNumber,
        riskLevel: riskLevel,
        message: message,
        agentReasoning: agentReasoning,
      ),
    );
  }

  static Future<void> _showInternal({
    required String phoneNumber,
    required String riskLevel,
    required String message,
    String? agentReasoning,
  }) async {
    _trace(
      'Solicitud overlay: '
      '$phoneNumber | $riskLevel',
    );

    try {
      final bool permissionGranted =
          await FlutterOverlayWindow
              .isPermissionGranted();

      if (!permissionGranted) {
        _trace(
          'Permiso de overlay no concedido.',
        );

        return;
      }

      final Map<String, dynamic> payload =
          <String, dynamic>{
        'phone_number': phoneNumber,
        'risk_level': riskLevel,
        'message': message,
        'agent_reasoning':
            agentReasoning ?? '',
        'timestamp':
            DateTime.now()
                .millisecondsSinceEpoch,
      };

      bool active =
          await FlutterOverlayWindow
              .isActive();

      if (!active) {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: 'ALERTA CENTINELA',
          overlayContent:
              '$riskLevel: $phoneNumber',
          flag: OverlayFlag.defaultFlag,
          visibility:
              NotificationVisibility
                  .visibilitySecret,
          positionGravity:
              PositionGravity.auto,
          height: 450,
          width: WindowSize.matchParent,
        );

        await Future<void>.delayed(
          _startupDelay,
        );

        active =
            await FlutterOverlayWindow
                .isActive();
      }

      if (!active) {
        _trace(
          'Android no confirmó overlay activo.',
        );

        return;
      }

      final bool sent =
          await _sendPayload(payload);

      if (!sent) {
        _trace(
          'No fue posible enviar el payload al overlay.',
        );

        return;
      }

      _trace(
        'Overlay sincronizado correctamente.',
      );
    } catch (error, stackTrace) {
      _trace(
        'Error mostrando overlay: $error',
      );

      developer.log(
        'Error mostrando overlay.',
        name: 'josh.security.overlay',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<bool> _sendPayload(
    Map<String, dynamic> payload,
  ) async {
    for (int attempt = 1;
        attempt <= 3;
        attempt++) {
      try {
        await FlutterOverlayWindow
            .shareData(payload);

        return true;
      } catch (error) {
        _trace(
          'Payload intento $attempt falló: $error',
        );

        if (attempt < 3) {
          await Future<void>.delayed(
            _retryDelay,
          );
        }
      }
    }

    return false;
  }

  static Future<void> closeOverlay() async {
    await _serialized<void>(
      () async {
        try {
          final bool active =
              await FlutterOverlayWindow
                  .isActive();

          if (!active) {
            return;
          }

          await FlutterOverlayWindow
              .closeOverlay();

          _trace(
            'Overlay cerrado correctamente.',
          );
        } catch (error, stackTrace) {
          _trace(
            'Error cerrando overlay: $error',
          );

          developer.log(
            'Error cerrando overlay.',
            name: 'josh.security.overlay',
            error: error,
            stackTrace: stackTrace,
          );
        }
      },
    );
  }
}
