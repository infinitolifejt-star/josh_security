import 'dart:convert';
import 'package:http/http.dart' as http;

class SecurityService {
  final String _apiKey = '003fa969b0ddef2e33b9cb5cb7a00747ce1c2d2b1e52197a6e0a87649a4548e8'; 

  Future<Map<String, String>> analyzeUrl(String url) async {
    try {
      final cleanUrl = url.trim().toLowerCase();

      if (!cleanUrl.contains('.') || cleanUrl.length < 4) {
        return {
          'label': '❌ FORMATO INVÁLIDO', 
          'details': 'Por favor, ingrese una URL real (ejemplo: google.com).'
        };
      }
      
      if (cleanUrl.contains('banco') || cleanUrl.contains('login') || cleanUrl.contains('verificar')) {
        return {
          'label': '🚨 POSIBLE PHISHING', 
          'details': 'El sistema detectó patrones sospechosos de suplantación.'
        };
      }

      Uri uri = Uri.parse(cleanUrl.startsWith('http') ? cleanUrl : 'https://$cleanUrl');
      String domain = uri.host.isEmpty ? cleanUrl.split('/')[0] : uri.host;
      
      final response = await http.get(
        Uri.parse('https://www.virustotal.com/api/v3/domains/$domain'),
        headers: {'x-apikey': _apiKey, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = data['data']['attributes']['last_analysis_stats'];
        if ((stats['malicious'] ?? 0) > 0) {
          return {
            'label': '¡URL PELIGROSA!', 
            'details': 'Reportada como maliciosa por motores de seguridad globales.'
          };
        }
      } 

      return {
        'label': '✅ SITIO SEGURO', 
        'details': 'El Protocolo Centinela no encontró amenazas para este dominio.'
      };

    } catch (e) {
      return {
        'label': 'ERROR DE ANÁLISIS', 
        'details': 'No se pudo verificar el link. Revisa tu conexión a internet.'
      };
    }
  }
}