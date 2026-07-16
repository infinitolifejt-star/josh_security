// ====================================================================================================
// ARCHIVO: lib/services/reputation/reputation_engine.dart
// COMPONENTE: Motor de Reputación Centinela (Google Safe Browsing + VirusTotal API)
// ====================================================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../core/math_utils.dart';

class ReputationEngine {
  // Acceso seguro a las variables de entorno
  String get _virusTotalApiKey => dotenv.env['VIRUSTOTAL_API_KEY'] ?? '';
  String get _safeBrowsingApiKey => dotenv.env['GOOGLE_SAFE_BROWSING_API_KEY'] ?? '';

  /// 1. Computa el Score de Riesgo final aplicando pesos ponderados
  double computeRiskScore({
    required double entropy,
    required double frequency,
    required double timeRisk,
    required double durationRisk,
    required double communityScore,
  }) {
    final double rawScore = (entropy * 0.25) +
        (frequency * 0.20) +
        (timeRisk * 0.20) +
        (durationRisk * 0.15) +
        (communityScore * 0.20);

    return MathUtils.sigmoid(rawScore * 5.0);
  }

  /// 2. Consulta Google Safe Browsing real
  /// Retorna [true] si la URL es MALICIOSA o sospechosa (Amenaza confirmada).
  /// Retorna [false] si la URL está limpia o si la consulta falla (prevención de falsos positivos).
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
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // CORRECCIÓN DE LÓGICA DE RETORNO Y PARSEO SEGURO:
        // Si 'matches' existe en el JSON, es una lista y no está vacía, la URL es de riesgo confirmado.
        if (data.containsKey('matches') && data['matches'] != null) {
          final matchesList = data['matches'];
          if (matchesList is List && matchesList.isNotEmpty) {
            return true; 
          }
        }
        return false;
      }
    } catch (e) {
      debugPrint("Error crítico en Google Safe Browsing: $e");
    }
    return false;
  }

  /// 3. Consulta a VirusTotal con tipado estricto corregido
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
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final Map<String, dynamic> stats = data['data']['attributes']['last_analysis_stats'];
        
        // Conversión estricta de num a int para evitar errores de análisis
        final int malicious = (stats['malicious'] as num?)?.toInt() ?? 0;
        final int suspicious = (stats['suspicious'] as num?)?.toInt() ?? 0;
        final int harmless = (stats['harmless'] as num?)?.toInt() ?? 1;
        final int total = malicious + suspicious + harmless;

        return (malicious + suspicious) / total;
      }
    } catch (e) {
      debugPrint("Error en VirusTotal: $e");
    }
    return 0.0;
  }

  /// 4. Integra el motor con los datos reales
  Future<double> evaluateCompleteReputation({
    required String url,
    required double localHeuristicScore,
  }) async {
    bool isGoogleThreat = await checkUrlSafeBrowsing(url);
    double vtScore = await checkVirusTotal(url, isUrl: true);

    double googleRisk = isGoogleThreat ? 1.0 : 0.0;
    
    return (localHeuristicScore * 0.40) + (googleRisk * 0.30) + (vtScore * 0.30);
  }

  /// 5. Clasifica el nivel de amenaza
  String classify(double score) {
    if (score < 0.3) return "SEGURO";
    if (score < 0.6) return "SOSPECHOSO";
    return "CRÍTICO";
  }
}