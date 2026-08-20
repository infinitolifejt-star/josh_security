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
    caseSensitive: false,
  );

  static final RegExp _suspiciousTldPattern = RegExp(
    r'\.comi\.co|\.com\.[a-z]{2}\.[a-z]{2}$|\.com\.[a-z]{2}$',
    caseSensitive: false,
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

      final List<int> temp = previous;
      previous = current;
      current = temp;
    }

    return previous.last;
  }

  Map<String, dynamic> analyze(String inputUrl) {
    final String clean = inputUrl.trim().toLowerCase();

    if (clean.isEmpty) {
      return _result(
        score: 95.0,
        verdict: 'CRÍTICO',
        reason: 'Entrada vacía: no se recibió una URL o dominio válido.',
      );
    }

    if (_numericPattern.hasMatch(clean)) {
      final String digitsOnly = clean.replaceAll(RegExp(r'\D'), '');

      if (_repeatedDigitPattern.hasMatch(digitsOnly)) {
        return _result(
          score: 90.0,
          verdict: 'CRÍTICO',
          reason:
              'Anomalía estructural: patrón numérico sintético con dígitos repetidos.',
        );
      }

      if (digitsOnly.length < 7 || digitsOnly.length > 15) {
        return _result(
          score: 75.0,
          verdict: 'SOSPECHOSO',
          reason:
              'Longitud anómala: numeración fuera del estándar telefónico (${digitsOnly.length} dígitos).',
        );
      }
    }

    if (_leetspeakPattern.hasMatch(clean)) {
      return _result(
        score: 95.0,
        verdict: 'CRÍTICO',
        reason:
            'Typosquatting detectado: sustitución de caracteres por dígitos en una marca.',
      );
    }

    final bool badProtocol = _hasBadProtocol(clean);

    String normalizedUrl = clean;

    if (!normalizedUrl.contains('://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    final Uri uri;

    try {
      uri = Uri.parse(normalizedUrl);
    } catch (_) {
      return _result(
        score: 95.0,
        verdict: 'CRÍTICO',
        reason: 'Estructura malformada: URL o dominio inválido.',
      );
    }

    final String host = uri.host.toLowerCase().trim();

    if (host.isEmpty) {
      return _result(
        score: 95.0,
        verdict: 'CRÍTICO',
        reason: 'Estructura malformada: no se pudo identificar el dominio.',
      );
    }

    if (_suspiciousTldPattern.hasMatch(host) &&
        !officialWhitelist.contains(host)) {
      return _result(
        score: 88.0,
        verdict: 'CRÍTICO',
        reason:
            'Dominio sospechoso: TLD o extensión potencialmente alterada.',
      );
    }

    if (officialWhitelist.contains(host) || host.endsWith('.gov.co')) {
      return _result(
        score: badProtocol ? 35.0 : 2.0,
        verdict: badProtocol ? 'SOSPECHOSO' : 'SEGURO',
        reason: badProtocol
            ? 'Dominio oficial con protocolo alterado.'
            : 'Dominio oficial verificado.',
      );
    }

    for (final String brand in _brandKeywords) {
      if (!host.contains(brand)) {
        continue;
      }

      final bool isOfficialBrandDomain =
          host == '$brand.com' ||
          host == '$brand.co' ||
          host.endsWith('.$brand.com') ||
          host.endsWith('.$brand.co');

      if (!isOfficialBrandDomain) {
        return _result(
          score: 97.0,
          verdict: 'CRÍTICO',
          reason:
              'Suplantación de marca identificada: posible phishing imitando a $brand.',
        );
      }
    }

    final List<String> hostParts = host.split('.');
    final String current = hostParts.first;

    for (final String official in officialWhitelist) {
      final String base = official.split('.').first;

      if (current.length >= 4 &&
          current != base &&
          levenshtein(current, base) <= 2) {
        return _result(
          score: 98.0,
          verdict: 'CRÍTICO',
          reason:
              'Typosquatting detectado: dominio similar a una marca legítima ($base).',
        );
      }
    }

    if (uri.userInfo.isNotEmpty || normalizedUrl.contains('@')) {
      return _result(
        score: 90.0,
        verdict: 'CRÍTICO',
        reason:
            'Estructura sospechosa: uso del carácter @ para ocultar el dominio real.',
      );
    }

    if (hostParts.any(
      (String part) => part.split('-').length > 4,
    )) {
      return _result(
        score: 80.0,
        verdict: 'CRÍTICO',
        reason:
            'Ofuscación de dominio: segmento con múltiples guiones.',
      );
    }

    if (badProtocol) {
      return _result(
        score: 75.0,
        verdict: 'SOSPECHOSO',
        reason: 'Protocolo inseguro o alterado.',
      );
    }

    return _result(
      score: 45.0,
      verdict: 'SOSPECHOSO',
      reason:
          'Dominio no verificado en la lista blanca de reputación local.',
    );
  }

  bool _hasBadProtocol(String value) {
    return value.startsWith('hht') ||
        value.startsWith('htps') ||
        value.startsWith('http//');
  }

  Map<String, dynamic> _result({
    required double score,
    required String verdict,
    required String reason,
  }) {
    return <String, dynamic>{
      'score': score.clamp(0.0, 100.0),
      'verdict': verdict,
      'reason': reason,
    };
  }
}
