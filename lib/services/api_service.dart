import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = "http://localhost:5000"});

  // Procesador dinámico profundo para extraer payloads válidos del backend
  Map<String, dynamic> _cleanResponse(http.Response response) {
    try {
      if (response.body.isEmpty) {
        return {"status": "ERROR", "message": "Cuerpo vacío"};
      }
      
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        // Si el servidor devolvió la estructura estándar con la clave 'data' anidada
        if (decoded.containsKey('data') && decoded['data'] is Map) {
          final Map<String, dynamic> dataMap = Map<String, dynamic>.from(decoded['data']);
          return {
            "status": decoded['status'] ?? "SUCCESS",
            "fileName": dataMap['fileName'] ?? "Objeto Desconocido",
            "verdict": dataMap['verdict'] ?? "SEGURO",
            "engine": dataMap['engine'] ?? "Centinela Core"
          };
        }
        return Map<String, dynamic>.from(decoded);
      }
      return {"status": "ERROR", "message": "Formato JSON no compatible"};
    } catch (e) {
      return {"status": "ERROR", "message": "Fallo de parseo: ${e.toString()}"};
    }
  }

  Future<Map<String, dynamic>> scanFileWithPython(PlatformFile file) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/scan');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"fileName": file.name, "size": file.size}),
      );
      return _cleanResponse(response);
    } catch (e) {
      return {"status": "ERROR", "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> scanUrlWithPython(String targetUrl) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/scan-url');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"url": targetUrl}),
      );
      return _cleanResponse(response);
    } catch (e) {
      return {"status": "ERROR", "message": e.toString()};
    }
  }

  Future<List<dynamic>> fetchScanHistory() async {
    try {
      final url = Uri.parse('$baseUrl/api/history');
      final response = await http.get(url, headers: {"Accept": "application/json"});
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}