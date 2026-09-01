// ====================================================================================================
// ARCHIVO: lib/views/widgets/forensic_history_list.dart
// COMPONENTE: Lista de Historial Forense JOSH
// OPERACIÓN: Renderizado de registros de auditoría y llamadas procesadas en tiempo real
// ====================================================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/security_provider.dart';
import '../../services/security/phone_interceptor_service.dart';

class ForensicHistoryList extends StatefulWidget {
  final VoidCallback? onClear;

  const ForensicHistoryList({
    super.key,
    this.onClear,
  });

  @override
  State<ForensicHistoryList> createState() => _ForensicHistoryListState();
}

class _ForensicHistoryListState extends State<ForensicHistoryList> {
  bool _isLoadingNativeLogs = false;

  Future<void> _handleClearAll(SecurityProvider provider) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2541),
          title: const Text(
            'LIMPIAR HISTORIAL FORENSE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '¿Desea eliminar de forma permanente la bitácora local y los registros de llamadas analizadas por JOSH?',
            style: TextStyle(
              color: Colors.blueGrey,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              child: const Text(
                'CANCELAR',
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
                foregroundColor: Colors.white,
              ),
              child: const Text('ELIMINAR TODO'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isLoadingNativeLogs = true;
      });

      // 1. Limpiar la bitácora visual y provider
      widget.onClear?.call();

      // 2. Limpiar base de datos nativa SQLite a través del servicio
      await PhoneInterceptorService.clearNativeCallHistory();

      if (mounted) {
        setState(() {
          _isLoadingNativeLogs = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Historial forense purgado correctamente.'),
            backgroundColor: Color(0xFF1C2541),
          ),
        );
      }
    }
  }

  Color _getRiskColor(double score) {
    if (score >= 0.7) return const Color(0xFFE63946); // Amenaza Alta / Crítica
    if (score >= 0.4) return const Color(0xFFFFB703); // Sospechoso / Medio
    return const Color(0xFF2ECC71); // Limpio / Seguro
  }

  IconData _getRiskIcon(double score) {
    if (score >= 0.7) return Icons.gpp_bad_rounded;
    if (score >= 0.4) return Icons.warning_amber_rounded;
    return Icons.verified_user_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final securityProvider = Provider.of<SecurityProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1C2541),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    color: Color(0xFF5BC0BE),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'HISTORIAL DE AUDITORÍAS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (_isLoadingNativeLogs)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF5BC0BE),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    color: Color(0xFFE63946),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Limpiar Todo',
                  onPressed: () => _handleClearAll(securityProvider),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(
            color: Color(0xFF1C2541),
            height: 1,
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: PhoneInterceptorService.getNativeCallHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF5BC0BE),
                    ),
                  ),
                );
              }

              final nativeRecords = snapshot.data ?? [];

              if (nativeRecords.isEmpty && securityProvider.forensicLogs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.blueGrey[600],
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sin registros forenses almacenados',
                        style: TextStyle(
                          color: Colors.blueGrey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: nativeRecords.length,
                separatorBuilder: (context, index) => const Divider(
                  color: Color(0xFF1C2541),
                  height: 12,
                ),
                itemBuilder: (context, index) {
                  final record = nativeRecords[index];
                  final double riskScore = (record['riskScore'] as num?)?.toDouble() ?? 0.0;
                  final String number = record['phoneNumber'] ?? 'Desconocido';
                  final String status = record['status'] ?? 'ANALIZADO';
                  final Color riskColor = _getRiskColor(riskScore);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: riskColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        _getRiskIcon(riskScore),
                        color: riskColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    subtitle: Text(
                      'Riesgo: ${(riskScore * 100).toInt()}% | Estado: $status',
                      style: TextStyle(
                        color: Colors.blueGrey[300],
                        fontSize: 11,
                      ),
                    ),
                    trailing: Text(
                      record['type'] ?? 'LLAMADA',
                      style: TextStyle(
                        color: riskColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
