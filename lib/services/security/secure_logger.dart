// lib/services/security/secure_logger.dart

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

  /// Crea un bloque de registro seguro uniendo los datos con la estampa de tiempo y su firma criptográfica
  Map<String, String> createSecureLog(String data) {
    final String timestamp = DateTime.now().toIso8601String();
    final String payload = "$data|$timestamp";
    final String signature = _hash(payload);

    return const {
      "payload": "payload",
      "signature": "signature",
    }.map((key, value) => MapEntry(key, key == "payload" ? payload : signature));
  }

  /// Verifica la integridad de un registro contrastando el payload con su firma SHA-256
  bool verify(String payload, String signature) {
    return _hash(payload) == signature;
  }
}