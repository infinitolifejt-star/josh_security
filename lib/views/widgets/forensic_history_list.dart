// ====================================================================================================
// ARCHIVO: lib/views/widgets/forensic_history_list.dart
// CORRECCIÓN: Corrección de Overflow, Scroll Independiente y reemplazo de Container por SizedBox
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

  double _calculateHeuristicScore(Map<String, dynamic> rawItem) {
    if (rawItem['score'] != null) {
      return (rawItem['score'] as num).toDouble();
    }
    if (rawItem['agentRiskScore'] != null) {
      return (rawItem['agentRiskScore'] as num).toDouble();
    }

    final String verdict = (rawItem['verdict'] ?? rawItem['risk_level'] ?? 'CONFIABLE')
        .toString()
        .toUpperCase();

    switch (verdict) {
      case 'AMENAZA_BLOQUEADA_PREVENTIVAMENTE':
      case 'CRÍTICO':
      case 'PELIGRO':
        return 85.0;
      case 'SUGERENCIA_REVISAR_ALERTAS':
      case 'ADVERTENCIA':
      case 'SOSPECHOSO':
        return 45.0;
      case 'SISTEMA_OPERATIVO_SEGURO':
      case 'CONFIABLE':
      case 'SEGURO':
      default:
        return 0.0;
    }
  }

  void _mostrarDetalleForense(BuildContext context, Map<String, dynamic> item, double score, String verdict) {
    final String target = (item['target'] ?? item['activity'] ?? item['url'] ?? item['phoneNumber'] ?? 'Análisis de perímetro').toString();
    final String timestamp = (item['timestamp'] ?? item['scanned_at'] ?? 'Sin fecha').toString();
    final String reasoning = (item['agentReasoning'] ?? item['reason'] ?? 'Evaluación estándar del motor de seguridad').toString();
    final String vector = (item['vector'] ?? item['service'] ?? 'SEGURIDAD').toString().toUpperCase();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111A35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1C2541)),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF5BC0BE)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detalle de Inspección',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('OBJETIVO / VECTOR', style: TextStyle(color: Color(0xFF5BC0BE), fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(
                target,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RIESGO ESTRUCTURAL', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                      Text(
                        '${score.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: score >= 70
                              ? const Color(0xFFFF5252)
                              : (score >= 35 ? const Color(0xFFFFD740) : const Color(0xFF00E676)),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('VEREDICTO', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                      Text(
                        verdict,
                        style: TextStyle(
                          color: score >= 70
                              ? const Color(0xFFFF5252)
                              : (score >= 35 ? const Color(0xFFFFD740) : const Color(0xFF00E676)),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('FECHA Y HORA', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
              Text('$vector • $timestamp', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('RAZONAMIENTO AGÉNTICO / EVIDENCIA', style: TextStyle(color: Color(0xFF5BC0BE), fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1326),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1C2541)),
                ),
                child: Text(
                  reasoning,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CERRAR', style: TextStyle(color: Color(0xFF5BC0BE))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final securityProvider = Provider.of<SecurityProvider>(context);
    final List<Map<String, dynamic>> dbLogs = securityProvider.historicalLogs;

    Color getCardColor(double score) {
      if (score >= 70) return const Color(0xFFFF5252);
      if (score >= 35) return const Color(0xFFFFD740);
      return const Color(0xFF00E676);
    }

    IconData getCardIcon(double score, String vector) {
      if (vector.contains('TEL') || vector.contains('PHONE') || vector.contains('CALL')) {
        return Icons.phone_in_talk_outlined;
      } else if (vector.contains('URL') || vector.contains('LINK') || vector.contains('PHISHING')) {
        return Icons.link_rounded;
      } else if (vector.contains('MALWARE') || vector.contains('BIN')) {
        return Icons.security_rounded;
      }

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
        mainAxisSize: MainAxisSize.min,
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
                  tooltip: "Limpiar Bitácora Local",
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    await securityProvider.clearMasterBitacora();
                    onClear();
                  },
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
                      "No hay registros de auditoría en la bitácora local.",
                      style: TextStyle(
                        color: Colors.blueGrey[500],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 300, // Altura contenida para el área deslizable
                  child: ListView.builder(
                    shrinkWrap: false,
                    physics: const AlwaysScrollableScrollPhysics(), // Permite scroll suave en la bitácora
                    itemCount: dbLogs.length,
                    itemBuilder: (context, index) {
                      final rawItem = dbLogs[index];

                      final String verdict = (rawItem['verdict'] ?? rawItem['risk_level'] ?? 'CONFIABLE').toString();
                      final double score = _calculateHeuristicScore(rawItem);
                      final String vector = (rawItem['vector'] ?? rawItem['service'] ?? 'SEGURIDAD').toString().toUpperCase();
                      final String target = (rawItem['target'] ?? rawItem['activity'] ?? rawItem['url'] ?? rawItem['phoneNumber'] ?? 'Análisis de perímetro').toString();
                      final String timestamp = (rawItem['timestamp'] ?? rawItem['scanned_at'] ?? '').toString();
                      final Color cardColor = getCardColor(score);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2541),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardColor.withValues(alpha: 0.2)),
                        ),
                        child: InkWell(
                          onTap: () => _mostrarDetalleForense(context, rawItem, score, verdict),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: cardColor.withValues(alpha: 0.1),
                                child: Icon(
                                  getCardIcon(score, vector),
                                  color: cardColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      target,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      timestamp.isNotEmpty ? "$vector • $timestamp" : vector,
                                      style: TextStyle(
                                        color: Colors.blueGrey[300],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cardColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      verdict.length > 10 ? '${verdict.substring(0, 9)}...' : verdict.toUpperCase(),
                                      style: TextStyle(
                                        color: cardColor,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
