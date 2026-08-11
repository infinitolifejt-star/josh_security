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

  // ==================================================================================================
  // PERMISO
  // ==================================================================================================

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

  // ==================================================================================================
  // MOSTRAR OVERLAY
  // ==================================================================================================

  static Future<void> showWarningOverlay({
    required String phoneNumber,
    required String riskLevel,
    required String message,
    String? agentReasoning,
  }) async {
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

      // ---------------------------------------------------------------------------------------------
      // CERRAR OVERLAY PREVIO
      // ---------------------------------------------------------------------------------------------

      final bool active =
          await FlutterOverlayWindow.isActive();

      if (active) {
        try {
          await FlutterOverlayWindow.closeOverlay();
        } catch (e) {
          developer.log(
            'Error cerrando overlay previo.',
            name: 'josh.security.overlay',
            error: e,
          );
        }

        await Future<void>.delayed(
          const Duration(milliseconds: 150),
        );
      }

      // ---------------------------------------------------------------------------------------------
      // CREAR OVERLAY
      // ---------------------------------------------------------------------------------------------

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

      // ---------------------------------------------------------------------------------------------
      // ESPERAR AL ISOLATED ENGINE DEL OVERLAY
      // ---------------------------------------------------------------------------------------------

      await Future<void>.delayed(
        const Duration(milliseconds: 250),
      );

      // ---------------------------------------------------------------------------------------------
      // ENVIAR INFORMACIÓN AL OVERLAY
      // ---------------------------------------------------------------------------------------------

      final Map<String, dynamic> payload =
          <String, dynamic>{
        'phone_number': phoneNumber,
        'risk_level': riskLevel,
        'message': message,
        'agent_reasoning': agentReasoning ?? '',
      };

      // Primer intento.
      try {
        await FlutterOverlayWindow.shareData(payload);
        return;
      } catch (e) {
        developer.log(
          'Primer envío de datos al overlay falló. Reintentando.',
          name: 'josh.security.overlay',
          error: e,
        );
      }

      // Segundo intento.
      await Future<void>.delayed(
        const Duration(milliseconds: 250),
      );

      try {
        await FlutterOverlayWindow.shareData(payload);
        return;
      } catch (e) {
        developer.log(
          'Segundo envío de datos al overlay falló.',
          name: 'josh.security.overlay',
          error: e,
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error desplegando Overlay.',
        name: 'josh.security.overlay',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ==================================================================================================
  // CERRAR OVERLAY
  // ==================================================================================================

  static Future<void> closeOverlay() async {
    try {
      final bool active =
          await FlutterOverlayWindow.isActive();

      if (active) {
        await FlutterOverlayWindow.closeOverlay();
      }
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
