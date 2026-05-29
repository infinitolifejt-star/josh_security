// lib/services/security/secure_logger.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecureLogger {
  String hash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Map<String, String> createSecureLog(String data) {
    String timestamp = DateTime.now().toIso8601String();
    String payload = "$data|$timestamp";

    String signature = hash(payload);

    return {
      "payload": payload,
      "signature": signature,
    };
  }

  bool verify(String payload, String signature) {
    return hash(payload) == signature;
  }
}