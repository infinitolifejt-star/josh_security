import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 🚨 PUENTE DE RED LOCAL GLOBAL-CENTINELA
  static const String _baseUrl = 'http://192.168.1.9:5000';

  Future<List<dynamic>> fetchHistory() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/history'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al sincronizar con el Core: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> scanTarget(String type, String target) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/scan'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'type': type, 'target': target}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Fallo en el motor analítico externo.');
    }
  }

  Future<void> downloadPdfReport() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/report/pdf'));
    if (response.statusCode != 200) {
      throw Exception('Error al compilar el reporte forense en el servidor.');
    }
  }
}