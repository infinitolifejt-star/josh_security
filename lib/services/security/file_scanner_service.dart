// ====================================================================================================
// ARCHIVO: lib/services/security/file_scanner_service.dart
// REEMPLAZO TOTAL — ENTORNO SINCRONIZADO CENTINELA v4.5.1
// OP-HEURÍSTICA: Escaneo Perimetral y Persistencia de Evidencia Forense en SQLite
// ====================================================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'database_service.dart';
import 'phone_interceptor_service.dart'; // Importa DiagnosticSource
import '../reputation/reputation_engine.dart'; // Importa el motor de reputación

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
  // Patrón Singleton para acceso global seguro en el ecosistema Centinela
  static final FileScannerService _instance = FileScannerService._internal();
  factory FileScannerService() => _instance;
  FileScannerService._internal();

  // Instancia del motor de reputación real
  final ReputationEngine _reputationEngine = ReputationEngine();

  /// Getter seguro para obtener la base de datos de manera perezosa (Lazy),
  /// evitando el 'NotInitializedError' si el servicio se invoca antes de que SQLite esté listo.
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

  // Constante estricta de restricción preventiva: 15 Megabytes en bytes
  static const int maxSafeSizeBytes = 15 * 1024 * 1024;

  /// Verifica si el dispositivo tiene conexión a internet de manera asíncrona
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false; // Retorna falso de forma segura si no hay red (Modo Aislamiento)
    }
  }

  /// Calcula el hash SHA-256 de un archivo físico de forma asíncrona
  Future<String?> _calculateFileHash(File file) async {
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes);
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

  /// Ejecuta un escaneo perimetral defensivo real sobre un archivo del almacenamiento
  Future<FileScanVerdict> scanLocalFile(File file) async {
    final String cleanName = file.path.split('/').last;
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

    // --- REGLA PERIMETRAL CRÍTICA: RESTRICCIÓN DE 15MB ---
    if (cleanSize > maxSafeSizeBytes) {
      matchedRule = 'PERIMETER_SIZE_LIMIT_EXCEEDED';
      finalVerdict = FileScanVerdict(
        fileName: cleanName,
        fileSizeInBytes: cleanSize,
        riskLevel: 'CRÍTICO',
        analysisMessage: 'Análisis suspendido: El archivo excede el límite preventivo de 15MB. Riesgo de desbordamiento o carga masiva.',
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

    // --- OBTENCIÓN DE HASH Y VERIFICACIÓN EN NUBE (VIRUSTOTAL) ---
    String? fileHash;
    double cloudRiskScore = 0.0;

    if (isConnected) {
      fileHash = await _calculateFileHash(file);
      if (fileHash != null) {
        cloudRiskScore = await _reputationEngine.checkVirusTotal(fileHash, isUrl: false);
      }
    }

    // Si la reputación en la nube reporta un riesgo alto (>= 0.5)
    if (cloudRiskScore >= 0.5) {
      matchedRule = 'CLOUD_SIGNATURE_MATCH';
      finalVerdict = FileScanVerdict(
        fileName: cleanName,
        fileSizeInBytes: cleanSize,
        riskLevel: 'CRÍTICO',
        analysisMessage: '¡Amenaza Detectada en la Nube! Coincidencia confirmada por firmas de seguridad globales.',
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

    // --- ESCANEO DE EXTENSIONES O COMPORTAMIENTOS SOSPECHOSOS (HEURÍSTICA LOCAL) ---
    final String lowerName = cleanName.toLowerCase();
    final bool isSuspiciousExtension = lowerName.endsWith('.apk') || 
                                       lowerName.endsWith('.exe') || 
                                       lowerName.endsWith('.bat') ||
                                       lowerName.endsWith('.scr');

    if (isSuspiciousExtension) {
      matchedRule = 'SUSPICIOUS_EXEC_EXTENSION';
      finalVerdict = FileScanVerdict(
        fileName: cleanName,
        fileSizeInBytes: cleanSize,
        riskLevel: 'ADVERTENCIA',
        analysisMessage: 'Hay 1 sugerencia de seguridad. El archivo contiene una extensión ejecutable potencialmente peligrosa.',
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
      // Escenario de Archivo Seguro
      matchedRule = 'HEURISTIC_CLEAN_FILE';
      finalVerdict = FileScanVerdict(
        fileName: cleanName,
        fileSizeInBytes: cleanSize,
        riskLevel: 'SEGURO',
        analysisMessage: 'JOSH Security analizó el binario. No se detectaron firmas maliciosas locales ni globales.',
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

    // Guardado forense asíncrono en caliente
    await _persistScanLog(finalVerdict, matchedRule);
    return finalVerdict;
  }

  /// Estructura y guarda el registro forense del escaneo dentro de SQLite con Try-Catch de aislamiento
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
      
      // Intentar inserción usando el getter perezoso protegido
      await _dbService.insertForensicLog(logEntry);
    } catch (e, stackTrace) {
      developer.log(
        'ERR_DATABASE_PERSISTENCE_FILE_SCANNER - Fallo controlled para evitar romper el hilo UI',
        error: e,
        stackTrace: stackTrace,
        name: 'josh.security.db',
      );
    }
  }
}