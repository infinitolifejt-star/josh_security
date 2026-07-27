// ====================================================================================================
// ARCHIVO: lib/services/background_shield.dart
// ENTORNO SINCRO CENTINELA v4.5.8
// OP-HEURÍSTICA: Interceptación en Segundo Plano, Transmisión IPC a UI y Disparo Directo de Overlay
// ====================================================================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:phone_state/phone_state.dart';

import 'security/phone_interceptor_service.dart';
import 'security/overlay_service.dart';

class BackgroundShield {
  static const String notificationChannelId = 'josh_shield_channel';
  static const int notificationId = 888;

  /// Inicializa el servicio en segundo plano para el Escudo Activo.
  @pragma('vm:entry-point')
  static Future<void> initializeService() async {
    WidgetsFlutterBinding.ensureInitialized();
    final service = FlutterBackgroundService();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'JOSH Active Shield',
      description: 'Mantiene el motor de JOSH Security protegiendo tu dispositivo en tiempo real.',
      importance: Importance.low,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Escudo Activo JOSH',
        initialNotificationContent: 'Patrullando amenazas en tiempo real...',
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

  /// Punto de entrada aislado de la máquina virtual de Dart para Android.
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // 📞 ESCUCHA EN TIEMPO REAL DE EVENTOS TELEFÓNICOS EN SEGUNDO PLANO
    PhoneState.stream.listen((PhoneState state) async {
      if (state.status == PhoneStateStatus.CALL_INCOMING) {
        final String incomingNumber = state.number ?? '';

        if (incomingNumber.isNotEmpty) {
          // 1. Análisis Heurístico
          final interceptor = PhoneInterceptorService();
          final CallVerdict verdict = await interceptor.analyzeIncomingCall(incomingNumber);

          // 2. Transmisión de evento al isolate de la UI
          service.invoke('incoming_call', {
            'number': incomingNumber,
            'riskLevel': verdict.riskLevel,
            'message': verdict.analysisMessage,
          });

          // 3. Actualización de notificación de estado
          if (service is AndroidServiceInstance) {
            if (await service.isForegroundService()) {
              service.setForegroundNotificationInfo(
                title: "Alerta Centinela: ${verdict.riskLevel}",
                content: "Número: $incomingNumber - ${verdict.analysisMessage}",
              );
            }
          }

          // 4. Despliegue de Ventana Emergente en Pantalla
          if (verdict.riskLevel == 'CRÍTICO' || verdict.riskLevel == 'ADVERTENCIA' || verdict.riskLevel == 'SEGURO') {
            try {
              await OverlayService.showWarningOverlay(
                phoneNumber: incomingNumber,
                riskLevel: verdict.riskLevel,
                message: verdict.analysisMessage,
              );
            } catch (e) {
              debugPrint('⚠️ Error al lanzar overlay desde servicio: $e');
            }
          }
        }
      } else if (state.status == PhoneStateStatus.CALL_ENDED) {
        service.invoke('call_ended');
        try {
          await OverlayService.closeOverlay();
        } catch (e) {
          debugPrint('⚠️ Error al cerrar overlay desde servicio: $e');
        }
      }
    });

    // Bucle de soporte persistente
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "Escudo Activo JOSH",
            content: "Protección perimetral activa. Dispositivo seguro.",
          );
        }
      }
    });
  }
}