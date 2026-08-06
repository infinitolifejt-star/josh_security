// ====================================================================================================
// ARCHIVO: lib/services/security/file_scanner_service.dart
// MOTOR DE ESCANEO PERIMETRAL JOSH SECURITY v6.0
// Primera Parte
// ====================================================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'database_service.dart';
import 'phone_interceptor_service.dart';
import '../reputation/reputation_engine.dart';

class FileScanVerdict {
  final String fileName;
  final int fileSizeInBytes;
  final String riskLevel;
  final String analysisMessage;
  final DiagnosticSource source;
  final Map<String, dynamic> telemetryDetails;

  const FileScanVerdict({
    required this.fileName,
    required this.fileSizeInBytes,
    required this.riskLevel,
    required this.analysisMessage,
    required this.source,
    required this.telemetryDetails,
  });

  double get fileSizeInMB =>
      fileSizeInBytes / (1024 * 1024);

  bool get isCritical =>
      riskLevel == "CRÍTICO";

  bool get isWarning =>
      riskLevel == "ADVERTENCIA";

  bool get isSafe =>
      riskLevel == "SEGURO";
}

class FileScannerService {

  FileScannerService._internal();

  static final FileScannerService instance =
      FileScannerService._internal();

  factory FileScannerService() => instance;

  final ReputationEngine _reputation =
      ReputationEngine();

  DatabaseService get _database =>
      DatabaseService.instance;

  static const int maxSafeSizeBytes =
      15 * 1024 * 1024;

  Future<bool> _hasInternet() async {
    try {

      final result =
          await InternetAddress.lookup("google.com")
              .timeout(const Duration(seconds: 2));

      return result.isNotEmpty;

    } catch (_) {
      return false;
    }
  }

  Future<String?> _sha256(File file) async {

    try {

      if (!await file.exists()) {
        return null;
      }

      final hash =
          await sha256.bind(file.openRead()).first;

      return hash.toString();

    } catch (e, s) {

      developer.log(
        "SHA256 ERROR",
        error: e,
        stackTrace: s,
        name: "FileScanner",
      );

      return null;
    }
  }

  Future<FileScanVerdict> scanLocalFile(
      File file) async {

    final filename =
        file.path.split(Platform.pathSeparator).last;

    int size = 0;

    try {

      if (await file.exists()) {
        size = await file.length();
      }

    } catch (_) {}

    final connected =
        await _hasInternet();

    final source = connected
        ? DiagnosticSource.cloud
        : DiagnosticSource.local;

    final tracking =
        Random().nextInt(900000) + 100000;

    final timestamp =
        DateTime.now().toIso8601String();

    //----------------------------------------------------------------------
    // LIMITE PERIMETRAL
    //----------------------------------------------------------------------

    if (size > maxSafeSizeBytes) {

      final verdict = FileScanVerdict(

        fileName: filename,

        fileSizeInBytes: size,

        riskLevel: "CRÍTICO",

        analysisMessage:
            "Archivo superior a 15 MB. Escaneo detenido por seguridad.",

        source: DiagnosticSource.local,

        telemetryDetails: {

          "tracking_id":
              "JOSH-$tracking",

          "matched_rule":
              "MAX_SIZE_LIMIT",

          "timestamp":
              timestamp,

          "size":
              size,

        },
      );

      await _persistScanLog(
          verdict,
          "MAX_SIZE_LIMIT");

      return verdict;
    }

    //----------------------------------------------------------------------
    // SHA256
    //----------------------------------------------------------------------

    String? hash;

    double cloudScore = 0;

    if (connected) {

      hash = await _sha256(file);

      if (hash != null) {

        cloudScore =
            await _reputation.checkVirusTotal(
          hash,
          isUrl: false,
        );
      }
    }

    //----------------------------------------------------------------------
    // VIRUSTOTAL
    //----------------------------------------------------------------------

    if (cloudScore >= 0.05) {

      final verdict = FileScanVerdict(

        fileName: filename,

        fileSizeInBytes: size,

        riskLevel: "CRÍTICO",

        analysisMessage:
            "VirusTotal reporta firmas maliciosas.",

        source: source,

        telemetryDetails: {

          "tracking_id":
              "JOSH-$tracking",

          "matched_rule":
              "VIRUSTOTAL_MATCH",

          "risk":
              cloudScore,

          "hash":
              hash,

          "timestamp":
              timestamp,

        },
      );

      await _persistScanLog(
          verdict,
          "VIRUSTOTAL_MATCH");

      return verdict;
    }

    //----------------------------------------------------------------------
    // HEURISTICAS LOCALES
    //----------------------------------------------------------------------

    final lower =
        filename.toLowerCase();

    final executable =

        lower.endsWith(".apk") ||
        lower.endsWith(".exe") ||
        lower.endsWith(".bat") ||
        lower.endsWith(".cmd") ||
        lower.endsWith(".scr") ||
        lower.endsWith(".vbs") ||
        lower.endsWith(".ps1") ||
        lower.endsWith(".jar");
    if (executable) {

      final verdict = FileScanVerdict(

        fileName: filename,

        fileSizeInBytes: size,

        riskLevel: "ADVERTENCIA",

        analysisMessage:
            "Archivo ejecutable detectado. Se recomienda verificar su procedencia antes de abrirlo.",

        source: source,

        telemetryDetails: {

          "tracking_id": "JOSH-$tracking",

          "matched_rule": "EXECUTABLE_FILE",

          "hash": hash ?? "OFFLINE",

          "timestamp": timestamp,

        },
      );

      await _persistScanLog(
        verdict,
        "EXECUTABLE_FILE",
      );

      return verdict;
    }

    //----------------------------------------------------------------------
    // ARCHIVO LIMPIO
    //----------------------------------------------------------------------

    final verdict = FileScanVerdict(

      fileName: filename,

      fileSizeInBytes: size,

      riskLevel: "SEGURO",

      analysisMessage:
          "No se detectaron indicadores de compromiso ni firmas maliciosas.",

      source: source,

      telemetryDetails: {

        "tracking_id": "JOSH-$tracking",

        "matched_rule": "CLEAN_FILE",

        "hash": hash ?? "OFFLINE",

        "timestamp": timestamp,

      },
    );

    await _persistScanLog(
      verdict,
      "CLEAN_FILE",
    );

    return verdict;
  }

  //==========================================================================
  // PERSISTENCIA FORENSE
  //==========================================================================

  Future<void> _persistScanLog(
    FileScanVerdict verdict,
    String matchedRule,
  ) async {

    try {

      await _database.insertForensicLog({

        "timestamp":
            DateTime.now().toIso8601String(),

        "service":
            "FileScannerService",

        "activity":
            "Escaneo de archivo: ${verdict.fileName}",

        "verdict":
            verdict.riskLevel,

        "matched_rule":
            matchedRule,

        "extra_data":
            jsonEncode(verdict.telemetryDetails),

      });

    } catch (e, s) {

      developer.log(

        "DATABASE_ERROR",

        name: "FileScannerService",

        error: e,

        stackTrace: s,

      );
    }
  }
}
