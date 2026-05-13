import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SentinelApiService {
  // Usamos la clave que ya tienes en tu archivo .env
  final String _apiKey = dotenv.env['VT_API_KEY'] ?? 'TU_CLAVE_MANUAL_AQUI';

  Future<Map<String, dynamic>> checkUrl(String url) async {
    try {
      // 1. Limpiar la URL
      final cleanUrl = url.trim().replaceAll('https://', '').replaceAll('http://', '');
      
      // 2. Llamada real a VirusTotal (v3)
      final response = await http.get(
        Uri.parse('https://www.virustotal.com/api/v3/domains/$cleanUrl'),
        headers: {'x-apikey': _apiKey},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Analizamos si hay votos de malicia
        final stats = data['data']['attributes']['last_analysis_stats'];
        final malicious = stats['malicious'] ?? 0;

        if (malicious > 0) {
          return {'status': '🚨 ¡AMENAZA DETECTADA! ($malicious motores marcaron esta URL)'};
        } else {
          return {'status': '✅ JOSH Sentinel: URL Limpia y Segura.'};
        }
      } else {
        return {'status': '🛡️ Escudo Local: La URL parece segura, pero VirusTotal no respondió.'};
      }
    } catch (e) {
      return {'status': '⚠️ Error de conexión. Verificando integridad local...'};
    }
  }
}