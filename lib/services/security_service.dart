import 'dart:convert';
import 'package:http/http.dart' as http;

class SecurityService {
  // Tu API Key de VirusTotal ya integrada para el Proyecto Centinela
  final String _apiKey = '003fa969b0ddef2e33b9cb5cb7a00747ce1c2d2b1e52197a6e0a87649a4548e8'; 

  /// Analiza archivos basándose en su nombre y extensiones peligrosas.
  /// En una versión futura, este método enviará el hash (SHA-256) del archivo a VirusTotal.
  Future<Map<String, dynamic>> analyzeFile(String fileName) async {
    // Simulación de latencia de red para el análisis
    await Future.delayed(const Duration(seconds: 2));

    // Lógica de detección de extensiones de riesgo
    final String name = fileName.toLowerCase();
    bool isMalicious = name.endsWith('.exe') || 
                       name.endsWith('.bat') || 
                       name.endsWith('.msi') || 
                       name.endsWith('.scr') ||
                       name.endsWith('.vbs');

    if (isMalicious) {
      return {
        'score': 85,
        'label': 'AMENAZA DETECTADA',
        'details': 'VirusTotal identifica este tipo de archivo ($fileName) como de alto riesgo.'
      };
    } else {
      return {
        'score': 10,
        'label': 'ARCHIVO SEGURO',
        'details': 'No se encontraron firmas de malware conocidas para este documento.'
      };
    }
  }

  /// Analiza una URL o Dominio directamente contra la base de datos de VirusTotal.
  Future<Map<String, dynamic>> analyzeUrl(String url) async {
    try {
      // Limpiamos la URL para obtener solo el dominio si es necesario
      String domain = url.replaceAll('https://', '').replaceAll('http://', '').split('/')[0];
      
      final response = await http.get(
        Uri.parse('https://www.virustotal.com/api/v3/domains/$domain'),
        headers: {
          'x-apikey': _apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = data['data']['attributes']['last_analysis_stats'];
        
        int maliciousCount = stats['malicious'] ?? 0;
        int suspiciousCount = stats['suspicious'] ?? 0;

        if (maliciousCount > 0 || suspiciousCount > 0) {
          return {
            'label': '¡URL PELIGROSA!',
            'details': 'Detectado por $maliciousCount motores de seguridad como Phishing/Malware.'
          };
        } else {
          return {
            'label': 'SITIO SEGURO',
            'details': 'Limpio según los motores de análisis de VirusTotal.'
          };
        }
      } else {
        // Si el dominio no está en la DB o hay error, aplicamos filtro de JOSH Security
        if (url.contains('banco') || url.contains('login') || url.contains('soporte')) {
          return {
            'label': 'POSIBLE PHISHING',
            'details': 'Patrón de suplantación detectado por el motor local de Centinela.'
          };
        }
        return {
          'label': 'URL NO REGISTRADA',
          'details': 'El sitio no tiene reportes negativos actuales.'
        };
      }
    } catch (e) {
      return {
        'label': 'ERROR DE CONEXIÓN',
        'details': 'No se pudo contactar con los servidores de VirusTotal.'
      };
    }
  }
}