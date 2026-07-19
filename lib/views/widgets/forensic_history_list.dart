// ====================================================================================================
// ARCHIVO: lib/views/widgets/forensic_history_list.dart
// REEMPLAZO TOTAL — ENTORNO SÍNCRONIZADO CENTINELA v4.5.1
// OP-HEURÍSTICA: Interfaz de Bitácora Conectada a Persistencia Reactiva del Provider
// ====================================================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/security_provider.dart';

class ForensicHistoryList extends StatelessWidget {
  final VoidCallback onClear;

  const ForensicHistoryList({
    super.key,
    required this.onClear,
  });

  /// Traduce los esquemas de base de datos a los parámetros visuales del HUD
  double _calculateHeuristicScore(String verdict) {
    switch (verdict.toUpperCase()) {
      case 'AMENAZA_BLOQUEADA_PREVENTIVAMENTE':
      case 'CRÍTICO':
        return 85.0; // Estado crítico (Rojo)
      case 'SUGERENCIA_REVISAR_ALERTAS':
      case 'ADVERTENCIA':
        return 45.0; // Advertencia de seguridad (Amarillo)
      case 'SISTEMA_OPERATIVO_SEGURO':
      case 'CONFIABLE':
      default:
        return 0.0;  // Sistema íntegro (Verde)
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios del proveedor de seguridad de forma reactiva
    final securityProvider = Provider.of<SecurityProvider>(context);
    
    // Obtenemos los registros históricos cacheados en el estado global
    final List<Map<String, dynamic>> dbLogs = securityProvider.historicalLogs;

    Color getCardColor(double score) {
      if (score >= 70) return const Color(0xFFFF5252);
      if (score >= 35) return const Color(0xFFFFD740);
      return const Color(0xFF00E676);
    }

    IconData getCardIcon(double score) {
      if (score >= 70) return Icons.gpp_bad_outlined;
      if (score >= 35) return Icons.report_problem_outlined;
      return Icons.verified_user_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111A35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2541)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_toggle_off, color: Color(0xFF5BC0BE), size: 16),
                  SizedBox(width: 8),
                  Text(
                    "BITÁCORA INTEGRAL DE RESGUARDO",
                    style: TextStyle(
                      color: Color(0xFF5BC0BE),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              if (dbLogs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFFF5252), size: 20),
                  tooltip: "Limpiar Consola HUD",
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: onClear,
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFF1C2541), thickness: 1.5),
          ),
          dbLogs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      "No hay registros de amenazas en la persistencia local SQLite.",
                      style: TextStyle(
                        color: Colors.blueGrey[500],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dbLogs.length,
                  itemBuilder: (context, index) {
                    final rawItem = dbLogs[index];

                    final String verdict = rawItem['verdict'] ?? 'CONFIABLE';
                    final double score = _calculateHeuristicScore(verdict);
                    final String vector = (rawItem['service'] ?? 'CENTINELA').toUpperCase();
                    final String target = rawItem['activity'] ?? 'Análisis de perímetro';
                    final String timestamp = rawItem['timestamp'] ?? '';
                    final Color cardColor = getCardColor(score);

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2541),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardColor.withAlpha((0.2 * 255).round())),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: cardColor.withAlpha((0.1 * 255).round()),
                          child: Icon(
                            getCardIcon(score),
                            color: cardColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          target,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "$vector • $timestamp",
                            style: TextStyle(
                              color: Colors.blueGrey[300],
                              fontSize: 10,
                            ),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              score > 0 ? "${score.toStringAsFixed(1)}%" : "OK",
                              style: TextStyle(
                                color: cardColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              verdict.toUpperCase(),
                              style: TextStyle(
                                color: cardColor.withAlpha((0.7 * 255).round()),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}