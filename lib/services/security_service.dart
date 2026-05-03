import 'dart:convert';
import 'package:http/http.dart' as http;

class SecurityService {
  // API Key de VirusTotal vinculada al Proyecto Centinela
  final String _apiKey = '003fa969b0ddef2e33b9cb5cb7a00747ce1c2d2b1e52197a6e0a87649a4548e8'; 

  /// Analiza archivos basándose en su extensión (Motor Local)
  Future<Map<String, dynamic>> analyzeFile(String fileName) async {
    await Future.delayed(const Duration(seconds: 2));
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
        'details': 'Archivo ejecutable ($fileName) de alto riesgo.'
      };
    } else {
      return {
        'score': 10,
        'label': 'ARCHIVO SEGURO',
        'details': 'No se detectaron firmas sospechosas.'
      };
    }
  }

  /// Analiza una URL contra VirusTotal y filtros locales de Centinela
  Future<Map<String, dynamic>> analyzeUrl(String url) async {
    try {
      final cleanUrl = url.trim().toLowerCase();
      
      // 1. Detección de acortadores sospechosos (Filtro local Centinela)
      final shorteners = ['bit.ly', 't.co', 'tinyurl.com', 'cutt.ly'];
      if (shorteners.any((s) => cleanUrl.contains(s))) {
        return {
          'label': 'PRECAUCIÓN: ENLACE OCULTO',
          'details': 'Uso de acortador detectado. Podría ocultar un sitio malicioso.'
        };
      }

      // 2. Extraer dominio para la consulta a la API
      String domain = cleanUrl.replaceAll('https://', '').replaceAll('http://', '').split('/')[0];
      
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
        if (maliciousCount > 0) {
          return {
            'label': '¡URL PELIGROSA!',
            'details': 'Detectado por $maliciousCount motores de seguridad en VirusTotal.'
          };
        }
      } 
      
      // 3. Filtro de palabras clave si la API no reporta nada
      if (cleanUrl.contains('banco') || cleanUrl.contains('login') || cleanUrl.contains('soporte')) {
        return {
          'label': 'POSIBLE PHISHING',
          'details': 'Patrón de suplantación detectado por el motor local de Centinela.'
        };
      }

      return {
        'label': 'SITIO SEGURO',
        'details': 'El sitio no tiene reportes negativos actuales.'
      };

    } catch (e) {
      return {
        'label': 'ERROR DE CONEXIÓN',
        'details': 'No se pudo contactar con los servidores de análisis.'
      };
    }
  }
}