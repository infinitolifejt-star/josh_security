// ====================================================================================================
// ARCHIVO: lib/services/ai_threat_service.dart
// SERVICIO EVALUADOR DE AMENAZAS CON IA Y HEURÍSTICA LOCAL - JOSH SECURITY v6.0
// ====================================================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/phone_threat_intelligence.dart';
import 'security/database_repository.dart';

class AiThreatService {
  final DatabaseRepository _dbRepo = DatabaseRepository.instance;

  // Endpoint de producción en Render Cloud
  static const String _backendUrl = 'https://josh-security.onrender.com/scan';

  /// Examina un número entrante calculando riesgo heurístico local y enriqueciendo vía backend
  Future<PhoneThreatIntelligence> evaluatePhoneNumber(String rawPhone) async {
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[\s\-()+]'), '');
    final timestamp = DateTime.now();

    // 1. Heurística Local Preventiva (Offline-First)
    double localRisk = 0.0;
    List<String> reasons = [];
    bool isVoip = false;
    bool recentAbuse = false;

    if (cleanPhone.contains('8888888888') || _hasRepeatingPattern(cleanPhone)) {
      localRisk = 95.0;
      recentAbuse = true;
      reasons.add('Patrón numérico iterativo o secuencia sospechosa');
    } else if (cleanPhone.startsWith('4470') ||
        cleanPhone.startsWith('234') ||
        cleanPhone.startsWith('1888')) {
      localRisk = 85.0;
      isVoip = true;
      recentAbuse = true;
      reasons.add('Prefijo internacional asociado a pasarelas VoIP desprotegidas');
    } else if (cleanPhone.length >= 3 && cleanPhone.length <= 6) {
      localRisk = 25.0;
      reasons.add('Mensajería en masa o código corto corporativo');
    }

    // 2. Consulta remota al Backend (Si hay red disponible)
    try {
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'target': cleanPhone,
          'type': 'SPAM / BOTS',
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final remoteThreat = PhoneThreatIntelligence.fromJson(data);

        // Guardar en la base de datos local SQLite
        await _dbRepo.saveThreatIntelligence(remoteThreat);
        return remoteThreat;
      }
    } catch (_) {
      // Fallback a evaluación offline si el backend o la red fallan
    }

    // Fallback con evaluación local
    String verdict = "SIN_AMENAZAS";
    String statusLabel = "🟢 SIN AMENAZAS DETECTADAS";

    if (localRisk >= 80.0) {
      verdict = "AMENAZA_CONFIRMADA";
      statusLabel = "🔴 ALTO RIESGO / AMENAZA";
    } else if (localRisk >= 40.0) {
      verdict = "ADVERTENCIA";
      statusLabel = "🟡 ADVERTENCIA DE RIESGO";
    }

    if (reasons.isEmpty) {
      reasons.add('Evaluación local sin anomalías registradas');
    }

    final localResult = PhoneThreatIntelligence(
      phoneNumber: rawPhone,
      riskScore: localRisk,
      ipqsScore: localRisk,
      verdict: verdict,
      statusLabel: statusLabel,
      confidence: "OFFLINE",
      isVoip: isVoip,
      recentAbuse: recentAbuse,
      carrier: "Análisis Local",
      reasons: reasons,
      timestamp: timestamp,
    );

    await _dbRepo.saveThreatIntelligence(localResult);
    return localResult;
  }

  bool _hasRepeatingPattern(String phone) {
    if (phone.isEmpty) return false;
    final firstChar = phone[0];
    return phone.split('').every((char) => char == firstChar);
  }
}
