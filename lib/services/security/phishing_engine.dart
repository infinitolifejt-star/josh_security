// ====================================================================================================
// ARCHIVO: lib/services/security/phishing_engine.dart
// MOTOR HEURÍSTICO DE DETECCIÓN DE PHISHING Y NUMERACIÓN ANÓMALA
// JOSH SECURITY v6.0-AGENTIC
// ====================================================================================================

import 'dart:math';

class PhishingEngine {
  PhishingEngine();

  static const Set<String> officialWhitelist = <String>{
    'google.com',
    'youtube.com',
    'github.com',
    'facebook.com',
    'instagram.com',
    'microsoft.com',
    'apple.com',
    'amazon.com',
    'paypal.com',
    'whatsapp.com',
    'netflix.com',
    'spotify.com',
    'live.com',
    'outlook.com',
    'mercadolibre.com.co',
    'mercadopago.com.co',
    'bancolombia.com',
    'nequi.com.co',
    'davivienda.com',
    'daviplata.com',
    'bbva.com.co',
    'bancodebogota.com',
    'bancopopular.com.co',
    'bancodeoccidente.com.co',
    'avvillas.com.co',
    'scotiabankcolpatria.com.co',
    'itau.co',
    'lulobank.com',
    'nu.com.co',
    'bold.co',
    'pse.com.co',
    'tuya.com.co',
    'dale.com.co',
    'movii.com.co',
    'gov.co',
    'dian.gov.co',
    'ramajudicial.gov.co',
    'policia.gov.co',
    'fiscalia.gov.co',
    'presidencia.gov.co',
    'mintic.gov.co',
    'procuraduria.gov.co',
    'contraloria.gov.co',
  };

  static const List<String> _brandKeywords = <String>[
    'google',
    'facebook',
    'bancolombia',
    'nequi',
    'davivienda',
    'daviplata',
    'lulobank',
    'login',
    'seguro',
    'verificacion',
    'soporte',
  ];

  static final RegExp _numericPattern = RegExp(r'^\+?\d+$');
  static final RegExp _repeatedDigitPattern = RegExp(r'^(\d)\1+$');
  static final RegExp _leetspeakPattern = RegExp(
    r'go0gle|banc0lombia|paypa1|micr0soft|f4cebook|nequ1|d4vivienda',
  );
  static final RegExp _suspiciousTldPattern = RegExp(
    r'\.comi\.co|\.com\.[a-z]{2}\.[a-z]{2}$|\.com\.[a-z]{2}$',
  );

  int levenshtein(String a, String b) {
    if (a == b) {
      return 0;
    }

    if (a.isEmpty) {
      return b.length;
    }

    if (b.isEmpty) {
      return a.length;
    }

    List<int> previous = List<int>.generate(
      b.length + 1,
      (int index) => index,
    );
    List<int> current = List<int>.filled(
      b.length + 1,
      0,
    );

    for (int i = 0; i < a.length; i++) {
      current[0] = i + 1;

      for (int j = 0; j < b.length; j++) {
        final int cost = a[i] == b[j] ? 0 : 1;

        current[j + 1] = min(
          min(
            current[j] + 1,
            previous[j + 1] + 1,
          ),
          previous[j] + cost,
        );
      }

      final List<int> swap = previous;
      previous = current;
      current = swap;
    }

    return previous.last;
  }

