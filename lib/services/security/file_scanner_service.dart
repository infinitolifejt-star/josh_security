// ============================================================================
// ARCHIVO: lib/services/security/file_scanner_service.dart
// MOTOR DE ESCANEO PERIMETRAL DE ARCHIVOS
// JOSH SECURITY v6.0
// ============================================================================

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../reputation/reputation_engine.dart';
import 'database_service.dart';
import 'phone_interceptor_service.dart';

class FileScanVerdict {
  final String fileName;
  final int fileSizeInBytes;
  final int riskScore;
  final String riskLevel;
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

  double get fileSizeInMB =>
      fileSizeInBytes / (1024 * 1024);

  bool get isCritical => riskScore >= 80;

  bool get isWarning =>
      riskScore >= 40 && riskScore < 80;

  bool get isSafe => riskScore < 40;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fileName': fileName,
      'fileSizeInBytes': fileSizeInBytes,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'analysisMessage': analysisMessage,
      'source': source.name,
      'telemetryDetails': telemetryDetails,
    };
  }
}

class FileScannerService {
  FileScannerService._internal();

  static final FileScannerService instance =
      FileScannerService._internal();

  factory FileScannerService() => instance;

  final ReputationEngine _reputation = ReputationEngine();

  DatabaseService get _database =>
      DatabaseService.instance;

  static const int maxSafeSizeBytes =
      15 * 1024 * 1024;

  Future<bool> _hasInternet() async {
    try {
      final List<InternetAddress> result =
          await InternetAddress.lookup('google.com')
              .timeout(
        const Duration(seconds: 2),
      );

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

      final Digest hash =
          await sha256.bind(file.openRead()).first;

      return hash.toString();
    } catch (error, stackTrace) {
      developer.log(
        'SHA256 ERROR',
        error: error,
        stackTrace: stackTrace,
        name: 'FileScanner',
      );

      return null;
    }
  }

