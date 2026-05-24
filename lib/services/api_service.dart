import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Al compilar en Chrome para PC, la API se conecta directamente al localhost de Python
  final String baseUrl = "http://127.0.0.1:5000/api";

  // 1. Verificación de Handshake (Conexión Viva con el Servidor)
  Future<Map<String, dynamic>?> checkHandshake() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/handshake'),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Error de Handshake con el servidor de Python: $e");
      return null;
    }
  }

  // 2. Ejecución del Escaneo Forense (Sustituye 'scanUrl' por 'scanTarget')
  Future<Map<String, dynamic>> scanTarget(String type, String targetUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/scan'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "url": targetUrl,
          "type": type, // 'phishing', 'malware' o 'fraud'
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          "verdict": "ERROR",
          "details": "El servidor Python respondió con código: ${response.statusCode}"
        };
      }
    } catch (e) {
      return {
        "verdict": "DESCONECTADO",
        "details": "No se pudo conectar con el motor forense. Detalles: $e"
      };
    }
  }

  // 3. Recuperar Historial de Auditorías desde la Base de Datos Local de Python
  Future<List<dynamic>> fetchHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/history'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data;
        } else if (data is Map && data.containsKey('history')) {
          return data['history'];
        }
      }
      return [];
    } catch (e) {
      print("Error al traer el historial analítico: $e");
      return [];
    }
  }

  // 4. Descarga del Reporte Forense Institucional en PDF
  Future<bool> downloadPdfReport() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/download-pdf'),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        // Nota: En la versión web de Flutter, la descarga se gestiona abriendo o guardando el stream de bytes de la respuesta http.
        print("Reporte PDF descargado con éxito desde el Core.");
        return true;
      }
      return false;
    } catch (e) {
      print("Error al descargar el PDF analítico: $e");
      return false;
    }
  }
}