  Map<String, dynamic> analyze(String inputUrl) {
    final String clean = inputUrl.trim().toLowerCase();

    if (clean.isEmpty) {
      return <String, dynamic>{
        'score': 95.0,
        'verdict': 'CRÍTICO',
        'reason': 'Entrada vacía: no se recibió una URL o dominio válido.',
      };
    }

    final bool isNumeric = _numericPattern.hasMatch(clean);

    if (isNumeric) {
      final String digitsOnly = clean.replaceAll(RegExp(r'\D'), '');

      if (_repeatedDigitPattern.hasMatch(digitsOnly)) {
        return <String, dynamic>{
          'score': 90.0,
          'verdict': 'CRÍTICO',
          'reason':
              'Anomalía Estructural: Patrón numérico sintético con dígitos repetidos (Spoofing).',
        };
      }

      if (digitsOnly.length < 7 || digitsOnly.length > 15) {
        return <String, dynamic>{
          'score': 75.0,
          'verdict': 'SOSPECHOSO',
          'reason':
              'Longitud Anómala: Numeración fuera de estándar telefónico (${digitsOnly.length} dígitos).',
        };
      }
    }

    if (_leetspeakPattern.hasMatch(clean)) {
      return <String, dynamic>{
        'score': 95.0,
        'verdict': 'CRÍTICO',
        'reason':
            'Typosquatting Agéntico: Sustitución de caracteres por dígitos en nombre de marca (Leetspeak).',
      };
    }

    final bool badProtocol = clean.startsWith('hht') ||
        clean.startsWith('htps') ||
        clean.startsWith('http//');

    String normalizedUrl = clean;

    if (!normalizedUrl.contains('://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    final Uri uri;

    try {
      uri = Uri.parse(normalizedUrl);
    } catch (_) {
      return <String, dynamic>{
        'score': 95.0,
        'verdict': 'CRÍTICO',
        'reason':
            'Estructura Malformada: URL o dominio sintácticamente inválido.',
      };
    }

    String host = uri.host.toLowerCase().trim();

    if (host.isEmpty) {
      return <String, dynamic>{
        'score': 95.0,
        'verdict': 'CRÍTICO',
        'reason': 'Estructura Malformada: no se pudo identificar el dominio.',
      };
    }

    if (_suspiciousTldPattern.hasMatch(host) &&
        !officialWhitelist.contains(host)) {
      return <String, dynamic>{
        'score': 88.0,
        'verdict': 'CRÍTICO',
        'reason':
            'Dominio Sospechoso: TLD no estándar o extensión bancaria alterada.',
      };
    }

    if (officialWhitelist.contains(host) || host.endsWith('.gov.co')) {
      return <String, dynamic>{
        'score': badProtocol ? 35.0 : 2.0,
        'verdict': badProtocol ? 'SOSPECHOSO' : 'SEGURO',
        'reason': badProtocol
            ? 'Dominio oficial con protocolo alterado.'
            : 'Dominio oficial verificado.',
      };
    }

    for (final String brand in _brandKeywords) {
      final bool containsBrand = host.contains(brand);
      final bool isOfficialBrandDomain =
          host == '$brand.com' ||
          host == '$brand.co' ||
          host.endsWith('.$brand.com') ||
          host.endsWith('.$brand.co');

      if (containsBrand && !isOfficialBrandDomain) {
        return <String, dynamic>{
          'score': 97.0,
          'verdict': 'CRÍTICO',
          'reason':
              'Suplantación de Marca Identificada: Intento de Phishing imitando a $brand.',
        };
      }
    }

    final List<String> hostParts = host.split('.');
    final String current = hostParts.first;

    for (final String official in officialWhitelist) {
      final String base = official.split('.').first;

      if (current.length >= 4 &&
          current != base &&
          levenshtein(current, base) <= 2) {
        return <String, dynamic>{
          'score': 98.0,
          'verdict': 'CRÍTICO',
          'reason':
              'Typosquatting Detectado: Coincidencia de distancia reducida con marca legítima ($base).',
        };
      }
    }

    if (normalizedUrl.contains('@')) {
      return <String, dynamic>{
        'score': 90.0,
        'verdict': 'CRÍTICO',
        'reason':
            "Inyección Maliciosa: Uso de carácter '@' para deconstrucción de dominio.",
      };
    }

    if (hostParts.any((String part) => part.split('-').length > 4)) {
      return <String, dynamic>{
        'score': 80.0,
        'verdict': 'CRÍTICO',
        'reason':
            'Ofuscación de Dominio: Segmento con múltiples guiones de enmascaramiento.',
      };
    }

    if (badProtocol) {
      return <String, dynamic>{
        'score': 75.0,
        'verdict': 'SOSPECHOSO',
        'reason': 'Protocolo Inseguro o Alterado en la conexión.',
      };
    }

    return <String, dynamic>{
      'score': 45.0,
      'verdict': 'SOSPECHOSO',
      'reason':
          'Dominio no verificado en la lista blanca de reputación local.',
    };
  }
}
