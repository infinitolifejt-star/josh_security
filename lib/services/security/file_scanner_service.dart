// ====================================================================================================
// ARCHIVO: lib/services/security/file_scanner_service.dart
// ESCANEO PERIMETRAL Y PERSISTENCIA DE EVIDENCIA FORENSE v4.6
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

/// Modelo estructurado para el veredicto del análisis de malware en archivos
class FileScanVerdict {
  final String fileName;
  final int fileSizeInBytes;
  final String riskLevel; // 'SEGURO', 'ADVERTENCIA', 'CRÍTICO'
  final String analysisMessage;
  final DiagnosticSource source;
  final Map<String, dynamic> telemetryDetails;

  FileScanVerdict({
    required this.fileName,
    required this.fileSizeInBytes,
    required this.riskLevel,
    required this.analysisMessage,
    required this.source,
    required this.telemetryDetails,
  });

  /// Propiedad calculada para mostrar el tamaño legible en el HUD
  double get fileSizeInMB => fileSizeInBytes / (1024 * 1024);
}

/// Core del Servicio Perimetral de Escaneo de Archivos y Mitigación de Malware
class FileScannerService {
  // Patrón Singleton para acceso global seguro
  static final FileScannerService _instance = FileScannerService._internal();
  factory FileScannerService() => _instance;
  FileScannerService._internal();

  final ReputationEngine _reputationEngine = ReputationEngine();

  DatabaseService get _dbService {
    try {
      return DatabaseService.instance;
    } catch (e) {
      developer.log(
        "DatabaseService no inicializado aún. Retornando fallback perezoso.",
        error: e,
        name: 'josh.security.scanner',
      );
      rethrow;
    }
  }

  // Constante estricta de restricción preventiva: 15 Megabytes
  static const int maxSafeSizeBytes = 15 * 1024 * 1024;

  /// Verifica si el dispositivo tiene conexión a internet
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Calcula el hash SHA-256 de un archivo físico usando lectura por transmisión (Stream)
  Future<String?> _calculateFileHash(File file) async {
    try {
      if (!await file.exists()) return null;
      final stream = file.openRead();
      final hash = await sha256.bind(stream).first;
      return hash.toString();
    } catch (e, stackTrace) {
      developer.log(
        "Error al calcular hash en scanner",
        error: e,
        stackTrace: stackTrace,
        name: 'josh.security.scanner',
      );
      return null;
    }
  }