  Future<FileScanVerdict> scanLocalFile(
    File file,
  ) async {
    final String filename =
        file.path.split(Platform.pathSeparator).last;

    int size = 0;

    try {
      if (await file.exists()) {
        size = await file.length();
      }
    } catch (_) {}

    final bool connected = await _hasInternet();

    final DiagnosticSource source =
        connected
            ? DiagnosticSource.cloud
            : DiagnosticSource.local;

    final int tracking =
        Random().nextInt(900000) + 100000;

    final String timestamp =
        DateTime.now().toIso8601String();

    // ------------------------------------------------------------------------
    // CAPA 1: VALIDACIÓN DE TAMAÑO
    // ------------------------------------------------------------------------

    if (size > maxSafeSizeBytes) {
      final FileScanVerdict verdict =
          FileScanVerdict(
        fileName: filename,
        fileSizeInBytes: size,
        riskScore: 25,
        riskLevel: 'ADVERTENCIA_TAMAÑO',
        analysisMessage:
            'El archivo supera los 15 MB. '
            'Se omitió la inspección profunda '
            'por límites perimetrales.',
        source: DiagnosticSource.local,
        telemetryDetails: <String, dynamic>{
          'tracking_id': 'JOSH-$tracking',
          'matched_rule':
              'MAX_SIZE_LIMIT_EXCEEDED',
          'timestamp': timestamp,
          'size': size,
        },
      );

      await _persistScanLog(
        verdict,
        'MAX_SIZE_LIMIT_EXCEEDED',
      );

      return verdict;
    }

    // ------------------------------------------------------------------------
    // CAPA 2: SHA-256 + REPUTACIÓN
    // ------------------------------------------------------------------------

    String? hash;
    double cloudScore = 0.0;

    if (connected) {
      try {
        hash = await _sha256(file);

        if (hash != null && hash.isNotEmpty) {
          cloudScore =
              await _reputation.checkVirusTotal(
            hash,
            isUrl: false,
          );
        }
      } catch (error, stackTrace) {
        developer.log(
          'REPUTATION_ENGINE WARNING',
          name: 'FileScannerService',
          error: error,
          stackTrace: stackTrace,
        );

        cloudScore = 0.0;
      }
    }

    if (cloudScore >= 0.05) {
      final int calculatedRisk =
          (cloudScore * 100)
              .toInt()
              .clamp(80, 100);

      final FileScanVerdict verdict =
          FileScanVerdict(
        fileName: filename,
        fileSizeInBytes: size,
        riskScore: calculatedRisk,
        riskLevel: 'CRÍTICO',
        analysisMessage:
            'Firma de malware detectada '
            'por el sistema de reputación.',
        source: source,
        telemetryDetails: <String, dynamic>{
          'tracking_id': 'JOSH-$tracking',
          'matched_rule':
              'VIRUSTOTAL_REPUTATION_MATCH',
          'risk_raw': cloudScore,
          'hash': hash,
          'timestamp': timestamp,
        },
      );

      await _persistScanLog(
        verdict,
        'VIRUSTOTAL_REPUTATION_MATCH',
      );

      return verdict;
    }

    // ------------------------------------------------------------------------
    // CAPA 3: EXTENSIÓN EJECUTABLE
    // ------------------------------------------------------------------------

    final String lowerName =
        filename.toLowerCase();

    final bool isExecutable =
        lowerName.endsWith('.apk') ||
        lowerName.endsWith('.exe') ||
        lowerName.endsWith('.bat') ||
        lowerName.endsWith('.cmd') ||
        lowerName.endsWith('.scr') ||
        lowerName.endsWith('.vbs') ||
        lowerName.endsWith('.ps1') ||
        lowerName.endsWith('.jar');

    if (isExecutable) {
      final FileScanVerdict verdict =
          FileScanVerdict(
        fileName: filename,
        fileSizeInBytes: size,
        riskScore: 50,
        riskLevel: 'ADVERTENCIA',
        analysisMessage:
            'Archivo con capacidad de ejecución '
            'detectado. Verifique su origen antes '
            'de abrirlo o instalarlo.',
        source: source,
        telemetryDetails: <String, dynamic>{
          'tracking_id': 'JOSH-$tracking',
          'matched_rule':
              'EXECUTABLE_EXTENSION_PREVENTIVE',
          'hash': hash ?? 'OFFLINE',
          'timestamp': timestamp,
        },
      );

      await _persistScanLog(
        verdict,
        'EXECUTABLE_EXTENSION_PREVENTIVE',
      );

      return verdict;
    }

    // ------------------------------------------------------------------------
    // CAPA 4: ARCHIVO SIN INDICADORES
    // ------------------------------------------------------------------------

    final FileScanVerdict verdict =
        FileScanVerdict(
      fileName: filename,
      fileSizeInBytes: size,
      riskScore: 0,
      riskLevel: 'SIN_AMENAZAS',
      analysisMessage:
          'No se encontraron indicadores de compromiso '
          'en las comprobaciones realizadas.',
      source: source,
      telemetryDetails: <String, dynamic>{
        'tracking_id': 'JOSH-$tracking',
        'matched_rule': 'CLEAN_FILE',
        'hash': hash ?? 'OFFLINE',
        'timestamp': timestamp,
      },
    );

    await _persistScanLog(
      verdict,
      'CLEAN_FILE',
    );

    return verdict;
  }

  Future<void> _persistScanLog(
    FileScanVerdict verdict,
    String matchedRule,
  ) async {
    try {
      await _database.insertForensicLog(
        <String, dynamic>{
          'timestamp':
              DateTime.now().toIso8601String(),
          'service': 'FileScannerService',
          'activity':
              'Escaneo de archivo: '
              '${verdict.fileName}',
          'verdict': verdict.riskLevel,
          'risk_score': verdict.riskScore,
          'matched_rule': matchedRule,
          'extra_data':
              jsonEncode(verdict.telemetryDetails),
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'DATABASE_ERROR',
        name: 'FileScannerService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
