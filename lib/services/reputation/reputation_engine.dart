// ====================================================================================================
// ARCHIVO: lib/services/reputation/reputation_engine.dart
// MOTOR DE REPUTACIÓN JOSH SECURITY v6.0
// Google Safe Browsing + VirusTotal + Motor de Riesgo
// ====================================================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ReputationEngine {
  ReputationEngine();

  String get _virusTotalKey =>
      dotenv.env["VIRUSTOTAL_API_KEY"] ?? "";

  String get _safeBrowsingKey =>
      dotenv.env["GOOGLE_SAFE_BROWSING_API_KEY"] ?? "";

  //==========================================================================
  // MOTOR DE RIESGO LOCAL
  //==========================================================================

  double computeRiskScore({
    required double entropy,
    required double frequency,
    required double timeRisk,
    required double durationRisk,
    required double communityScore,
  }) {
    final score =
        entropy * 0.25 +
        frequency * 0.20 +
        timeRisk * 0.20 +
        durationRisk * 0.15 +
        communityScore * 0.20;

    return score.clamp(0.0, 100.0);
  }

  //==========================================================================
  // GOOGLE SAFE BROWSING
  //==========================================================================

  Future<bool> checkUrlSafeBrowsing(
    String url,
  ) async {

    if (_safeBrowsingKey.isEmpty) {
      return false;
    }

    try {

      final endpoint =
          "https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$_safeBrowsingKey";

      final response =
          await http.post(

        Uri.parse(endpoint),

        headers: {
          "Content-Type":
              "application/json",
        },

        body: jsonEncode({

          "client": {

            "clientId":
                "josh-security",

            "clientVersion":
                "6.0",

          },

          "threatInfo": {

            "threatTypes": [

              "MALWARE",

              "SOCIAL_ENGINEERING",

              "UNWANTED_SOFTWARE",

              "POTENTIALLY_HARMFUL_APPLICATION"

            ],

            "platformTypes": [
              "ANY_PLATFORM"
            ],

            "threatEntryTypes": [
              "URL"
            ],

            "threatEntries": [
              {
                "url": url
              }
            ],

          }

        }),

      ).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode != 200) {
        return false;
      }

      final data =
          jsonDecode(response.body);

      return data["matches"] != null;

    } on TimeoutException {

      debugPrint(
          "Google Safe Browsing timeout");

      return false;

    } catch (e) {

      debugPrint(
          "Safe Browsing error: $e");

      return false;
    }
  }

  //==========================================================================
  // VIRUSTOTAL
  //==========================================================================

  Future<double> checkVirusTotal(
    String target, {
    bool isUrl = false,
  }) async {

    if (_virusTotalKey.isEmpty) {
      return 0;
    }

    try {

      final id = isUrl

          ? base64Url
              .encode(utf8.encode(target))
              .replaceAll("=", "")

          : target;

      final endpoint = isUrl

          ? "https://www.virustotal.com/api/v3/urls/$id"

          : "https://www.virustotal.com/api/v3/files/$id";

      final response =
          await http.get(

        Uri.parse(endpoint),

        headers: {
          "x-apikey":
              _virusTotalKey,
        },

      ).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode != 200) {
        return 0;
      }

      final json =
          jsonDecode(response.body);

      final stats =
          json["data"]["attributes"]
              ["last_analysis_stats"];

      final malicious =
          stats["malicious"] ?? 0;

      final suspicious =
          stats["suspicious"] ?? 0;

      final harmless =
          stats["harmless"] ?? 1;

      final total =
          malicious +
          suspicious +
          harmless;

      if (total == 0) {
        return 0;
      }

      return (malicious + suspicious) /
          total;

    } on TimeoutException {

      debugPrint(
          "VirusTotal timeout");

      return 0;

    } catch (e) {

      debugPrint(
          "VirusTotal error: $e");

      return 0;
    }
  }

  //==========================================================================
  // REPUTACIÓN COMPLETA
  //==========================================================================

  Future<double> evaluateCompleteReputation({

    required String url,

    required double localHeuristicScore,

  }) async {

    final googleThreat =
        await checkUrlSafeBrowsing(url);

    final vt =
        await checkVirusTotal(
      url,
      isUrl: true,
    );

    final google =
        googleThreat ? 100.0 : 0.0;

    final virusTotal =
        (vt * 100);

    final finalScore =

        localHeuristicScore * 0.40 +

        google * 0.30 +

        virusTotal * 0.30;

    return finalScore.clamp(
      0,
      100,
    );
  }

  //==========================================================================
  // CLASIFICACIÓN
  //==========================================================================

  String classify(
    double score,
  ) {

    if (score < 30) {
      return "SEGURO";
    }

    if (score < 70) {
      return "ADVERTENCIA";
    }

    return "CRÍTICO";
  }
}