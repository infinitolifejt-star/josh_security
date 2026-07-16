import 'package:flutter/material.dart';

class ProactiveShieldsMonitor extends StatelessWidget {
  final int linksChecked;
  final int callsChecked;
  final int malwarePrevented;

  const ProactiveShieldsMonitor({
    super.key,
    required this.linksChecked,
    required this.callsChecked,
    required this.malwarePrevented,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A506B).withAlpha((0.5 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Color(0xFF5BC0BE), size: 14),
              const SizedBox(width: 8),
              Text(
                "MONITOR DE ESCUDOS EN TIEMPO REAL",
                style: TextStyle(
                  color: Colors.blueGrey[200],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("ENLACES", linksChecked, Icons.link, Colors.blue),
              _buildStatItem("LLAMADAS", callsChecked, Icons.phone, Colors.orange),
              _buildStatItem("PREVENIDO", malwarePrevented, Icons.gpp_good, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color.withAlpha((0.8 * 255).round()), size: 18),
        const SizedBox(height: 4),
        Text(
          "$value",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.blueGrey[400],
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}