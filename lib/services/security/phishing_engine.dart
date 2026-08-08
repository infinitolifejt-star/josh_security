// ====================================================================================================
// ARCHIVO: lib/services/security/phishing_engine.dart
// MOTOR HEURÍSTICO Y AGÉNTICO DE DETECCIÓN DE PHISHING Y NUMERACIÓN ANÓMALA
// JOSH SECURITY v6.0-AGENTIC
// ====================================================================================================

import 'dart:math';

class PhishingEngine {
  PhishingEngine();

  static final Set<String> officialWhitelist = {
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

  int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> previous = List.generate(b.length + 1, (i) => i);
    List<int> current = List.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      current[0] = i + 1;

      for (int j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;

        current[j + 1] = min(
          min(
            current[j] + 1,
            previous[j + 1] + 1,
          ),
          previous[j] + cost,
        );
      }

      previous = List<int>.from(current);
    }

    return current.last;
  }

  Map<String, dynamic> analyze(String inputUrl) {
    String clean = inputUrl.trim().toLowerCase();

    // ------------------------------------------------------------------------------------------------
    // REGLA 0: VALIDACIÓN DE NUMERACIÓN TELEFÓNICA O CADENAS DE DÍGITOS
    // ------------------------------------------------------------------------------------------------
    final isNumeric = RegExp(r'^\+?\d+$').hasMatch(clean);
    if (isNumeric) {
      final digitsOnly = clean.replaceAll(RegExp(r'\D'), '');

      // Patrón de dígitos repetidos sintéticos (ej: 888888888888888888)
      if (RegExp(r'^(\d)\1+$').hasMatch(digitsOnly)) {
        return {
          "score": 90.0,
          "verdict": "CRÍTICO",
          "reason": "Anomalía Estructural: Patrón numérico sintético con dígitos repetidos (Spoofing)."
        };
      }

      // Longitud fuera de estándares E.164 (menos de 7 o más de 15 dígitos)
      if (digitsOnly.length < 7 || digitsOnly.length > 15) {
        return {
          "score": 75.0,
          "verdict": "SOSPECHOSO",
          "reason": "Longitud Anómala: Numeración fuera de estándar telefónico (${digitsOnly.length} dígitos)."
        };
      }
    }

    // ------------------------------------------------------------------------------------------------
    // REGLA 1: DETECCIÓN DE SUPLANTACIÓN TIPOGRÁFICA / LEETSPEAK EN MARCAS (Ej. Go0gle, Banc0lombia)
    // ------------------------------------------------------------------------------------------------
    if (RegExp(r'go0gle|banc0lombia|paypa1|micr0soft|f4cebook|nequ1|d4vivienda').hasMatch(clean)) {
      return {
        "score": 95.0,
        "verdict": "CRÍTICO",
        "reason": "Typosquatting Agéntico: Sustitución de caracteres por dígitos en nombre de marca (Leetspeak)."
      };
    }

    bool badProtocol = false;

    if (clean.startsWith("hht") || clean.startsWith("htps") || clean.startsWith("http//")) {
      badProtocol = true;
    }

    String url = clean;

    if (!url.contains("://")) {
      url = "https://$url";
    }

    Uri uri;

    try {
      uri = Uri.parse(url);
    } catch (_) {
      return {
        "score": 95.0,
        "verdict": "CRÍTICO",
        "reason": "Estructura Malformada: URL o dominio sintácticamente inválido."
      };
    }

    String host = uri.host;

    if (host.contains(":")) {
      host = host.split(":").first;
    }

    // ------------------------------------------------------------------------------------------------
    // REGLA 2: DOMINIOS Y TLDs SOSPECHOSOS O DE SEGUNDO NIVEL ALTERADOS (Ej. Bancolombia.comi.co)
    // ------------------------------------------------------------------------------------------------
    if (RegExp(r'\.comi\.co|\.com\.[a-z]{2}\.[a-z]{2}$|\.com\.[a-z]{2}$').hasMatch(host) &&
        !officialWhitelist.contains(host)) {
      return {
        "score": 88.0,
        "verdict": "CRÍTICO",
        "reason": "Dominio Sospechoso: TLD no estándar o extensión bancaria alterada."
      };
    }

    if (officialWhitelist.contains(host) || host.endsWith(".gov.co")) {
      return {
        "score": badProtocol ? 35.0 : 2.0,
        "verdict": badProtocol ? "SOSPECHOSO" : "SEGURO",
        "reason": badProtocol ? "Dominio oficial con protocolo alterado." : "Dominio oficial verificado."
      };
    }

    const brands = [
      "google",
      "facebook",
      "bancolombia",
      "nequi",
      "davivienda",
      "daviplata",
      "lulobank",
      "login",
      "seguro",
      "verificacion",
      "soporte"
    ];

    for (final brand in brands) {
      if (host.contains(brand) && !host.endsWith("$brand.com") && !host.endsWith("$brand.co")) {
        return {
          "score": 97.0,
          "verdict": "CRÍTICO",
          "reason": "Suplantación de Marca Identificada: Intento de Phishing imitando a $brand."
        };
      }
    }

    final current = host.split(".").first;

    for (final official in officialWhitelist) {
      final base = official.split(".").first;

      if (current.length >= 4 && levenshtein(current, base) <= 2 && current != base) {
        return {
          "score": 98.0,
          "verdict": "CRÍTICO",
          "reason": "Typosquatting Detectado: Coincidencia de distancia reducida con marca legítima ($base)."
        };
      }
    }

    if (host.contains("@")) {
      return {
        "score": 90.0,
        "verdict": "CRÍTICO",
        "reason": "Inyección Maliciosa: Uso de carácter '@' para deconstrucción de dominio."
      };
    }

    if (host.split("-").length > 4) {
      return {
        "score": 80.0,
        "verdict": "CRÍTICO",
        "reason": "Ofuscación de Dominio: Subdominios con múltiples guiones de enmascaramiento."
      };
    }

    if (badProtocol) {
      return {
        "score": 75.0,
        "verdict": "SOSPECHOSO",
        "reason": "Protocolo Inseguro o Alterado en la conexión."
      };
    }

    return {
      "score": 45.0,
      "verdict": "SOSPECHOSO",
      "reason": "Dominio no verificado en la lista blanca de reputación local."
    };
  }
}