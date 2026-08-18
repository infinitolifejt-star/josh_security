// ============================================================================
// lib/services/background_shield.dart
// JOSH SECURITY
// SERVICIO DE FONDO
// ============================================================================

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
class BackgroundShield {
  BackgroundShield._();

  static const String notificationChannelId =
      'josh_shield_channel_silent';

  static const int notificationId = 888;

  // ==========================================================================
  // INICIALIZACIÓN
  // ==========================================================================

  @pragma('vm:entry-point')
  static Future<void> initializeService() async {
    WidgetsFlutterBinding.ensureInitialized();

    final FlutterBackgroundService service =
        FlutterBackgroundService();

    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel =
        AndroidNotificationChannel(
      notificationChannelId,
      'JOSH Active Shield',
      description:
          'Mantiene JOSH Security activo en segundo plano.',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'JOSH SECURITY',
        initialNotificationContent:
            'Escudo de seguridad activo.',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: <AndroidForegroundType>[
          AndroidForegroundType.dataSync,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  // ==========================================================================
  // IOS
  // ==========================================================================

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(
    ServiceInstance service,
  ) async {
    return true;
  }

  // ==========================================================================
  // BACKGROUND ISOLATE
  // ==========================================================================

  @pragma('vm:entry-point')
  static void onStart(
    ServiceInstance service,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();

    // Registrar correctamente los plugins en el isolate secundario.
    DartPluginRegistrant.ensureInitialized();

    service.on('stopService').listen(
      (dynamic event) {
        service.stopSelf();
      },
    );

    debugPrint(
      '[JOSH SHIELD] Background service iniciado.',
    );

    // ------------------------------------------------------------------------
    // IMPORTANTE
    //
    // NO escuchar PhoneState aquí.
    //
    // La captura telefónica se centraliza en:
    //
    // PhoneCallReceiver
    //       ↓
    // MethodChannel
    //       ↓
    // PhoneInterceptorService
    //
    // Esto evita análisis duplicados.
    // ------------------------------------------------------------------------

    Timer.periodic(
      const Duration(minutes: 5),
      (Timer timer) {
        debugPrint(
          '[JOSH SHIELD] Servicio de fondo activo.',
        );
      },
    );
  }
}
