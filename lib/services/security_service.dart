import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SecurityService {
  static Future<Map<String, dynamic>> analizarDominio(String url) async {
    // Limpieza de URL para obtener solo el dominio
    final domain = url.trim()
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .split('/')[0];
        
    if (domain.isEmpty) return {'error': 'URL inválida'};

    try {
      final apiKey = dotenv.env['VT_API_KEY'];
      final response = await http.get(
        Uri.parse('https://www.virustotal.com/api/v3/domains/$domain'),
        headers: {'x-apikey': apiKey ?? ''},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'malicious': data['data']['attributes']['last_analysis_stats']['malicious'],
          'status': 'success'
        };
      } else {
        return {'error': 'Dominio no encontrado', 'status': 'not_found'};
      }
    } catch (e) {
      return {'error': 'Fallo de conexión', 'status': 'error'};
    }
  }
}