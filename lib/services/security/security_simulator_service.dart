// ====================================================================================================
// ARCHIVO: lib/services/security/security_simulator_service.dart
// GENERADOR DINÁMICO DE VECTORES DE AMENAZA PARA PRUEBAS RADAR EN TIEMPO REAL v1.0
// ====================================================================================================

import 'dart:math';

class SecuritySimulatorService {
  static final SecuritySimulatorService _instance = SecuritySimulatorService._internal();
  factory SecuritySimulatorService() => _instance;
  SecuritySimulatorService._internal();

  final Random _random = Random();

  /// Prefijos y patrones para la generación sintética de pruebas
  final List<String> _safeColombianPrefixes = ['300', '301', '302', '310', '311', '315', '320', '601', '604'];
  final List<String> _warningPrefixes = ['350', '319', '+4420', '+1800', '+3491'];
  final List<String> _criticalPrefixes = ['+234', '+882', '+252', '0000', '9999', '+371', '+216'];

  final List<String> _safeUrls = [
    'https://www.google.com',
    'https://www.bancolombia.com',
    'https://www.gov.co',
    'https://github.com'
  ];

  final List<String> _phishingUrls = [
    'http://secure-login-banco-colombia-update.free-site.xyz/login',
    'http://verifica-tu-cuenta-davivienda-alerta.net/auth',
    'http://actualizacion-nequi-seguridad-2026.online/reset',
    'http://soporte-tecnico-urgente-bancario.top/verify'
  ];

  /// Genera un número de teléfono dinámico aleatorio clasificable en Verde, Amarillo o Rojo
  Map<String, dynamic> generateDynamicPhoneVector() {
    // 0: SEGURO (Verde), 1: ADVERTENCIA (Amarillo), 2: CRÍTICO (Rojo)
    int targetRiskCategory = _random.nextInt(3);

    String generatedNumber = '';
    String expectedClassification = '';

    switch (targetRiskCategory) {
      case 0: // 🟢 SEGURO
        String prefix = _safeColombianPrefixes[_random.nextInt(_safeColombianPrefixes.length)];
        String suffix = List.generate(7, (_) => _random.nextInt(10)).join();
        generatedNumber = '$prefix$suffix';
        expectedClassification = 'SEGURO';
        break;

      case 1: // 🟡 ADVERTENCIA
        String prefix = _warningPrefixes[_random.nextInt(_warningPrefixes.length)];
        String suffix = List.generate(7, (_) => _random.nextInt(10)).join();
        generatedNumber = '$prefix$suffix';
        expectedClassification = 'ADVERTENCIA';
        break;

      case 2: // 🔴 CRÍTICO
        String prefix = _criticalPrefixes[_random.nextInt(_criticalPrefixes.length)];
        String suffix = List.generate(8, (_) => _random.nextInt(10)).join();
        generatedNumber = '$prefix$suffix';
        expectedClassification = 'CRÍTICO';
        break;
    }

    return {
      'target': generatedNumber,
      'type': 'SPAM',
      'expectedClassification': expectedClassification,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Genera una URL aleatoria para probar el motor de Phishing
  Map<String, dynamic> generateDynamicUrlVector() {
    bool isPhishing = _random.nextBool();

    String url = isPhishing
        ? _phishingUrls[_random.nextInt(_phishingUrls.length)]
        : _safeUrls[_random.nextInt(_safeUrls.length)];

    return {
      'target': url,
      'type': 'PHISHING',
      'expectedClassification': isPhishing ? 'CRÍTICO' : 'SEGURO',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}