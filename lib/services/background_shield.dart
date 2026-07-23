// ====================================================================================================
// ARCHIVO: lib/services/background_shield.dart
// REEMPLAZO TOTAL — ENTORNO SÍNCRONIZADO CENTINELA v4.5.2
// OP-HEURÍSTICA: Interceptación en Segundo Plano y Disparo Directo de Overlay
// ====================================================================================================

import 'dart:async';
import 'dart:ui';
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
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Escudo Activo JOSH',
        initialNotificationContent: 'Patrullando amenazas en tiempo real...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
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
    DartPluginRegistrant.ensureInitialized();

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // 📞 ESCUCHA EN TIEMPO REAL DE EVENTOS TELEFÓNICOS
    PhoneState.stream.listen((PhoneState state) async {
      if (state.status == PhoneStateStatus.CALL_INCOMING) {
        final String incomingNumber = state.number ?? '';

        if (incomingNumber.isNotEmpty) {
          // 1. Análisis Heurístico
          final interceptor = PhoneInterceptorService();
          final CallVerdict verdict = await interceptor.analyzeIncomingCall(incomingNumber);

          // 2. Actualización de notificación
          if (service is AndroidServiceInstance) {
            if (await service.isForegroundService()) {
              service.setForegroundNotificationInfo(
                title: "Alerta Centinela: ${verdict.riskLevel}",
                content: "Número: $incomingNumber - ${verdict.analysisMessage}",
              );
            }
          }

          // 3. Despliegue de Ventana Emergente en Pantalla
          if (verdict.riskLevel == 'CRÍTICO' || verdict.riskLevel == 'ADVERTENCIA') {
            await OverlayService.showWarningOverlay(
              phoneNumber: incomingNumber,
              riskLevel: verdict.riskLevel,
              message: verdict.analysisMessage,
            );
          }
        }
      } else if (state.status == PhoneStateStatus.CALL_ENDED) {
        // Cierra la ventana flotante automáticamente al colgar o finalizar la llamada
        await OverlayService.closeOverlay();
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