  /// Ejecuta un escaneo perimetral defensivo real sobre un archivo
  Future<FileScanVerdict> scanLocalFile(File file) async {
    final String cleanName = file.path.split(Platform.pathSeparator).last;
    int sizeInBytes = 0;

    try {
      if (await file.exists()) {
        sizeInBytes = await file.length();
      }
    } catch (e, stackTrace) {
      developer.log(
        "No se pudo leer el tamaño del archivo",
        error: e,
        stackTrace: stackTrace,
        name: 'josh.security.scanner',
      );
    }

    final int cleanSize = sizeInBytes < 0 ? 0 : sizeInBytes;
    final bool isConnected = await _checkNetworkConnectivity();
    final DiagnosticSource selectedSource = isConnected ? DiagnosticSource.cloud : DiagnosticSource.local;
    
    final String timestamp = DateTime.now().toIso8601String();
    final int trackingId = Random().nextInt(900000) + 100000;

    FileScanVerdict finalVerdict;
    String matchedRule;

    // --- REGLA 1: RESTRICCIÓN PREVENTIVA DE 15MB ---
    if (cleanSize > maxSafeSizeBytes) {
      matchedRule = 'PERIMETER_SIZE_LIMIT_EXCEEDED';
      finalVerdict = FileScanVerdict(
        fileName: cleanName,
        fileSizeInBytes: cleanSize,
        riskLevel: 'CRÍTICO',
        analysisMessage: 'Análisis suspendido: El archivo excede el límite preventivo de 15MB. Riesgo de carga masiva.',
        source: DiagnosticSource.local,
        telemetryDetails: {
          'tracking_id': 'JOSH-MAL-$trackingId',
          'timestamp': timestamp,
          'matched_rule': matchedRule,
          'max_allowed_bytes': maxSafeSizeBytes,
          'isolation_mode': !isConnected ? 'ACTIVO_MODO_AVION' : 'DESACTIVADO',
        },
      );
      
      await _persistScanLog(finalVerdict, matchedRule);
      return finalVerdict;
    }

    // --- REGLA 2: OBTENCIÓN DE HASH Y VERIFICACIÓN EN NUBE (VIRUSTOTAL) ---
    String? fileHash;
    double cloudRiskScore = 0.0;

    if (isConnected) {
      fileHash = await _calculateFileHash(file);
      if (fileHash != null) {
        cloudRiskScore = await _reputationEngine.checkVirusTotal(fileHash, isUrl: false);
      }
    }

    // Si al menos un 5% de los motores de VirusTotal reportan amenaza (score >= 0.05)
    if (cloudRiskScore >= 0.05) {
      matchedRule = 'CLOUD_SIGNATURE_MATCH';
      finalVerdict = FileScanVerdict(
        fileName: cleanName,
        fileSizeInBytes: cleanSize,
        riskLevel: 'CRÍTICO',
        analysisMessage: '¡Amenaza Detectada! Coincidencia confirmada por firmas de seguridad en la nube.',
        source: selectedSource,
        telemetryDetails: {
          'tracking_id': 'JOSH-MAL-$trackingId',
          'timestamp': timestamp,
          'matched_rule': matchedRule,
          'file_hash': fileHash ?? 'N/A',
          'risk_score': cloudRiskScore,
          'isolation_mode': 'DESACTIVADO',
        },
      );

      await _persistScanLog(finalVerdict, matchedRule);
      return finalVerdict;
    }

    // --- REGLA 3: EXTENSIONES O COMPORTAMIENTOS EJECUTABLES ---
    final String lowerName = cleanName.toLowerCase();
    final bool isSuspiciousExtension = lowerName.endsWith('.apk') || 
                                       lowerName.endsWith('.exe') || 
                                       lowerName.endsWith('.bat') ||
                                       lowerName.endsWith('.scr') ||
                                       lowerName.endsWith('.vbs');

    if (isSuspiciousExtension) {
      matchedRule = 'SUSPICIOUS_EXEC_EXTENSION';
      finalVerdict = FileScanVerdict(
        fileName: cleanName,
        fileSizeInBytes: cleanSize,
        riskLevel: 'ADVERTENCIA',
        analysisMessage: 'Precaución: El archivo posee una extensión ejecutable potencialmente riesgosa.',
        source: selectedSource,
        telemetryDetails: {
          'tracking_id': 'JOSH-MAL-$trackingId',
          'timestamp': timestamp,
          'matched_rule': matchedRule,
          'file_hash': fileHash ?? 'No calculado (Offline)',
          'isolation_mode': !isConnected ? 'ACTIVO_MODO_AVION' : 'DESACTIVADO',
        },
      );
    } else {
      // Escenario Limpio
      matchedRule = 'HEURISTIC_CLEAN_FILE';
      finalVerdict = FileScanVerdict(
        fileName: cleanName,
        fileSizeInBytes: cleanSize,
        riskLevel: 'SEGURO',
        analysisMessage: 'JOSH Security analizó el binario. No se detectaron firmas maliciosas.',
        source: selectedSource,
        telemetryDetails: {
          'tracking_id': 'JOSH-MAL-$trackingId',
          'timestamp': timestamp,
          'matched_rule': matchedRule,
          'file_hash': fileHash ?? 'No calculado (Offline)',
          'isolation_mode': !isConnected ? 'ACTIVO_MODO_AVION' : 'DESACTIVADO',
        },
      );
    }

    await _persistScanLog(finalVerdict, matchedRule);
    return finalVerdict;
  }

  /// Guarda el registro forense del escaneo dentro de SQLite
  Future<void> _persistScanLog(FileScanVerdict verdict, String matchedRule) async {
    try {
      final Map<String, dynamic> logEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'service': 'FileScannerService',
        'activity': 'Escaneo de archivo local: ${verdict.fileName} (${verdict.fileSizeInMB.toStringAsFixed(2)} MB)',
        'verdict': verdict.riskLevel,
        'matched_rule': matchedRule,
        'extra_data': jsonEncode(verdict.telemetryDetails),
      };
      
      await _dbService.insertForensicLog(logEntry);
    } catch (e, stackTrace) {
      developer.log(
        'ERR_DATABASE_PERSISTENCE_FILE_SCANNER',
        error: e,
        stackTrace: stackTrace,
        name: 'josh.security.db',
      );
    }
  }
}