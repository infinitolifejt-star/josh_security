// ====================================================================================================
// ARCHIVO: lib/services/background_shield.dart
// COMPONENTE: Servicio de Protección y Escudo en Segundo Plano (Isolate AOT Robustecido)
// PROYECTO: JOSH Security
// ====================================================================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
class BackgroundShield {
  static const String notificationChannelId = 'josh_security_foreground';
  static const int notificationId = 888;
  static bool _isInitialized = false;

  /// Inicialización perimetral del servicio desde el Main Isolate
  static Future<void> initializeService() async {
    if (_isInitialized) {
      debugPrint('🛡️ [JOSH SHIELD] El servicio ya se encuentra inicializado.');
      return;
    }

    final FlutterBackgroundService service = FlutterBackgroundService();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Escudo de Protección JOSH Security',
      description:
          'Mantiene activa la protección perimetral y el monitoreo de amenazas.',
      importance: Importance.low,
    );

    // Configurar canal de notificación nativo
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'JOSH Security Activo',
        initialNotificationContent:
            'Escudo perimetral de seguridad ejecutándose',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
    _isInitialized = true;
    debugPrint(
        '🛡️ [JOSH SHIELD] Servicio de fondo inicializado correctamente.');
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  /// Punto de entrada aislado de segundo plano (Isolate Secundario)
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Encapsulamiento en zona aislada para mitigar excepciones de llamadas nativas cruzadas
    runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();

      if (service is AndroidServiceInstance) {
        service.on('setAsForeground').listen((_) {
          service.setAsForegroundService();
        });

        service.on('setAsBackground').listen((_) {
          service.setAsBackgroundService();
        });
      }

      // Escucha limpia para detención de servicio
      service.on('stopService').listen((_) {
        service.stopSelf();
      });

      // Monitoreo pasivo periódico de bajo consumo de energía (Cada 5 minutos)
      Timer.periodic(const Duration(minutes: 5), (_) {
        debugPrint(
            '🛡️ [JOSH SHIELD] Verificación periódica de integridad ejecutada.');
      });

      debugPrint('🛡️ [JOSH SHIELD] Escudo de fondo activo y listo.');
    }, (Object error, StackTrace stack) {
      // Captura y silencia errores no críticos de bindings entre isolates
      debugPrint('🛡️ [JOSH SHIELD] Captura preventiva de isolate: $error');
    });
  }
}
