import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Mantenemos tus dependencias
import 'views/splash_screen.dart'; // Importamos la nueva portada

Future<void> main() async {
  // Aseguramos que los widgets estén inicializados antes de cargar el .env
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargamos tus variables de entorno para que VirusTotal siga funcionando
  await dotenv.load(fileName: ".env");
  
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
        primarySwatch: Colors.green,
        useMaterial3: true,
        // Personalización del cursor y colores base para tu rol de experto 3D
        scaffoldBackgroundColor: const Color(0xFF010508),
      ),
      // CAMBIO CLAVE: Ahora la aplicación inicia en la pantalla de bienvenida
      home: const SplashScreen(), 
    );
  }
}