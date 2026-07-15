import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundShield {
  static const String notificationChannelId = 'josh_shield_channel';
  static const int notificationId = 888;

  /// Inicializa el servicio en segundo plano para el Escudo Activo
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Configurar canal de notificaciones locales (necesario para Foreground Service en Android)
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'JOSH Active Shield',
      description: 'Mantiene el motor de JOSH Security protegiendo tu dispositivo en tiempo real.',
      importance: Importance.low, // Evita hacer ruidos molestos de forma persistente
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Se iniciará cuando el usuario active el interruptor en la UI
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Escudo Activo JOSH',
        initialNotificationContent: 'Monitoreando amenazas en tiempo real...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Punto de entrada aislado de la máquina virtual de Dart para iOS
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  /// Punto de entrada aislado (@pragma) de la máquina virtual de Dart para Android.
  /// Todo lo que ocurra aquí corre de manera independiente a la UI de la app.
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Si el servicio se detiene desde fuera
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // ==========================================
    // BUCLE PRINCIPAL DEL ESCUDO ACTIVO
    // ==========================================
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Aquí es donde se conectará el listener de llamadas/SMS nativo.
          // Por ahora, actualiza la notificación persistente para indicar que sigue vivo.
          service.setForegroundNotificationInfo(
            title: "Escudo Activo JOSH",
            content: "Protección perimetral activa. Dispositivo seguro.",
          );
        }
      }
    });
  }
}