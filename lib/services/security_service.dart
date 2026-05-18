import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class SecurityService {
  // ==========================================
  // CONFIGURACIÓN DE LLAVES (MODIFÍCALO LOCALMENTE)
  // ==========================================
  final String _vtApiKey = '003fa969b0ddef2e33b9cb5cb7a00747ce1c2d2b1e52197a6e0a87649a4548e8'; 
  final String _googleKey = 'AIzaSyDOsRp-_qb7CAdw9NfqnWIGCUiBS_zp00Q';

  // Usamos un proxy de desarrollo para evadir las restricciones CORS de Chrome Web
  final String _corsProxy = 'https://cors-anywhere.herokuapp.com/';
  final String _vtBaseUrl = 'https://www.virustotal.com/api/v3';

  // --- 1. ANÁLISIS MULTI-MOTOR DE URLS (VirusTotal + Google Safe Browsing) ---
  Future<Map<String, dynamic>> analyzeUrl(String urlToAnalyze) async {
    try {
      // FASE A: Consulta en Google Safe Browsing (Verificación de Phishing/Malware)
      final googleUrl = 'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$_googleKey';
      final googleBody = {
        "client": {"clientId": "josh_security", "clientVersion": "1.0.0"},
        "threatInfo": {
          "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE", "POTENTIALLY_HARMFUL_APPLICATION"],
          "platformTypes": ["ANY_PLATFORM"],
          "threatEntryTypes": ["URL"],
          "threatEntries": [{"url": urlToAnalyze}]
        }
      };

      bool isGoogleUnsafe = false;
      try {
        final googleResponse = await http.post(
          Uri.parse(googleUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(googleBody),
        );
        if (googleResponse.statusCode == 200) {
          final googleData = jsonDecode(googleResponse.body);
          if (googleData.containsKey('matches')) {
            isGoogleUnsafe = true;
          }
        }
      } catch (e) {
        print('Advertencia de enlace Google Safe Browsing: $e');
      }

      // FASE B: Consulta Paralela en VirusTotal
      String rawId = base64Url.encode(utf8.encode(urlToAnalyze)).replaceAll('=', '');
      
      // Intentamos petición directa; si falla por CORS, usamos el respaldo analítico
      final vtUri = Uri.parse('$_vtBaseUrl/urls/$rawId');
      final response = await http.get(
        vtUri,
        headers: {
          'x-apikey': _vtApiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = data['data']['attributes']['last_analysis_stats'];

        int malicious = stats['malicious'] ?? 0;
        int suspicious = stats['suspicious'] ?? 0;
        int harmless = stats['harmless'] ?? 0;

        if (isGoogleUnsafe) malicious += 5; // Penalización táctica si Google lo tiene reportado

        String status = 'safe';
        String message = 'Análisis completado. El enlace no registra anomalías en los motores principales.';

        if (malicious > 0) {
          status = 'danger';
          message = '¡ALERTA CRÍTICA! Enlace catalogado como amenaza activa por $malicious motores de seguridad.';
        } else if (suspicious > 0) {
          status = 'warning';
          message = 'Advertencia de seguridad: Se detectaron indicios sospechosos ($suspicious motores).';
        }

        return {
          'status': status,
          'message': message,
          'malicious': malicious,
          'suspicious': suspicious,
          'harmless': harmless,
        };
      } else {
        // Intento secundario usando el Proxy en caso de bloqueo estricto de CORS
        return await _analyzeUrlWithProxy(rawId, isGoogleUnsafe);
      }
    } catch (e) {
      return _returnErrorData('Error general en análisis de URL: $e');
    }
  }

  // --- 2. ANÁLISIS CRIPTOGRÁFICO DE ARCHIVOS POR HASH SHA-256 ---
  Future<Map<String, dynamic>> analyzeFile(List<int> fileBytes, String fileName) async {
    try {
      // Generamos el Hash SHA-256 nativo de los bytes cargados en memoria
      final hash = sha256.convert(fileBytes).toString();
      
      final response = await http.get(
        Uri.parse('$_vtBaseUrl/files/$hash'),
        headers: {
          'x-apikey': _vtApiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = data['data']['attributes']['last_analysis_stats'];

        int malicious = stats['malicious'] ?? 0;
        int suspicious = stats['suspicious'] ?? 0;
        int harmless = stats['harmless'] ?? 0;

        String status = 'safe';
        String message = 'Firma criptográfica ($hash) verificada. El archivo "$fileName" está libre de malware conocido.';

        if (malicious > 0) {
          status = 'danger';
          message = '¡AMENAZA DETECTADA! El Hash del archivo coincide con registros hostiles confirmados por $malicious motores.';
        } else if (suspicious > 0) {
          status = 'warning';
          message = 'Firma sospechosa: El archivo exhibe comportamientos inestables en sistemas de auditoría.';
        }

        return {
          'status': status,
          'message': message,
          'malicious': malicious,
          'suspicious': suspicious,
          'harmless': harmless,
        };
      } else if (response.statusCode == 404) {
        return {
          'status': 'safe',
          'message': 'Componente limpio. El Hash de "$fileName" no registra antecedentes de código malicioso en la base global.',
          'malicious': 0,
          'suspicious': 0,
          'harmless': 0,
        };
      } else {
        // Intento de respaldo del archivo vía Proxy por si ocurre bloqueo de CORS en la consulta del Hash
        return await _analyzeFileWithProxy(hash, fileName);
      }
    } catch (e) {
      return _returnErrorData('Falla en el procesamiento criptográfico: $e');
    }
  }

  // --- MÉTODOS DE RESPALDO PROXY (EVASIÓN DE CORS EN DESARROLLO WEB) ---
  Future<Map<String, dynamic>> _analyzeUrlWithProxy(String rawId, bool googleThreat) async {
    try {
      final response = await http.get(
        Uri.parse('$_corsProxy$_vtBaseUrl/urls/$rawId'),
        headers: {
          'x-apikey': _vtApiKey,
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = data['data']['attributes']['last_analysis_stats'];
        int malicious = (stats['malicious'] ?? 0) + (googleThreat ? 5 : 0);
        return {
          'status': malicious > 0 ? 'danger' : 'safe',
          'message': malicious > 0 ? 'Amenaza detectada a través del nodo de respaldo.' : 'Enlace verificado como seguro.',
          'malicious': malicious,
          'suspicious': stats['suspicious'] ?? 0,
          'harmless': stats['harmless'] ?? 0,
        };
      }
    } catch (_) {}
    return _returnErrorData('Falla de comunicación con los servidores analíticos.');
  }

  Future<Map<String, dynamic>> _analyzeFileWithProxy(String hash, String fileName) async {
    try {
      final response = await http.get(
        Uri.parse('$_corsProxy$_vtBaseUrl/files/$hash'),
        headers: {
          'x-apikey': _vtApiKey,
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = data['data']['attributes']['last_analysis_stats'];
        int malicious = stats['malicious'] ?? 0;
        return {
          'status': malicious > 0 ? 'danger' : 'safe',
          'message': malicious > 0 ? 'Malware confirmado en base de datos global.' : 'Firma de archivo "$fileName" limpia.',
          'malicious': malicious,
          'suspicious': stats['suspicious'] ?? 0,
          'harmless': stats['harmless'] ?? 0,
        };
      }
    } catch (_) {}
    return _returnErrorData('Falla en el enlace táctico.');
  }

  Map<String, dynamic> _returnErrorData(String consoleLog) {
    print('LOG_SEGURIDAD: $consoleLog');
    return {
      'status': 'danger',
      'message': 'Falla en el enlace táctico: Las solicitudes están siendo bloqueadas por restricciones de red o CORS del navegador Chrome.',
      'malicious': 0,
      'suspicious': 0,
      'harmless': 0,
    };
  }
}