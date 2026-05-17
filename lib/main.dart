import 'package:flutter/material.dart';
import 'views/home_screen.dart';
import 'views/proactive_analysis_screen.dart';
import 'views/simulation_screen.dart'; // La nueva vista que crearemos

void main() {
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
        primaryColor: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFF020617),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/analysis': (context) => const ProactiveAnalysisScreen(),
        '/simulation': (context) => const SimulationScreen(), // Enlace directo al Pilar 2
      },
    );
  }
}