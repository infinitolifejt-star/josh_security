// =====================================================================
// PROJECT CENTINELA: MAIN APPLICATION ENTRY POINT (v4.4.0)
// MÓDULO INTEGRADO DE PREVENCIÓN DE SUSPENSIÓN CLOUD (KEEP-ALIVE)
// =====================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // 1. Agregado para leer la memoria local
import 'views/home_screen.dart';
import 'views/onboarding_screen.dart'; // 2. Agregado para enlazar la nueva vista

void main() async { // 3. Se agregó 'async' para poder leer el disco antes de arrancar
  WidgetsFlutterBinding.ensureInitialized();

  // 4. LA ADUANA: Buscamos en la memoria si el usuario ya vio el onboarding
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingVisto = prefs.getBool('onboarding_visto') ?? false;

  // ⏰ CRONÓMETRO DE REANIMACIÓN AUTOMÁTICA (Ejecución persistente cada 14 minutos)
  Timer.periodic(const Duration(minutes: 14), (timer) async {
    const String url = 'https://josh-security.onrender.com/';
    try {
      debugPrint('🛰️ [KEEP-ALIVE] Transmitiendo pulso preventivo para evitar suspensión en Render...');
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('⚠️ [KEEP-ALIVE] Falla en transmisión de pulso (Nube despertando): $e');
    }
  });

  // 5. Pasamos el resultado invertido: si NO lo ha visto, se activa 'mostrarOnboarding'
  runApp(JoshSecurityApp(mostrarOnboarding: !onboardingVisto));
}

class JoshSecurityApp extends StatelessWidget {
  final bool mostrarOnboarding;
  
  // Constructor que recibe el estado de la aduana
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
      // 6. DECISIÓN DE RUTA: Si es true va a los Sliders, si es false va directo al Home
      home: mostrarOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}