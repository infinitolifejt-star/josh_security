// ====================================================================================================
// ARCHIVO: lib/main.dart
// PROJECT JOSH SECURITY
// PUNTO DE ENTRADA PRINCIPAL
// ====================================================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/security_provider.dart';
import 'services/background_shield.dart';
import 'services/security/overlay_service.dart';
import 'views/home_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/widgets/overlay_card.dart';

// ====================================================================================================
// ENTRY POINT DEL OVERLAY (Invocado si se requiere renderizado legacy en Flutter)
// ====================================================================================================

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: OverlayCard(),
      ),
    ),
  );
}

// ====================================================================================================
// MAIN
// ====================================================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Carga rápida de SharedPreferences para decidir la pantalla inicial
  bool onboardingVisto = false;
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    onboardingVisto = prefs.getBool('onboarding_visto') ?? false;
  } catch (e, stackTrace) {
    debugPrint('⚠️ [JOSH MAIN] Error leyendo onboarding: $e');
    debugPrint(stackTrace.toString());
  }

  // 2. Instanciamos el Provider
  final SecurityProvider securityProvider = SecurityProvider();

  // 3. Montamos la aplicación DE INMEDIATO para dibujar el primer frame y evitar congelar la UI
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SecurityProvider>.value(
          value: securityProvider,
        ),
      ],
      child: JoshSecurityApp(
        mostrarOnboarding: !onboardingVisto,
        securityProvider: securityProvider,
      ),
    ),
  );
}

// ====================================================================================================
// APP STRUCT
// ====================================================================================================

class JoshSecurityApp extends StatefulWidget {
  final bool mostrarOnboarding;
  final SecurityProvider securityProvider;

  const JoshSecurityApp({
    super.key,
    required this.mostrarOnboarding,
    required this.securityProvider,
  });

  @override
  State<JoshSecurityApp> createState() => _JoshSecurityAppState();
}

class _JoshSecurityAppState extends State<JoshSecurityApp> {
  @override
  void initState() {
    super.initState();
    // Ejecuta la inicialización de servicios pesados en segundo plano justo después del primer renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
  }

  Future<void> _initServices() async {
    // ----------------------------------------------------------------------------------------------
    // BACKGROUND SHIELD
    // ----------------------------------------------------------------------------------------------
    try {
      await BackgroundShield.initializeService();
      debugPrint('🛡️ [JOSH SHIELD] Servicio de fondo inicializado correctamente.');
    } catch (e, stackTrace) {
      debugPrint('⚠️ [JOSH SHIELD] Error inicializando servicio: $e');
      debugPrint(stackTrace.toString());
    }

    // ----------------------------------------------------------------------------------------------
    // OVERLAY PERMISSION CHECK
    // ----------------------------------------------------------------------------------------------
    try {
      final bool overlayGranted = await OverlayService.requestPermission();
      debugPrint(
        overlayGranted
            ? '🪟 [JOSH OVERLAY] Permiso concedido.'
            : '⚠️ [JOSH OVERLAY] Permiso no concedido.',
      );
    } catch (e, stackTrace) {
      debugPrint('⚠️ [JOSH OVERLAY] Error solicitando permiso: $e');
      debugPrint(stackTrace.toString());
    }

    // ----------------------------------------------------------------------------------------------
    // SECURITY PROVIDER
    // ----------------------------------------------------------------------------------------------
    try {
      await widget.securityProvider.initialize();
      debugPrint('📊 [JOSH ENGINE] SecurityProvider inicializado.');
    } catch (e, stackTrace) {
      debugPrint('⚠️ [JOSH ENGINE] Error inicializando SecurityProvider: $e');
      debugPrint(stackTrace.toString());
    }
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
      home: widget.mostrarOnboarding
          ? const OnboardingScreen()
          : const HomeScreen(),
    );
  }
}
