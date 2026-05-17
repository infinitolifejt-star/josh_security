import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text(
          'JOSH SECURITY - CENTRAL DE OPERACIONES', 
          style: TextStyle(fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.blueAccent)
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.gpp_good, color: Colors.greenAccent, size: 20),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 60, color: Color(0xFF2563EB)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CENTINELA DIGITAL SECURITY",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Ecosistema Modular de Defensa • Licencia Activa",
                            style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "MÓDULOS DEL SISTEMA CENTINELA",
                style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _buildMenuCard(
                    context: context,
                    title: "ANÁLISIS PROACTIVO",
                    subtitle: "Escáner híbrido con VirusTotal & Google Safe Browsing Engine",
                    icon: Icons.radar,
                    color: const Color(0xFF2563EB),
                    route: '/analysis',
                    isActive: true,
                  ),
                  _buildMenuCard(
                    context: context,
                    title: "CONCIENTIZACIÓN / PILAR 2",
                    subtitle: "Simulador táctico de Ingeniería Social y Phishing Educativo",
                    icon: Icons.model_training,
                    color: Colors.purpleAccent,
                    route: '/simulation', // Ruta activada con éxito
                    isActive: true, // ¡Módulo desbloqueado!
                  ),
                  _buildMenuCard(
                    context: context,
                    title: "REGISTRO DE INCIDENTES",
                    subtitle: "Historial centralizado de firmas bloqueadas y logs locales",
                    icon: Icons.assignment,
                    color: Colors.tealAccent,
                    route: '#',
                    isActive: false,
                  ),
                  _buildMenuCard(
                    context: context,
                    title: "ESTADO DE LAS APIS",
                    subtitle: "Verificación de credenciales en la nube y latencia del backend",
                    icon: Icons.hub,
                    color: Colors.amberAccent,
                    route: '#',
                    isActive: false,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "PYTHON CORE: ONLINE (PORT 5000)",
                          style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const Text(
                      "V1.0.0-STABLE",
                      style: TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
    required bool isActive,
  }) {
    return InkWell(
      onTap: () {
        if (isActive && route != '#') {
          Navigator.pushNamed(context, route);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Módulo $title en desarrollo para la siguiente fase táctica.",
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              backgroundColor: const Color(0xFF0F172A),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? color.withOpacity(0.3) : const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isActive ? color : Colors.white24, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white38, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 13,
                      letterSpacing: 0.5
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 10, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isActive ? Icons.arrow_forward_ios : Icons.lock_outline, 
              color: isActive ? Colors.white38 : Colors.white10, 
              size: 14
            ),
          ],
        ),
      ),
    );
  }
}