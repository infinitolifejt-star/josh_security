// ====================================================================================================
// ARCHIVO: lib/services/security/secure_logger.dart
// COMPONENTE: Motor Criptográfico de Integridad de Logs para JOSH Security v6.0
// ====================================================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecureLogger {
  const SecureLogger();

  /// Calcula el hash SHA-256 blindando el procesamiento de bits
  static String _hash(String input) {
    final List<int> bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Genera un identificador pseudo-UUID v4 simple para correlación local
  static String _generateUuidV4() {
    final DateTime now = DateTime.now();
    final String microseconds = now.microsecondsSinceEpoch.toRadixString(16);
    final String signature = _hash(microseconds);
    return '${signature.substring(0, 8)}-${signature.substring(8, 12)}-4${signature.substring(13, 16)}-'
        '${signature.substring(16, 20)}-${signature.substring(20, 32)}';
  }

  /// Crea un bloque de registro seguro uniendo los datos con la estampa de tiempo y su firma criptográfica
  Map<String, String> createSecureLog(String data) {
    final String timestamp = DateTime.now().toIso8601String();
    final String logId = _generateUuidV4();

    final String structuredPayload = jsonEncode({
      "id": logId,
      "data": data,
      "timestamp": timestamp,
    });

    final String signature = _hash(structuredPayload);

    return {
      "id": logId,
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
