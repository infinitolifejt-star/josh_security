// ====================================================================================================
// ARCHIVO: lib/services/security/overlay_service.dart
// JOSH SECURITY v6.0
// GESTOR DEL POP-UP FLOTANTE
// ====================================================================================================

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  OverlayService._();

  // ================================================================================================
  // CONSTANTES
  // ================================================================================================

  static const Duration _overlayStartupDelay =
      Duration(milliseconds: 300);

  static const Duration _retryDelay =
      Duration(milliseconds: 300);

  // ================================================================================================
  // ESTADO INTERNO
  // ================================================================================================

  static bool _operationInProgress = false;

  // ================================================================================================
  // PERMISO
  // ================================================================================================

  static Future<bool> requestPermission() async {
    try {
      final bool granted =
          await FlutterOverlayWindow.isPermissionGranted();

      if (granted) {
        return true;
      }

      final bool? result =
          await FlutterOverlayWindow.requestPermission();

      return result ?? false;
    } catch (e, stackTrace) {
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
  // MOSTRAR / ACTUALIZAR OVERLAY
  // ================================================================================================

  static Future<void> showWarningOverlay({
    required String phoneNumber,
    required String riskLevel,
    required String message,
    String? agentReasoning,
  }) async {
    if (_operationInProgress) {
      developer.log(
        'Operación de overlay ya en curso. Evento ignorado.',
        name: 'josh.security.overlay',
      );
      return;
    }

    _operationInProgress = true;

    try {
      final bool permissionGranted =
          await FlutterOverlayWindow.isPermissionGranted();

      if (!permissionGranted) {
        developer.log(
          'Permiso de overlay no concedido.',
          name: 'josh.security.overlay',
        );

        return;
      }

      final Map<String, dynamic> payload =
          <String, dynamic>{
        'phone_number': phoneNumber,
        'risk_level': riskLevel,
        'message': message,
        'agent_reasoning': agentReasoning ?? '',
      };

      // ----------------------------------------------------------------------------------------------
      // SI YA EXISTE UN OVERLAY, ACTUALIZARLO
      // ----------------------------------------------------------------------------------------------

      final bool active =
          await FlutterOverlayWindow.isActive();

      if (active) {
        developer.log(
          'Overlay activo. Actualizando información.',
          name: 'josh.security.overlay',
        );

        final bool sent =
            await _sendPayload(payload);

        if (sent) {
          return;
        }

        developer.log(
          'No fue posible actualizar el overlay activo. '
          'Se intentará reconstruir.',
          name: 'josh.security.overlay',
        );

        try {
          await FlutterOverlayWindow.closeOverlay();
        } catch (e, stackTrace) {
          developer.log(
            'Error cerrando overlay activo antes de reconstruir.',
            name: 'josh.security.overlay',
            error: e,
            stackTrace: stackTrace,
          );
        }

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );
      }

      // ----------------------------------------------------------------------------------------------
      // CREAR OVERLAY
      // ----------------------------------------------------------------------------------------------

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

      // ----------------------------------------------------------------------------------------------
      // ESPERAR INICIALIZACIÓN DEL ISOLATE NATIVO
      // ----------------------------------------------------------------------------------------------

      await Future<void>.delayed(
        _overlayStartupDelay,
      );

      // ----------------------------------------------------------------------------------------------
      // ENVIAR PAYLOAD
      // ----------------------------------------------------------------------------------------------

      final bool sent =
          await _sendPayload(payload);

      if (!sent) {
        developer.log(
          'No fue posible enviar los datos al overlay después de los reintentos.',
          name: 'josh.security.overlay',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error desplegando Overlay.',
        name: 'josh.security.overlay',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _operationInProgress = false;
    }
  }

  // ================================================================================================
  // ENVÍO DE DATOS AL OVERLAY
  // ================================================================================================

  static Future<bool> _sendPayload(
    Map<String, dynamic> payload,
  ) async {
    try {
      await FlutterOverlayWindow.shareData(payload);
      return true;
    } catch (e) {
      developer.log(
        'Primer envío de datos al overlay falló.',
        name: 'josh.security.overlay',
        error: e,
      );
    }

    await Future<void>.delayed(
      _retryDelay,
    );

    try {
      await FlutterOverlayWindow.shareData(payload);
      return true;
    } catch (e) {
      developer.log(
        'Segundo envío de datos al overlay falló.',
        name: 'josh.security.overlay',
        error: e,
      );
    }

    return false;
  }

  // ================================================================================================
  // CERRAR OVERLAY
  // ================================================================================================

  static Future<void> closeOverlay() async {
    if (_operationInProgress) {
      developer.log(
        'Cierre de overlay solicitado mientras existe otra operación.',
        name: 'josh.security.overlay',
      );
    }

    try {
      final bool active =
          await FlutterOverlayWindow.isActive();

      if (!active) {
        return;
      }

      await FlutterOverlayWindow.closeOverlay();

      developer.log(
        'Overlay cerrado correctamente.',
        name: 'josh.security.overlay',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error cerrando Overlay.',
        name: 'josh.security.overlay',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
