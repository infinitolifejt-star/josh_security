import 'package:flutter/material.dart';

class ForensicHistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> masterBitacora;
  final VoidCallback onClear;

  const ForensicHistoryList({
    super.key,
    required this.masterBitacora,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
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
              if (masterBitacora.isNotEmpty)
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
          masterBitacora.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      "No hay registros de amenazas en la sesión activa.",
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
                  itemCount: masterBitacora.length,
                  itemBuilder: (context, index) {
                    final item = masterBitacora[index];
                    final double score = (item['score'] as num?)?.toDouble() ?? 0.0;
                    final String vector = item['vector'] ?? 'GENERAL';
                    final String verdict = (item['verdict'] ?? 'ANALIZADO').toUpperCase();
                    
                    Color cardColor = const Color(0xFF00E676);
                    if (score >= 70) {
                      cardColor = const Color(0xFFFF5252);
                    } else if (score >= 35) {
                      cardColor = const Color(0xFFFFD740);
                    }

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
                            score >= 70 
                              ? Icons.gpp_bad_outlined 
                              : (score >= 35 ? Icons.report_problem_outlined : Icons.verified_user_outlined),
                            color: cardColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item['target'] ?? 'Desconocido',
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
                            "$vector • ${item['timestamp']}",
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
                              "${score.toStringAsFixed(1)}%",
                              style: TextStyle(
                                color: cardColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              verdict,
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