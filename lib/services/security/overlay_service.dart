// ====================================================================================================
// ARCHIVO: lib/services/security/overlay_service.dart
// COMPONENTE: Gestor del Pop-Up Flotante en Pantalla (JOSH Security)
// ====================================================================================================

import 'dart:developer' as developer;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  /// Solicita permisos para dibujar sobre otras aplicaciones si no están concedidos
  static Future<bool> requestPermission() async {
    final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      final bool? status = await FlutterOverlayWindow.requestPermission();
      return status ?? false;
    }
    return true;
  }

  /// Muestra la alerta flotante con los detalles del diagnóstico de la llamada
  static Future<void> showWarningOverlay({
    required String phoneNumber,
    required String riskLevel,
    required String message,
  }) async {
    try {
      final bool hasPermission = await requestPermission();
      if (!hasPermission) return;

      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "ALERTA CENTINELA",
        overlayContent: "$riskLevel: $phoneNumber",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.auto,
        height: 500,
        width: WindowSize.matchParent,
      );

      // Transmite los datos de la amenaza a la vista del Overlay
      await FlutterOverlayWindow.shareData({
        'phone_number': phoneNumber,
        'risk_level': riskLevel,
        'message': message,
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
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }
}