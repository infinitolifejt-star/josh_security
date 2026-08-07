// ====================================================================================================
// ARCHIVO: lib/services/security/overlay_service.dart
// COMPONENTE: Gestor del Pop-Up Flotante en Pantalla (JOSH Security v6.0)
// ====================================================================================================

import 'dart:developer' as developer;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  /// Solicita permisos para dibujar sobre otras aplicaciones si no están concedidos
  static Future<bool> requestPermission() async {
    try {
      final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
      if (!isGranted) {
        final bool? status = await FlutterOverlayWindow.requestPermission();
        return status ?? false;
      }
      return true;
    } catch (e) {
      developer.log(
        'Error al verificar/solicitar permiso de Overlay',
        error: e,
        name: 'josh.security.overlay',
      );
      return false;
    }
  }

  /// Muestra la alerta flotante con los detalles del diagnóstico de la llamada
  static Future<void> showWarningOverlay({
    required String phoneNumber,
    required String riskLevel,
    required String message,
    String? agentReasoning,
  }) async {
    try {
      final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
      if (!isGranted) {
        developer.log(
          'Permiso de overlay no concedido. Omitiendo apertura.',
          name: 'josh.security.overlay',
        );
        return;
      }

      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "ALERTA CENTINELA",
        overlayContent: "$riskLevel: $phoneNumber",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: 600,
        width: WindowSize.matchParent,
      );

      // Pequeño retardo para asegurar que la ventana de la VM Dart montó la vista antes de compartir datos
      await Future.delayed(const Duration(milliseconds: 150));

      // Transmite los datos de la amenaza a la vista del Overlay (OverlayCard)
      await FlutterOverlayWindow.shareData({
        'phone_number': phoneNumber,
        'risk_level': riskLevel,
        'message': message,
        'agent_reasoning': agentReasoning,
      });
    } catch (e, stack) {
      developer.log(
        'Error al desplegar Overlay',
        error: e,
        stackTrace: stack,
        name: 'josh.security.overlay',
      );
    }
  }

  /// Cierra la ventana emergente
  static Future<void> closeOverlay() async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (e) {
      developer.log(
        'Error al cerrar Overlay',
        error: e,
        name: 'josh.security.overlay',
      );
    }
  }
}