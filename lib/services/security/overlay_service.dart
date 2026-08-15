// ====================================================================================================
// ARCHIVO: lib/services/security/overlay_service.dart
// JOSH SECURITY v6.0
// GESTOR DEL POP-UP FLOTANTE DE ADVERTENCIA EN TIEMPO REAL
// ====================================================================================================

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  OverlayService._();

  // ================================================================================================
  // CONSTANTES
  // ================================================================================================

  static const Duration _overlayStartupDelay = Duration(milliseconds: 250);
  static const Duration _retryDelay = Duration(milliseconds: 200);

  static void _trace(String message) {
    debugPrint('[JOSH_TRACE] [OverlayService] $message');
    developer.log(message, name: 'josh.security.overlay');
  }

  // ================================================================================================
  // PERMISO DE DIBUJO
  // ================================================================================================

  static Future<bool> requestPermission() async {
    try {
      final bool granted = await FlutterOverlayWindow.isPermissionGranted();

      if (granted) {
        return true;
      }

      final bool? result = await FlutterOverlayWindow.requestPermission();
      return result ?? false;
    } catch (e, stackTrace) {
      _trace('Error solicitando permisos de superposición: $e');
      developer.log(
        'Error verificando/solicitando permiso de Overlay.',
        name: 'josh.security.overlay',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ================================================================================================
  // DESPLIEGUE Y ACTUALIZACIÓN EN TIEMPO REAL
  // ================================================================================================

  static Future<void> showWarningOverlay({
    required String phoneNumber,
    required String riskLevel,
    required String message,
    String? agentReasoning,
  }) async {
    _trace('Solicitud de Overlay -> Número: $phoneNumber | Nivel: $riskLevel');

    try {
      final bool permissionGranted = await FlutterOverlayWindow.isPermissionGranted();

      if (!permissionGranted) {
        _trace('Permiso denegado por el sistema Android.');
        return;
      }

      final Map<String, dynamic> payload = <String, dynamic>{
        'phone_number': phoneNumber,
        'risk_level': riskLevel,
        'message': message,
        'agent_reasoning': agentReasoning ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final bool active = await FlutterOverlayWindow.isActive();

      if (active) {
        _trace('Overlay activo en pantalla. Forzando re-sincronización...');
        try {
          await FlutterOverlayWindow.closeOverlay();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      // Desplegar ventana superpuesta con dimensiones estandarizadas
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'ALERTA CENTINELA',
        overlayContent: '$riskLevel: $phoneNumber',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.auto,
        height: 600,
        width: WindowSize.matchParent,
      );

      await Future<void>.delayed(_overlayStartupDelay);

      final bool sent = await _sendPayload(payload);

      if (!sent) {
        _trace('ALERTA: El payload no pudo ser entregado al Isolate del Overlay.');
      } else {
        _trace('Overlay desplegado y datos entregados exitosamente.');
      }
    } catch (e, stackTrace) {
      _trace('Error crítico desplegando Overlay: $e');
      developer.log(
        'Error desplegando Overlay.',
        name: 'josh.security.overlay',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ================================================================================================
  // ENVÍO DE DATOS AL ISOLATE DE OVERLAY
  // ================================================================================================

  static Future<bool> _sendPayload(Map<String, dynamic> payload) async {
    try {
      await FlutterOverlayWindow.shareData(payload);
      return true;
    } catch (e) {
      _trace('Intento 1 de envío de datos falló: $e');
    }

    await Future<void>.delayed(_retryDelay);

    try {
      await FlutterOverlayWindow.shareData(payload);
      return true;
    } catch (e) {
      _trace('Intento 2 de envío de datos falló: $e');
    }

    return false;
  }

  // ================================================================================================
  // CIERRE DE LA VENTANA Y LIMPIEZA DE ESTADO
  // ================================================================================================

  static Future<void> closeOverlay() async {
    try {
      final bool active = await FlutterOverlayWindow.isActive();

      if (!active) {
        return;
      }

      // Inyectar payload de limpieza antes de cerrar
      await _sendPayload(<String, dynamic>{
        'phone_number': 'Analizando...',
        'risk_level': 'CORTAFUEGOS',
        'message': 'JOSH Security evaluando paquete entrante.',
        'agent_reasoning': '',
        'timestamp': 0,
      });

      await FlutterOverlayWindow.closeOverlay();
      _trace('Overlay cerrado y buffer de datos purgado.');
    } catch (e, stackTrace) {
      _trace('Error cerrando Overlay: $e');
      developer.log(
        'Error cerrando Overlay.',
        name: 'josh.security.overlay',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
