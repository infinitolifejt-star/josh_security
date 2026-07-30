// ====================================================================================================
// ARCHIVO: lib/services/permission_manager.dart
// GESTOR DE PERMISOS NATIVOS Y OVERLAY CENTINELA
// ====================================================================================================

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class JoshPermissionManager {
  /// Solicita los permisos críticos para el Escudo Activo (Llamadas y Ventana Flotante).
  /// Retorna [true] si el usuario concedió todos los permisos necesarios.
  static Future<bool> requestActiveShieldPermissions() async {
    // 1. Solicitamos los permisos de teléfono y notificaciones
    Map<Permission, PermissionStatus> statuses = await [
      Permission.phone,
      Permission.notification,
    ].request();

    bool phoneGranted = statuses[Permission.phone]?.isGranted ?? false;

    // 2. Comprobación y solicitud nativa del Overlay (Ventana Flotante)
    bool overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!overlayGranted) {
      final bool? status = await FlutterOverlayWindow.requestPermission();
      overlayGranted = status ?? false;
    }

    return phoneGranted && overlayGranted;
  }

  /// Verifica de forma rápida si el Escudo Activo ya tiene los permisos necesarios autorizados.
  static Future<bool> hasActiveShieldPermissions() async {
    bool phoneGranted = await Permission.phone.isGranted;
    bool overlayGranted = await FlutterOverlayWindow.isPermissionGranted();

    return phoneGranted && overlayGranted;
  }
}