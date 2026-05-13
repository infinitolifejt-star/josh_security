import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importante para las llaves
import 'views/proactive_analysis_screen.dart';

Future<void> main() async {
  // Aseguramos que Flutter esté listo antes de cargar el .env
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    print("✅ Archivo .env cargado correctamente");
  } catch (e) {
    print("⚠️ No se pudo cargar el archivo .env: $e");
  }

  runApp(const JoshSecurityApp());
}

class JoshSecurityApp extends StatelessWidget {
  const JoshSecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOSH Security',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617),
        primaryColor: Colors.blueAccent,
      ),
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: ProactiveAnalysisScreen(),
        ),
      ),
    );
  }
}