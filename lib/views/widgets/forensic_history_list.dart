// ====================================================================================================
// ARCHIVO: lib/views/widgets/forensic_history_list.dart
// COMPONENTE: Lista de Historial Forense Universal JOSH (Blindado para Multi-Motor)
// ====================================================================================================

import 'dart:async';
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
  late Future<List<Map<String, dynamic>>> _unifiedHistoryFuture;
  StreamSubscription? _callLogSubscription;

  @override
  void initState() {
    super.initState();
    _refreshHistory();
    _subscribeToLiveEvents();
  }

  @override
  void dispose() {
    _callLogSubscription?.cancel();
    super.dispose();
  }

  /// Escucha cambios en tiempo real desde PhoneInterceptorService
  void _subscribeToLiveEvents() {
    _callLogSubscription = PhoneInterceptorService().onCallLogUpdated.listen((_) {
      if (mounted) {
        _refreshHistory();
      }
    });
  }

  void _refreshHistory() {
    setState(() {
      _unifiedHistoryFuture = _loadUnifiedHistory();
    });
  }

  double _extractRiskFromForensicLog(Map<String, dynamic> log) {
    // 1. Intentar extraer directo de campos raíz
    final dynamic rootScore = log['risk_score'] ?? log['score'] ?? log['fraud_score'] ?? log['threat_level'];
    if (rootScore != null && rootScore is num) {
      final double val = rootScore.toDouble();
      return val > 1.0 ? val / 100.0 : val;
    }

    // 2. Extracción desde extra_data
    final String? extraDataStr = log['extra_data']?.toString();
    if (extraDataStr != null && extraDataStr.isNotEmpty) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(extraDataStr);
        final dynamic val = parsed['score'] ??
                            parsed['risk_score'] ??
                            parsed['fraud_score'] ??
                            parsed['threat_level'] ??
                            parsed['risk'];
        if (val != null && val is num) {
          final double parsedScore = val.toDouble();
          return parsedScore > 1.0 ? parsedScore / 100.0 : parsedScore;
        }
      } catch (_) {}
    }

    // 3. Fallback basado en veredicto
    final String verdict = (log['verdict'] ?? log['status'] ?? log['action'] ?? '').toString().toUpperCase();
    if (verdict.contains('PELIGRO') ||
        verdict.contains('MALICIOSO') ||
        verdict.contains('MALWARE') ||
        verdict.contains('PHISHING') ||
        verdict.contains('CRÍTICO')) {
      return 0.9;
    }
    if (verdict.contains('SOSPECHOSO') ||
        verdict.contains('ADVERTENCIA') ||
        verdict.contains('ALERTA')) {
      return 0.5;
    }
    if (verdict.contains('LIMPIO') ||
        verdict.contains('SEGURO') ||
        verdict.contains('PERMITIDO')) {
      return 0.0;
    }

    return 0.2;
  }

  int _parseTimestampToMs(dynamic rawTimestamp) {
    if (rawTimestamp == null) return 0;

    if (rawTimestamp is int) {
      return rawTimestamp < 10000000000 ? rawTimestamp * 1000 : rawTimestamp;
    }

    if (rawTimestamp is num) {
      final int val = rawTimestamp.toInt();
      return val < 10000000000 ? val * 1000 : val;
    }

    final String str = rawTimestamp.toString().trim();
    if (str.isEmpty) return 0;

    final int? parsedInt = int.tryParse(str);
    if (parsedInt != null) {
      return parsedInt < 10000000000 ? parsedInt * 1000 : parsedInt;
    }

    final DateTime? parsedDate = DateTime.tryParse(str);
    if (parsedDate != null) return parsedDate.millisecondsSinceEpoch;

    return 0;
  }

  String _formatDateTime(dynamic rawTimestamp) {
    final int ms = _parseTimestampToMs(rawTimestamp);
    if (ms == 0) return 'Fecha no registrada';

    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final String day = dt.day.toString().padLeft(2, '0');
    final String month = dt.month.toString().padLeft(2, '0');
    final String year = dt.year.toString();

    final int hourInt = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final String hour = hourInt.toString().padLeft(2, '0');
    final String minute = dt.minute.toString().padLeft(2, '0');
    final String period = dt.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year - $hour:$minute $period';
  }

  Future<List<Map<String, dynamic>>> _loadUnifiedHistory() async {
    final List<Map<String, dynamic>> formattedCalls = [];

    // 1. Obtener llamadas de SQLite local
    try {
      final List<Map<String, dynamic>> dbCalls =
          await DatabaseService.instance.getCallHistory();
      for (final c in dbCalls) {
        final double score = (c['risk_score'] as num?)?.toDouble() ?? 0.0;
        final double normalizedScore = score > 1.0 ? score / 100.0 : score;

        formattedCalls.add(<String, dynamic>{
          'title': c['phone_number'] ?? c['number'] ?? 'Desconocido',
          'subtitle':
              'Riesgo: ${(normalizedScore * 100).toInt()}% | Veredicto: ${c['verdict'] ?? 'ANALIZADO'}',
          'type': 'LLAMADA',
          'rawScore': normalizedScore,
          'timestamp': c['timestamp'] ?? c['created_at'] ?? c['date'],
        });
      }
    } catch (_) {}

    // 2. Fallback a llamadas nativas si SQLite local no arrojó llamadas
    if (formattedCalls.isEmpty) {
      try {
        final List<Map<String, dynamic>> nativeCalls =
            await PhoneInterceptorService.getNativeCallHistory();
        for (final c in nativeCalls) {
          final double score = (c['riskScore'] as num?)?.toDouble() ?? 0.0;
          final double normalizedScore = score > 1.0 ? score / 100.0 : score;

          formattedCalls.add(<String, dynamic>{
            'title': c['phoneNumber'] ?? c['number'] ?? 'Desconocido',
            'subtitle':
                'Riesgo: ${(normalizedScore * 100).toInt()}% | Estado: ${c['status'] ?? 'ANALIZADO'}',
            'type': 'LLAMADA',
            'rawScore': normalizedScore,
            'timestamp': c['timestamp'] ?? c['date'],
          });
        }
      } catch (_) {}
    }

    // 3. Cargar Logs Forenses (Phishing, Escaneo de Archivos, APKs, etc.)
    try {
      final List<Map<String, dynamic>> forensicLogs =
          await DatabaseService.instance.getForensicLogs();

      final List<Map<String, dynamic>> formattedLogs = forensicLogs.map((l) {
        final double normalizedScore = _extractRiskFromForensicLog(l);
        final int riskPercentage = (normalizedScore * 100).toInt();

        final String service = (l['service'] ?? l['type'] ?? l['source'] ?? '').toString();
        final String activity = (l['activity'] ?? l['action'] ?? l['url'] ?? l['file_name'] ?? 'Auditoría perimetral').toString();

        String typeLabel = 'ANÁLISIS';
        if (service.toUpperCase().contains('PHISHING') || activity.toUpperCase().contains('HTTP')) {
          typeLabel = 'PHISHING';
        } else if (service.toUpperCase().contains('FILE') ||
                   service.toUpperCase().contains('APK') ||
                   activity.toLowerCase().endsWith('.apk')) {
          typeLabel = 'MALWARE';
        } else if (service.isNotEmpty) {
          typeLabel = service.toUpperCase();
        }

        return <String, dynamic>{
          'title': activity,
          'subtitle':
              'Riesgo: $riskPercentage% | Veredicto: ${l['verdict'] ?? l['status'] ?? 'INSPECCIONADO'}',
          'type': typeLabel,
          'rawScore': normalizedScore,
          'timestamp': l['timestamp'] ?? l['created_at'] ?? l['date'],
        };
      }).toList();

      // 4. Fusionar y ordenar
      final List<Map<String, dynamic>> combined = [
        ...formattedCalls,
        ...formattedLogs
      ];

      combined.sort((a, b) {
        final int timeA = _parseTimestampToMs(a['timestamp']);
        final int timeB = _parseTimestampToMs(b['timestamp']);
        return timeB.compareTo(timeA);
      });

      return combined;
    } catch (_) {
      return formattedCalls;
    }
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

    if (!mounted) return;

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      widget.onClear?.call();
      await PhoneInterceptorService.clearNativeCallHistory();
      await DatabaseService.instance.clearAllLogs();
      await DatabaseService.instance.clearForensicLogs();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _refreshHistory();

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
    final securityProvider =
        Provider.of<SecurityProvider>(context, listen: false);

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
            future: _unifiedHistoryFuture,
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

              if (snapshot.hasError) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFE63946),
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error al cargar la bitácora forense',
                        style: TextStyle(
                          color: Colors.blueGrey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                  final double rawScore =
                      (record['rawScore'] as num?)?.toDouble() ?? 0.0;
                  final String title = record['title'] ?? 'Evento Forense';
                  final String subtitle = record['subtitle'] ?? '';
                  final String type = record['type'] ?? 'AUDITORÍA';
                  final String formattedDate =
                      _formatDateTime(record['timestamp']);
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.blueGrey[300],
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📅 $formattedDate',
                          style: const TextStyle(
                            color: Color(0xFF5BC0BE),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
