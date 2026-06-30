// =====================================================================
// PROJECT CENTINELA: MAIN APPLICATION ENTRY POINT (v4.3.4)
// MÓDULO INTEGRADO DE PREVENCIÓN DE SUSPENSIÓN CLOUD (KEEP-ALIVE)
// =====================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'views/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ⏰ CRONÓMETRO DE REANIMACIÓN AUTOMÁTICA (Ejecución persistente cada 14 minutos)
  Timer.periodic(const Duration(minutes: 14), (timer) async {
    final String url = 'https://josh-security-backend.onrender.com/';
    try {
      print('🛰️ [KEEP-ALIVE] Transmitiendo pulso preventivo para evitar suspensión en Render...');
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    } catch (e) {
      print('⚠️ [KEEP-ALIVE] Falla en transmisión de pulso (Nube despertando): $e');
    }
  });

  runApp(const JoshSecurityApp());
}

class JoshSecurityApp extends StatelessWidget {
  const JoshSecurityApp({super.key});

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
      home: const HomeScreen(),
    );
  }
}