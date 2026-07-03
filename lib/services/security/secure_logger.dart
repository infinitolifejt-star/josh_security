import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecureLogger {
  // Constructor constante para permitir la instanciación eficiente en memoria
  const SecureLogger();

  /// Calcula de forma privada el hash SHA-256 blindando el procesamiento de bits
  String _hash(String input) {
    final List<int> bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Crea un bloque de registro seguro uniendo los datos con la estampa de tiempo y su firma criptográfica en JSON estructurado
  Map<String, String> createSecureLog(String data) {
    // Anclaje temporal inmutable para evitar desincronizaciones en la pila asíncrona
    final String timestamp = DateTime.now().toIso8601String();
    
    // TODO: [DEUDA TÉCNICA - CENTINELA] Integrar un UID criptográfico correlativo (UUID v4) por cada registro generado para mitigar ataques de replicación u omisión en los reportes forenses de la Fase 3.
    
    // Serialización estricta en JSON para neutralizar inyecciones de delimitadores de texto (|)
    final String structuredPayload = jsonEncode({
      "data": data,
      "timestamp": timestamp,
    });
    
    final String signature = _hash(structuredPayload);

    return {
      "payload": structuredPayload,
      "signature": signature,
    };
  }

  /// Verifica la integridad de un registro contrastando el payload con su firma SHA-256
  bool verify(String payload, String signature) {
    if (payload.trim().isEmpty || signature.trim().isEmpty) return false;
    return _hash(payload) == signature;
  }
}