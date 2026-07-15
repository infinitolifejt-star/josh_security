import 'package:permission_handler/permission_handler.dart';

class JoshPermissionManager {
  /// Solicita los permisos críticos para el Escudo Activo (Llamadas y Ventana Flotante).
  /// Retorna [true] si el usuario concedió todos los permisos necesarios.
  static Future<bool> requestActiveShieldPermissions() async {
    // 1. Solicitamos el permiso de teléfono (lectura de estado y llamadas)
    PermissionStatus phoneStatus = await Permission.phone.request();

    // 2. Solicitamos el permiso para dibujar sobre otras apps (Alerta flotante)
    PermissionStatus alertStatus = await Permission.systemAlertWindow.request();

    // 3. Retornamos si ambos fueron concedidos
    return phoneStatus.isGranted && alertStatus.isGranted;
  }

  /// Verifica de forma rápida si el Escudo Activo ya tiene los permisos necesarios autorizados.
  static Future<bool> hasActiveShieldPermissions() async {
    bool phoneGranted = await Permission.phone.isGranted;
    bool alertGranted = await Permission.systemAlertWindow.isGranted;
    return phoneGranted && alertGranted;
  }
}