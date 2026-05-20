import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = "http://localhost:5000"});

  // Método para enviar archivos a analizar en el backend de Python
  Future<Map<String, dynamic>> scanFileWithPython(PlatformFile file) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/scan');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"fileName": file.name, "size": file.size}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          "status": "ERROR",
          "message": "Servidor Python respondió con estado: ${response.statusCode}"
        };
      }
    } catch (e) {
      return {
        "status": "ERROR",
        "message": "No se pudo conectar al backend de Python: ${e.toString()}"
      };
    }
  }

  // Método para recuperar el historial forense guardado en Flask
  Future<List<dynamic>> fetchScanHistory() async {
    try {
      final url = Uri.parse('$baseUrl/api/history');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}