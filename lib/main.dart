// ====================================================================================================
// ARCHIVO: lib/main.dart
// PROJECT JOSH SECURITY
// PUNTO DE ENTRADA PRINCIPAL
// INTEGRACIÓN: BACKGROUND SHIELD + PHONE INTERCEPTOR + OVERLAY
// ====================================================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/security_provider.dart';
import 'services/background_shield.dart';
import 'services/security/overlay_service.dart';
import 'services/security/phone_interceptor_service.dart';
import 'views/home_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/widgets/overlay_card.dart';

// ====================================================================================================
// ENTRY POINT DEL OVERLAY
// ====================================================================================================

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayCard(),
    ),
  );
}

// ====================================================================================================
// SERVICIO GLOBAL DEL INTERCEPTOR
// ====================================================================================================

final PhoneInterceptorService _phoneInterceptorService = PhoneInterceptorService();
Timer? _keepAliveTimer;

// ====================================================================================================
// MAIN
// ====================================================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Permisos de telefonía y notificaciones
  await _requestRuntimePermissions();

  // 2. Inicialización del Escudo de Segundo Plano
  try {
    await BackgroundShield.initializeService();
    debugPrint('🛡️ [JOSH SHIELD] Servicio de fondo inicializado correctamente.');
  } catch (e, stackTrace) {
    debugPrint('⚠️ [JOSH SHIELD] Error al inicializar el servicio de fondo: $e');
    debugPrint(stackTrace.toString());
  }

  // 3. Permiso de Overlay e Interceptor Telefónico
  try {
    final bool overlayGranted = await OverlayService.requestPermission();
    debugPrint(
      overlayGranted
          ? '🪟 [JOSH OVERLAY] Permiso de overlay concedido.'
          : '⚠️ [JOSH OVERLAY] Permiso de overlay no concedido.',
    );

    _phoneInterceptorService.startListening();
    debugPrint('📞 [JOSH INTERCEPTOR] Escucha de llamadas entrantes activada.');
  } catch (e, stackTrace) {
    debugPrint('⚠️ [JOSH INTERCEPTOR] Error activando interceptor: $e');
    debugPrint(stackTrace.toString());
  }

  // 4. Inicializar Security Provider
  final SecurityProvider securityProvider = SecurityProvider();
  bool onboardingVisto = false;

  try {
    await securityProvider.initialize();
    debugPrint('📊 [JOSH ENGINE] Base de datos y motor de seguridad listos.');
  } catch (e, stackTrace) {
    debugPrint('⚠️ [JOSH ENGINE] Error inicializando SecurityProvider: $e');
    debugPrint(stackTrace.toString());
  }

  // 5. Lectura de Preferencias
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    onboardingVisto = prefs.getBool('onboarding_visto') ?? false;
  } catch (e) {
    debugPrint('⚠️ [JOSH MAIN] Error leyendo estado del onboarding: $e');
  }

  // 6. Keep Alive del Backend
  _iniciarKeepAlive();

  // 7. Arranque de la Aplicación
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SecurityProvider>.value(
          value: securityProvider,
        ),
      ],
      child: JoshSecurityApp(
        mostrarOnboarding: !onboardingVisto,
      ),
    ),
  );
}

// ====================================================================================================
// PERMISOS DE EJECUCIÓN
// ====================================================================================================

Future<void> _requestRuntimePermissions() async {
  try {
    final PermissionStatus phoneStatus = await Permission.phone.request();
    debugPrint('📱 [JOSH PERMISSIONS] Estado permiso PHONE: $phoneStatus');

    final PermissionStatus notificationStatus = await Permission.notification.request();
    debugPrint('🔔 [JOSH PERMISSIONS] Estado permiso NOTIFICATION: $notificationStatus');

    if (!phoneStatus.isGranted) {
      debugPrint('⚠️ [JOSH PERMISSIONS] El permiso telefónico no fue concedido.');
    }
  } catch (e, stackTrace) {
    debugPrint('⚠️ [JOSH PERMISSIONS] Error solicitando permisos: $e');
    debugPrint(stackTrace.toString());
  }
}

// ====================================================================================================
// KEEP ALIVE DE BACKEND
// ====================================================================================================

void _iniciarKeepAlive() {
  _keepAliveTimer?.cancel();
  const String url = 'https://josh-security.onrender.com/';

  _keepAliveTimer = Timer.periodic(
    const Duration(minutes: 14),
    (_) async {
      try {
        debugPrint('🛰️ [KEEP-ALIVE] Transmitiendo pulso preventivo a Render...');
        final response = await http.get(Uri.parse(url)).timeout(
              const Duration(seconds: 15),
            );
        debugPrint('🛰️ [KEEP-ALIVE] Respuesta HTTP: ${response.statusCode}');
      } catch (e) {
        debugPrint('⚠️ [KEEP-ALIVE] Error de conexión: $e');
      }
    },
  );
}

// ====================================================================================================
// APLICACIÓN PRINCIPAL
// ====================================================================================================

class JoshSecurityApp extends StatefulWidget {
  final bool mostrarOnboarding;

  const JoshSecurityApp({
    super.key,
    required this.mostrarOnboarding,
  });

  @override
  State<JoshSecurityApp> createState() => _JoshSecurityAppState();
}

class _JoshSecurityAppState extends State<JoshSecurityApp> {
  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JOSH Security',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1E293B),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        useMaterial3: true,
      ),
      home: widget.mostrarOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
