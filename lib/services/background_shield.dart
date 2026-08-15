// ====================================================================================================
// ARCHIVO: lib/services/background_shield.dart
// ENTORNO SINCRO CENTINELA v4.6.0
// OP-HEURÍSTICA: Escudo Silencioso Persistente y Registro Forense
// ====================================================================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:phone_state/phone_state.dart';

import 'security/phone_interceptor_service.dart';
import 'security/overlay_service.dart';
import 'security/database_service.dart';

@pragma('vm:entry-point')
class BackgroundShield {
  static const String notificationChannelId = 'josh_shield_channel_silent';
  static const int notificationId = 888;

  @pragma('vm:entry-point')
  static Future<void> initializeService() async {
    WidgetsFlutterBinding.ensureInitialized();
    final service = FlutterBackgroundService();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'JOSH Active Shield',
      description:
          'Mantiene el motor de JOSH Security protegiendo tu dispositivo en tiempo real.',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

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
        initialNotificationTitle: 'JOSH SECURITY',
        initialNotificationContent: 'Patrullando en tiempo real...',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [
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

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    final interceptor = PhoneInterceptorService();

    PhoneState.stream.listen((PhoneState state) async {
      if (state.status == PhoneStateStatus.CALL_INCOMING) {
        final String incomingNumber = state.number ?? '';

        if (incomingNumber.isNotEmpty) {
          final CallVerdict verdict =
              await interceptor.analyzeIncomingCall(incomingNumber);

          // Sincronizar en SQLite desde el proceso en segundo plano
          try {
            await DatabaseService.instance.insertForensicLog({
              'timestamp': DateTime.now().toIso8601String(),
              'service': 'SPAM',
              'activity': incomingNumber,
              'verdict': verdict.riskLevel,
              'matched_rule': 'INTERCEPTOR_SEGUNDO_PLANO',
              'extra_data': verdict.details,
            });
          } catch (_) {}

          service.invoke('incoming_call', {
            'number': incomingNumber,
            'riskLevel': verdict.riskLevel,
            'message': verdict.analysisMessage,
          });
        }
      } else if (state.status == PhoneStateStatus.CALL_ENDED ||
          state.status == PhoneStateStatus.NOTHING) {
        service.invoke('call_ended');

        try {
          await OverlayService.closeOverlay();
        } catch (e) {
          debugPrint('⚠️ Error al cerrar overlay desde BackgroundShield: $e');
        }
      }
    });
  }
}
