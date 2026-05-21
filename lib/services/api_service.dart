import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Apuntamos al backend local en el puerto 5000
  static const String baseUrl = 'http://127.0.0.1:5000';

  /// Obtiene el historial adaptativo desde la base de datos SQLite
  Future<List<dynamic>> fetchHistory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/history'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al cargar historial (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ Excepción en ApiService.fetchHistory: $e');
      return [];
    }
  }

  /// Envía un objetivo manual (archivo o URL) para ser analizado en tiempo real
  Future<Map<String, dynamic>> sendScan({required String type, required String target}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/scan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'type': type,      // Puede ser 'file' o 'url'
          'target': target,  // El nombre del archivo o enlace a evaluar
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Error en servidor remoto (Status: ${response.statusCode})'
        };
      }
    } catch (e) {
      print('❌ Excepción en ApiService.sendScan: $e');
      return {
        'status': 'error',
        'message': 'No se pudo conectar con el servidor Centinela.'
      };
    }
  }
}