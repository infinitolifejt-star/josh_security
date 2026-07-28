// =====================================================================
// PROJECT JOSH SECURITY: MAIN APPLICATION ENTRY POINT
// MÓDULO INTEGRADO DE OVERLAY Y PREVENCIÓN DE SUSPENSIÓN CLOUD
// =====================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

import 'services/background_shield.dart';
import 'views/home_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/widgets/overlay_card.dart';
import 'providers/security_provider.dart'; 

/// Punto de entrada aislado de la máquina virtual de Dart para la ventana flotante (Overlay)
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. INICIALIZACIÓN DEL ESCUDO ACTIVO (Segundo Plano)
  try {
    await BackgroundShield.initializeService();
    debugPrint('🛡️ [JOSH SHIELD] Servicio de fondo inicializado correctamente.');
  } catch (e) {
    debugPrint('⚠️ [JOSH SHIELD] Error al inicializar el servicio de fondo: $e');
  }

  // 2. INICIALIZACIÓN PREVIA DEL PROVEEDOR DE SEGURIDAD Y PREFERENCIAS
  final securityProvider = SecurityProvider();
  bool onboardingVisto = false;

  try {
    await securityProvider.initialize(); // Carga de bitácora local SharedPreferences/SQLite
    debugPrint('📊 [JOSH ENGINE] Base de datos y heurística listas.');
  } catch (e) {
    debugPrint('⚠️ [JOSH ENGINE] Error al inicializar el motor de seguridad: $e');
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    onboardingVisto = prefs.getBool('onboarding_visto') ?? false;
  } catch (e) {
    debugPrint('⚠️ [JOSH MAIN] Error leyendo SharedPreferences de Onboarding: $e');
  }

  // 3. PULSO DE PREVENCIÓN EN NUBE (Render Keep-Alive)
  _iniciarKeepAlive();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SecurityProvider>.value(
          value: securityProvider,
        ),
      ],
      child: JoshSecurityApp(mostrarOnboarding: !onboardingVisto),
    ),
  );
}

/// Dispara un pulso cada 14 minutos para mantener activo el backend en Render
void _iniciarKeepAlive() {
  Timer.periodic(const Duration(minutes: 14), (timer) async {
    const String url = 'https://josh-security.onrender.com/';
    try {
      debugPrint('🛰️ [KEEP-ALIVE] Transmitiendo pulso preventivo a Render...');
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('⚠️ [KEEP-ALIVE] Falla en transmisión de pulso (Nube despertando): $e');
    }
  });
}

class JoshSecurityApp extends StatelessWidget {
  final bool mostrarOnboarding;
  
  const JoshSecurityApp({super.key, required this.mostrarOnboarding});

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
      home: mostrarOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}