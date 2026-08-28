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
  final SecurityProvider securityProvider = SecurityProvider();
  bool onboardingVisto = false;

  try {
    await securityProvider.initialize();
    debugPrint('📊 [JOSH ENGINE] SecurityProvider inicializado.');
  } catch (e, stackTrace) {
    debugPrint('⚠️ [JOSH ENGINE] Error inicializando SecurityProvider: $e');
    debugPrint(stackTrace.toString());
  }

  // ----------------------------------------------------------------------------------------------
  // PREFERENCIAS
  // ----------------------------------------------------------------------------------------------
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    onboardingVisto = prefs.getBool('onboarding_visto') ?? false;
  } catch (e, stackTrace) {
    debugPrint('⚠️ [JOSH MAIN] Error leyendo onboarding: $e');
    debugPrint(stackTrace.toString());
  }

  // ----------------------------------------------------------------------------------------------
  // APP INVOCATION
  // ----------------------------------------------------------------------------------------------
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
// APP STRUCT
// ====================================================================================================

class JoshSecurityApp extends StatelessWidget {
  final bool mostrarOnboarding;

  const JoshSecurityApp({
    super.key,
    required this.mostrarOnboarding,
  });

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
      home: mostrarOnboarding
          ? const OnboardingScreen()
          : const HomeScreen(),
    );
  }
}
