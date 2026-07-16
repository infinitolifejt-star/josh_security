// =====================================================================
// PROJECT CENTINELA: MAIN APPLICATION ENTRY POINT (v4.4.0)
// MÓDULO INTEGRADO DE PREVENCIÓN DE SUSPENSIÓN CLOUD (KEEP-ALIVE)
// =====================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart'; // ◄ AGREGADO: Importamos el gestor de estado
import 'package:shared_preferences/shared_preferences.dart';
import 'services/background_shield.dart';
import 'views/home_screen.dart';
import 'views/onboarding_screen.dart';
import 'providers/security_provider.dart'; // ◄ AGREGADO: Importamos tu nuevo proveedor

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INICIALIZACIÓN DEL ESCUDO ACTIVO (Segundo Plano)
  try {
    await BackgroundShield.initializeService();
    debugPrint('🛡️ [JOSH SHIELD] Servicio de fondo inicializado correctamente.');
  } catch (e) {
    debugPrint('⚠️ [JOSH SHIELD] Error al inicializar el servicio de fondo: $e');
  }

  // LA ADUANA: Buscamos en la memoria si el usuario ya vio el onboarding
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingVisto = prefs.getBool('onboarding_visto') ?? false;

  // ⏰ CRONÓMETRO DE REANIMACIÓN AUTOMÁTICA
  Timer.periodic(const Duration(minutes: 14), (timer) async {
    const String url = 'https://josh-security.onrender.com/';
    try {
      debugPrint('🛰️ [KEEP-ALIVE] Transmitiendo pulso preventivo para evitar suspensión en Render...');
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('⚠️ [KEEP-ALIVE] Falla en transmisión de pulso (Nube despertando): $e');
    }
  });

  // Pasamos el resultado invertido: si NO lo ha visto, se activa 'mostrarOnboarding'
  runApp(
    // ◄ MODIFICADO: Envolvemos la app para inicializar tu proveedor globalmente
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SecurityProvider()..initialize(), // Llama automáticamente a tu init() heurístico
        ),
      ],
      child: JoshSecurityApp(mostrarOnboarding: !onboardingVisto),
    ),
  );
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