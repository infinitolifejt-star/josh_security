import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Obtenemos las dimensiones de la pantalla para hacer el diseño responsivo
    final mediaQuery = MediaQuery.of(context);
    final bool isLandscape = mediaQuery.orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo oscuro premium
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado de la App
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JOSH SECURITY',
                          style: TextStyle(
                            color: Colors.blueAccent.shade400,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Text(
                          'Global Protection Active',
                          style: TextStyle(color: Colors.slate400, fontSize: 12),
                        ),
                      ],
                    ),
                    const Icon(Icons.shield, color: Colors.greenAccent, size: 32),
                  ],
                ),
                const SizedBox(height: 24),

                // Tarjeta de Alerta de Phishing (Corregida y Responsiva)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade900, Colors.red.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.gpp_bad_outlined,
                        color: Colors.white,
                        size: 50,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '¡PHISHING DETECTADO!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hemos bloqueado una amenaza potencial en tiempo real para proteger tu información.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade100,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sección de Estadísticas o Módulos
                const Text(
                  'Estado del Sistema',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),

                // Rejilla de módulos adaptativa
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isLandscape ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    _buildStatusCard('Malware', '0 Detectados', Icons.bug_report, Colors.greenAccent),
                    _buildStatusCard('Red Wi-Fi', 'Segura', Icons.wifi, Colors.blueAccent),
                    _buildStatusCard('Análisis', 'Completo', Icons.analytics, Colors.purpleAccent),
                    _buildStatusCard('Protección', '100%', Icons.verified_user, Colors.orangeAccent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, String status, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Gris azulado oscuro
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.slate.shade800),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.slate300, fontWeight: FontWeight.bold, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            status,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}