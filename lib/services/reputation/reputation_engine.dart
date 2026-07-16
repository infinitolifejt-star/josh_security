import 'dart:convert';
import 'package:flutter/foundation.dart'; // Importado para corregir avoid_print usando debugPrint
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Para cargar las llaves de forma segura
import 'package:http/http.dart' as http;
import '../core/math_utils.dart';

class ReputationEngine {
  /// Obtiene de forma segura la API Key de VirusTotal desde el archivo .env
  String get _virusTotalApiKey => dotenv.env['VIRUSTOTAL_API_KEY'] ?? 'FALLBACK_KEY';

  /// Obtiene de forma segura la API Key de Google Safe Browsing desde el archivo .env
  String get _safeBrowsingApiKey => dotenv.env['GOOGLE_SAFE_BROWSING_API_KEY'] ?? 'FALLBACK_KEY';

  /// 1. Computa el Score de Riesgo final aplicando pesos ponderados y normalización Sigmoide
  double computeRiskScore({
    required double entropy,
    required double frequency,
    required double timeRisk,
    required double durationRisk,
    required double communityScore,
  }) {
    final double rawScore =
        (entropy * 0.25) +
        (frequency * 0.20) +
        (timeRisk * 0.20) +
        (durationRisk * 0.15) +
        (communityScore * 0.20);

    return MathUtils.sigmoid(rawScore * 5.0);
  }

  /// 2. Consulta Google Safe Browsing para verificar si una URL es de phishing o malware
  Future<bool> checkUrlSafeBrowsing(String url) async {
    // CORREGIDO: prefer_const_declarations resuelto usando 'const' en vez de 'final'
    const String requestUrl = 'https://safebrowsing.googleapis.com/v4/threatMatches:find';
    
    final String fullUrl = '$requestUrl?key=$_safeBrowsingApiKey';

    final Map<String, dynamic> body = {
      "client": {"clientId": "josh-security", "clientVersion": "1.0.0"},
      "threatInfo": {
        "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE", "POTENTIALLY_HARMFUL_APPLICATION"],
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
        final data = jsonDecode(response.body);
        return data.containsKey('matches') ? false : true;
      }
    } catch (e) {
      // CORREGIDO: avoid_print resuelto usando debugPrint de Flutter
      debugPrint("Error en Google Safe Browsing: $e");
    }
    return true; 
  }

  /// 3. Consulta a VirusTotal para obtener el score de reputación de un archivo (vía SHA-256) o una URL
  Future<double> checkVirusTotal(String target, {bool isUrl = false}) async {
    final String endpoint = isUrl 
        ? 'https://www.virustotal.com/api/v3/urls' 
        : 'https://www.virustotal.com/api/v3/files/$target';

    try {
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'x-apikey': _virusTotalApiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = data['data']['attributes']['last_analysis_stats'];
        
        final int malicious = stats['malicious'] ?? 0;
        final int suspicious = stats['suspicious'] ?? 0;
        final int harmless = stats['harmless'] ?? 1;
        final int total = malicious + suspicious + harmless;

        if (total > 0) {
          return (malicious + suspicious) / total;
        }
      }
    } catch (e) {
      // CORREGIDO: avoid_print resuelto usando debugPrint de Flutter
      debugPrint("Error en VirusTotal: $e");
    }
    return 0.0; 
  }

  /// 4. Integra el motor local con los datos en la nube para devolver un Score unificado
  Future<double> evaluateCompleteReputation({
    required String url,
    required double localHeuristicScore,
  }) async {
    bool isGoogleSafe = await checkUrlSafeBrowsing(url);
    double virusTotalScore = await checkVirusTotal(url, isUrl: true);

    double googleRisk = isGoogleSafe ? 0.0 : 1.0;

    double integratedScore = (localHeuristicScore * 0.40) + (googleRisk * 0.30) + (virusTotalScore * 0.30);

    return integratedScore;
  }

  /// 5. Clasifica el nivel de amenaza en tres umbrales de criticidad adaptados a la UX Humana de Centinela
  String classify(double score) {
    if (score < 0.3) return "SEGURO";
    if (score < 0.6) return "SOSPECHOSO";
    return "CRÍTICO";
  }
}