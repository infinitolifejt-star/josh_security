// ====================================================================================================
// ARCHIVO: lib/views/widgets/forensic_history_list.dart
// COMPONENTE: Lista de Historial Forense Universal JOSH
// OPERACIÓN: Renderizado unificado (Llamadas, Phishing, Archivos/APK)
// ====================================================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/security_provider.dart';
import '../../services/security/database_service.dart';
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
  bool _isLoading = false;

  double _extractRiskFromForensicLog(Map<String, dynamic> log) {
    // 1. Intentar obtener el score directamente si viene en extra_data (JSON)
    final String? extraDataStr = log['extra_data']?.toString();
    if (extraDataStr != null && extraDataStr.isNotEmpty) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(extraDataStr);
        if (parsed.containsKey('score') || parsed.containsKey('risk_score') || parsed.containsKey('fraud_score')) {
          final dynamic val = parsed['score'] ?? parsed['risk_score'] ?? parsed['fraud_score'];
          final double parsedScore = (val as num).toDouble();
          return parsedScore > 1.0 ? parsedScore / 100.0 : parsedScore;
        }
      } catch (_) {
        // Ignorar si extra_data no es JSON válido
      }
    }

    // 2. Fallback según el veredicto
    final String verdict = (log['verdict'] ?? '').toString().toUpperCase();
    if (verdict.contains('PELIGRO') || verdict.contains('MALICIOSO') || verdict.contains('MALWARE') || verdict.contains('CRÍTICO')) {
      return 0.9;
    }
    if (verdict.contains('SOSPECHOSO') || verdict.contains('ADVERTENCIA') || verdict.contains('ALERTA')) {
      return 0.5;
    }
    if (verdict.contains('LIMPIO') || verdict.contains('SEGURO') || verdict.contains('PERMITIDO')) {
      return 0.0;
    }

    return 0.2; // Seguro por defecto
  }

  Future<List<Map<String, dynamic>>> _loadUnifiedHistory() async {
    // 1. Cargar Llamadas Nativas
    final List<Map<String, dynamic>> nativeCalls = await PhoneInterceptorService.getNativeCallHistory();
    final List<Map<String, dynamic>> formattedCalls = nativeCalls.map((c) {
      final double score = (c['riskScore'] as num?)?.toDouble() ?? 0.0;
      final double normalizedScore = score > 1.0 ? score / 100.0 : score;

      return <String, dynamic>{
        'title': c['phoneNumber'] ?? 'Desconocido',
        'subtitle': 'Riesgo: ${(normalizedScore * 100).toInt()}% | Estado: ${c['status'] ?? 'ANALIZADO'}',
        'type': 'LLAMADA',
        'rawScore': normalizedScore,
        'timestamp': c['timestamp']?.toString() ?? '',
      };
    }).toList();

    // 2. Cargar Logs Forenses (Phishing, Escaneo de Archivos)
    final List<Map<String, dynamic>> forensicLogs = await DatabaseService.instance.getForensicLogs();
    final List<Map<String, dynamic>> formattedLogs = forensicLogs.map((l) {
      final double normalizedScore = _extractRiskFromForensicLog(l);
      final int riskPercentage = (normalizedScore * 100).toInt();

      final String service = l['service']?.toString() ?? '';
      String typeLabel = 'ANÁLISIS';
      if (service.contains('Phishing')) typeLabel = 'PHISHING';
      if (service.contains('FileScanner') || service.contains('Apk')) typeLabel = 'MALWARE';

      return <String, dynamic>{
        'title': l['activity'] ?? 'Auditoría perimetral',
        'subtitle': 'Riesgo: $riskPercentage% | Veredicto: ${l['verdict'] ?? 'INSPECCIONADO'}',
        'type': typeLabel,
        'rawScore': normalizedScore,
        'timestamp': l['timestamp']?.toString() ?? '',
      };
    }).toList();

    // 3. Fusionar y ordenar por fecha (más recientes primero)
    final List<Map<String, dynamic>> combined = [...formattedCalls, ...formattedLogs];
    combined.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));

    return combined;
  }

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
        _isLoading = true;
      });

      widget.onClear?.call();
      await PhoneInterceptorService.clearNativeCallHistory();
      await DatabaseService.instance.clearForensicLogs();

      if (mounted) {
        setState(() {
          _isLoading = false;
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
    if (score >= 0.7) return const Color(0xFFE63946);
    if (score >= 0.4) return const Color(0xFFFFB703);
    return const Color(0xFF2ECC71);
  }

  IconData _getRiskIcon(double score, String type) {
    if (type == 'PHISHING') return Icons.link_off_rounded;
    if (type == 'MALWARE') return Icons.bug_report_rounded;
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
              if (_isLoading)
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
            future: _loadUnifiedHistory(),
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

              final records = snapshot.data ?? [];

              if (records.isEmpty) {
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
                itemCount: records.length,
                separatorBuilder: (context, index) => const Divider(
                  color: Color(0xFF1C2541),
                  height: 12,
                ),
                itemBuilder: (context, index) {
                  final record = records[index];
                  final double rawScore = (record['rawScore'] as num).toDouble();
                  final String title = record['title'] ?? 'Evento Forense';
                  final String subtitle = record['subtitle'] ?? '';
                  final String type = record['type'] ?? 'AUDITORÍA';
                  final Color riskColor = _getRiskColor(rawScore);

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
                        _getRiskIcon(rawScore, type),
                        color: riskColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.blueGrey[300],
                        fontSize: 11,
                      ),
                    ),
                    trailing: Text(
                      type,
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
