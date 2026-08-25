// ====================================================================================================
// ARCHIVO: lib/services/permission_manager.dart
// GESTOR DE PERMISOS NATIVOS Y OVERLAY DE JOSH SECURITY
// ====================================================================================================

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

class JoshPermissionManager {
  /// Solicita los permisos críticos para el Escudo Activo (Llamadas, Notificaciones y Ventana Flotante).
  /// Retorna [true] si el usuario concedió todos los permisos requeridos.
  static Future<bool> requestActiveShieldPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.phone,
      Permission.notification,
    ].request();

    final bool phoneGranted = statuses[Permission.phone]?.isGranted ?? false;

    bool overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!overlayGranted) {
      final bool? status = await FlutterOverlayWindow.requestPermission();
      overlayGranted = status ?? false;
    }

    return phoneGranted && overlayGranted;
  }

  /// Verifica si los permisos críticos del Escudo Activo ya se encuentran autorizados.
  static Future<bool> hasActiveShieldPermissions() async {
    final bool phoneGranted = await Permission.phone.isGranted;
    final bool overlayGranted = await FlutterOverlayWindow.isPermissionGranted();

    return phoneGranted && overlayGranted;
  }
}
