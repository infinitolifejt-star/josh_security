// ====================================================================================================
// ARCHIVO: lib/services/background_shield.dart
// JOSH SECURITY
// ESCUDO DE PROTECCIÓN CONTINUA EN SEGUNDO PLANO (ROBUSTO Y SEGURO)
// ====================================================================================================

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
class BackgroundShield {
  BackgroundShield._();

  static const String notificationChannelId = 'josh_shield_channel_silent';
  static const int notificationId = 888;

  static Future<void> initializeService() async {
    WidgetsFlutterBinding.ensureInitialized();

    final FlutterBackgroundService service = FlutterBackgroundService();

    // 1. Crear el canal de notificación explícitamente para Android desde el Isolate Principal UI
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'JOSH Security Background Shield',
      description: 'Canal oficial para mantener el escudo de seguridad activo.',
      importance: Importance.low, // Servicio silencioso y estable
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 2. Configurar el servicio en segundo plano
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'JOSH SECURITY',
        initialNotificationContent: 'Escudo de seguridad activo.',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    debugPrint('🛡️ [JOSH SHIELD] Escudo de fondo activo y listo.');

    // Timer secundario de supervisión pasiva
    Timer.periodic(const Duration(minutes: 5), (Timer timer) {
      debugPrint('🛡️ [JOSH SHIELD] Escudo activo y supervisando sistema...');
    });
  }
}
