// ====================================================================================================
// ARCHIVO: lib/services/security/file_scanner_service.dart
// MOTOR DE ESCANEO PERIMETRAL DE ARCHIVOS
// JOSH SECURITY v6.0 - ARQUITECTURA DE DECISIÓN UNIFICADA
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
  final int riskScore; // Medido de 0 a 100
  final String riskLevel; // Estado Semántico: SIN_AMENAZAS, ADVERTENCIA, CRÍTICO, etc.
  final String analysisMessage;
  final DiagnosticSource source;
  final Map<String, dynamic> telemetryDetails;

  const FileScanVerdict({
    required this.fileName,
    required this.fileSizeInBytes,
    required this.riskScore,
    required this.riskLevel,
    required this.analysisMessage,
    required this.source,
    required this.telemetryDetails,
  });

  double get fileSizeInMB => fileSizeInBytes / (1024 * 1024);

  bool get isCritical => riskScore >= 80;
  bool get isWarning => riskScore >= 40 && riskScore < 80;
  bool get isSafe => riskScore < 40;
}

class FileScannerService {
  FileScannerService._internal();

  static final FileScannerService instance = FileScannerService._internal();

  factory FileScannerService() => instance;

  final ReputationEngine _reputation = ReputationEngine();

  DatabaseService get _database => DatabaseService.instance;

  // Límite de 15 MB para análisis dinámico local/nube
  static const int maxSafeSizeBytes = 15 * 1024 * 1024;

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup("google.com")
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
      final hash = await sha256.bind(file.openRead()).first;
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

  // ================================================================================================
  // ANÁLISIS DE ARCHIVOS
  // ================================================================================================

  Future<FileScanVerdict> scanLocalFile(File file) async {
    final filename = file.path.split(Platform.pathSeparator).last;
    int size = 0;

    try {
      if (await file.exists()) {
        size = await file.length();
      }
    } catch (_) {}

    final connected = await _hasInternet();
    final source = connected ? DiagnosticSource.cloud : DiagnosticSource.local;
    final tracking = Random().nextInt(900000) + 100000;
    final timestamp = DateTime.now().toIso8601String();

    // ----------------------------------------------------------------------------------------------
    // CAPA 1: VALIDACIÓN DE TAMAÑO Y LÍMITE PERIMETRAL
    // ----------------------------------------------------------------------------------------------
    if (size > maxSafeSizeBytes) {
      final verdict = FileScanVerdict(
        fileName: filename,
        fileSizeInBytes: size,
        riskScore: 25, // Un peso excesivo es observación/advertencia de tamaño, NUNCA malware crítico.
        riskLevel: "ADVERTENCIA_TAMAÑO",
        analysisMessage: "El archivo supera los 15 MB. Se omitió la inspección profunda en la nube por límites perimetrales.",
        source: DiagnosticSource.local,
        telemetryDetails: {
          "tracking_id": "JOSH-$tracking",
          "matched_rule": "MAX_SIZE_LIMIT_EXCEEDED",
          "timestamp": timestamp,
          "size": size,
        },
      );

      await _persistScanLog(verdict, "MAX_SIZE_LIMIT_EXCEEDED");
      return verdict;
    }

    // ----------------------------------------------------------------------------------------------
    // CAPA 2: INTEGRIDAD Y REPUTACIÓN POR HASH (SHA-256 / VIRUSTOTAL)
    // ----------------------------------------------------------------------------------------------
    String? hash;
    double cloudScore = 0;

    if (connected) {
      hash = await _sha256(file);
      if (hash != null) {
        cloudScore = await _reputation.checkVirusTotal(
          hash,
          isUrl: false,
        );
      }
    }

    if (cloudScore >= 0.05) {
      final calculatedRisk = (cloudScore * 100).toInt().clamp(80, 100);
      final verdict = FileScanVerdict(
        fileName: filename,
        fileSizeInBytes: size,
        riskScore: calculatedRisk,
        riskLevel: "CRÍTICO",
        analysisMessage: "Firma de malware confirmada en bases de reputación global.",
        source: source,
        telemetryDetails: {
          "tracking_id": "JOSH-$tracking",
          "matched_rule": "VIRUSTOTAL_REPUTATION_MATCH",
          "risk_raw": cloudScore,
          "hash": hash,
          "timestamp": timestamp,
        },
      );

      await _persistScanLog(verdict, "VIRUSTOTAL_REPUTATION_MATCH");
      return verdict;
    }

    // ----------------------------------------------------------------------------------------------
    // CAPA 3: EXTENSIÓN Y HEURÍSTICA DE ESTRUCTURA
    // ----------------------------------------------------------------------------------------------
    final lowerName = filename.toLowerCase();

    final isExecutable = lowerName.endsWith(".apk") ||
        lowerName.endsWith(".exe") ||
        lowerName.endsWith(".bat") ||
        lowerName.endsWith(".cmd") ||
        lowerName.endsWith(".scr") ||
        lowerName.endsWith(".vbs") ||
        lowerName.endsWith(".ps1") ||
        lowerName.endsWith(".jar");

    if (isExecutable) {
      final verdict = FileScanVerdict(
        fileName: filename,
        fileSizeInBytes: size,
        riskScore: 50, // Ejecutable sin firma conocida = Advertencia preventiva, no condena automática
        riskLevel: "ADVERTENCIA",
        analysisMessage: "Archivo con capacidad de ejecución detectado. Verifique su origen antes de instalar o ejecutar.",
        source: source,
        telemetryDetails: {
          "tracking_id": "JOSH-$tracking",
          "matched_rule": "EXECUTABLE_EXTENSION_PREVENTIVE",
          "hash": hash ?? "OFFLINE",
          "timestamp": timestamp,
        },
      );

      await _persistScanLog(verdict, "EXECUTABLE_EXTENSION_PREVENTIVE");
      return verdict;
    }

    // ----------------------------------------------------------------------------------------------
    // CAPA 4: DOCUMENTO O ARCHIVO LIMPIO
    // ----------------------------------------------------------------------------------------------
    final verdict = FileScanVerdict(
      fileName: filename,
      fileSizeInBytes: size,
      riskScore: 0,
      riskLevel: "SIN_AMENAZAS",
      analysisMessage: "No se encontraron indicadores de compromiso ni código malicioso en las comprobaciones realizadas.",
      source: source,
      telemetryDetails: {
        "tracking_id": "JOSH-$tracking",
        "matched_rule": "CLEAN_FILE",
        "hash": hash ?? "OFFLINE",
        "timestamp": timestamp,
      },
    );

    await _persistScanLog(verdict, "CLEAN_FILE");
    return verdict;
  }

  // ================================================================================================
  // PERSISTENCIA FORENSE
  // ================================================================================================

  Future<void> _persistScanLog(
    FileScanVerdict verdict,
    String matchedRule,
  ) async {
    try {
      await _database.insertForensicLog({
        "timestamp": DateTime.now().toIso8601String(),
        "service": "FileScannerService",
        "activity": "Escaneo de archivo: ${verdict.fileName}",
        "verdict": verdict.riskLevel,
        "risk_score": verdict.riskScore,
        "matched_rule": matchedRule,
        "extra_data": jsonEncode(verdict.telemetryDetails),
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