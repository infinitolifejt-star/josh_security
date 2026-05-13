import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SentinelApiService {
  // Protocolo Zero Trust: Acceso seguro a la llave
  static final String _apiKey = dotenv.env['VT_API_KEY'] ?? '';
  static const String _baseUrl = 'https://www.virustotal.com/api/v3';

  // Servicio de Escaneo de Enlaces
  Future<Map<String, dynamic>> scanUrl(String urlToScan) async {
    if (_apiKey.isEmpty) {
      return {'error': 'Sentinel Error: API Key no encontrada en .env'};
    }
    
    // Codificación segura para la API de VirusTotal
    final encodedUrl = base64Url.encode(utf8.encode(urlToScan)).replaceAll('=', '');
    final requestUrl = Uri.parse('$_baseUrl/urls/$encodedUrl');

    try {
      final response = await http.get(
        requestUrl,
        headers: {
          'x-apikey': _apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        return {'error': 'Detección Fallida: ${errorData['error']['message']}'};
      }
    } catch (e) {
      return {'error': 'Conexión Interceptada o Fallida: $e'};
    }
  }
}