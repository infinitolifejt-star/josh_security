import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:html' as html; // Habilita la descarga directa en entornos Web Chrome

class ApiService {
  final String baseUrl = "http://127.0.0.1:5000";

  Future<List<dynamic>> fetchHistory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/history'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error cargando historial: $e");
    }
    return [];
  }

  Future<Map<String, dynamic>> sendScan({required String type, required String target}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/scan'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"type": type, "target": target}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error en escaneo: $e");
    }
    return {"status": "error", "verdict": "ERROR", "detail": "No hay conexión con el servidor Python."};
  }

  Future<void> downloadPdfReport() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/report/pdf'));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "Reporte_Forense_Centinela.pdf")
          ..click();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      print("Error descargando reporte PDF: $e");
    }
  }
}