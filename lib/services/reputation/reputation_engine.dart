// ====================================================================================================
// ARCHIVO: lib/services/reputation/reputation_engine.dart
// COMPONENTE: Motor de Reputación Centinela (Google Safe Browsing + VirusTotal API) v4.6
// ====================================================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ReputationEngine {
  // Acceso seguro a las variables de entorno
  String get _virusTotalApiKey => dotenv.env['VIRUSTOTAL_API_KEY'] ?? '';
  String get _safeBrowsingApiKey => dotenv.env['GOOGLE_SAFE_BROWSING_API_KEY'] ?? '';

  /// 1. Computa el Score de Riesgo final aplicando pesos ponderados (Escala 0.0 - 100.0)
  double computeRiskScore({
    required double entropy,
    required double frequency,
    required double timeRisk,
    required double durationRisk,
    required double communityScore,
  }) {
    // Calculamos el promedio ponderado recibiendo entradas en escala 0-100
    final double rawScore = (entropy * 0.25) +
        (frequency * 0.20) +
        (timeRisk * 0.20) +
        (durationRisk * 0.15) +
        (communityScore * 0.20);

    return rawScore.clamp(0.0, 100.0);
  }

  /// 2. Consulta Google Safe Browsing real
  /// Retorna [true] si la URL es MALICIOSA o sospechosa (Amenaza confirmada).
  Future<bool> checkUrlSafeBrowsing(String url) async {
    if (_safeBrowsingApiKey.isEmpty) return false;

    const String requestUrl = 'https://safebrowsing.googleapis.com/v4/threatMatches:find';
    final String fullUrl = '$requestUrl?key=$_safeBrowsingApiKey';

    final Map<String, dynamic> body = {
      "client": {"clientId": "josh-security", "clientVersion": "1.0.0"},
      "threatInfo": {
        "threatTypes": [
          "MALWARE", 
          "SOCIAL_ENGINEERING", 
          "UNWANTED_SOFTWARE", 
          "POTENTIALLY_HARMFUL_APPLICATION"
        ],
        "platformTypes": ["ANY_PLATFORM"],
        "threatEntryTypes": ["URL"],
        "threatEntries": [{"url": url}]
      }
    };

    try {
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        if (data.containsKey('matches') && data['matches'] != null) {
          final matchesList = data['matches'];
          if (matchesList is List && matchesList.isNotEmpty) {
            return true; 
          }
        }
        return false;
      }
    } catch (e) {
      debugPrint("Error o Timeout en Google Safe Browsing: $e");
    }
    return false;
  }

  /// 3. Consulta a VirusTotal (Puntaje devuelto entre 0.0 y 1.0)
  Future<double> checkVirusTotal(String target, {bool isUrl = false}) async {
    if (_virusTotalApiKey.isEmpty) return 0.0;

    final String targetId = isUrl 
        ? base64Url.encode(utf8.encode(target)).replaceAll('=', '') 
        : target;
        
    final String endpoint = isUrl 
        ? 'https://www.virustotal.com/api/v3/urls/$targetId' 
        : 'https://www.virustotal.com/api/v3/files/$targetId';

    try {
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'x-apikey': _virusTotalApiKey},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final Map<String, dynamic> stats = data['data']['attributes']['last_analysis_stats'];
        
        final int malicious = (stats['malicious'] as num?)?.toInt() ?? 0;
        final int suspicious = (stats['suspicious'] as num?)?.toInt() ?? 0;
        final int harmless = (stats['harmless'] as num?)?.toInt() ?? 1;
        final int total = malicious + suspicious + harmless;

        if (total == 0) return 0.0;
        return (malicious + suspicious) / total;
      }
    } catch (e) {
      debugPrint("Error o Timeout en VirusTotal: $e");
    }
    return 0.0;
  }

  /// 4. Integra el motor con los datos reales y devuelve un valor de 0.0 a 100.0
  Future<double> evaluateCompleteReputation({
    required String url,
    required double localHeuristicScore,
  }) async {
    final bool isGoogleThreat = await checkUrlSafeBrowsing(url);
    final double vtScoreRatio = await checkVirusTotal(url, isUrl: true);

    final double googleRiskScore = isGoogleThreat ? 100.0 : 0.0;
    final double vtRiskScore = (vtScoreRatio * 100.0).clamp(0.0, 100.0);

    // Combinación ponderada: 40% Heurística Local, 30% Safe Browsing, 30% VirusTotal
    final double combinedScore = (localHeuristicScore * 0.40) + 
                                (googleRiskScore * 0.30) + 
                                (vtRiskScore * 0.30);
                                
    return combinedScore.clamp(0.0, 100.0);
  }

  /// 5. Clasifica el nivel de amenaza estandarizado con la UI ('SEGURO', 'ADVERTENCIA', 'CRÍTICO')
  String classify(double score) {
    if (score < 30.0) return "SEGURO";
    if (score < 70.0) return "ADVERTENCIA";
    return "CRÍTICO";
  }
}