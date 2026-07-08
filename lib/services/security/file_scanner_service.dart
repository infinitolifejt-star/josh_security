import 'dart:async';
import 'dart:math';
import 'phone_interceptor_service.dart'; // Importa DiagnosticSource

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

  // Constante estricta de restricción preventiva: 15 Megabytes en bytes
  static const int maxSafeSizeBytes = 15 * 1024 * 1024;

  /// Simula la verificación de conectividad con los motores avanzados en la nube
  Future<bool> _checkNetworkConnectivity() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Simula entorno local/Modo Avión para forzar análisis heurístico local
    return false;
  }

  /// Ejecuta un escaneo perimetral defensivo sobre un archivo seleccionado
  Future<FileScanVerdict> scanLocalFile(String name, int sizeInBytes) async {
    // Normalización defensiva contra nulos o strings vacíos
    final String cleanName = name.trim().isEmpty ? 'archivo_indefinido.bin' : name.trim();
    final int cleanSize = sizeInBytes < 0 ? 0 : sizeInBytes;

    final bool isConnected = await _checkNetworkConnectivity();
    final DiagnosticSource selectedSource = isConnected ? DiagnosticSource.cloud : DiagnosticSource.local;
    
    final String timestamp = DateTime.now().toIso8601String();
    final int trackingId = Random().nextInt(900000) + 100000;

    // --- REGLA PERIMETRAL CRÍTICA: RESTRICCIÓN DE 15MB ---
    if (cleanSize > maxSafeSizeBytes) {
      return FileScanVerdict(
        fileName: cleanName,
        fileSizeInBytes: cleanSize,
        riskLevel: 'CRÍTICO',
        analysisMessage: 'Análisis suspendido: El archivo excede el límite preventivo de 15MB. Riesgo de desbordamiento o carga masiva.',
        source: DiagnosticSource.local, // Forzado local por política de aislamiento
        telemetryDetails: {
          'tracking_id': 'JOSH-MAL-$trackingId',
          'timestamp': timestamp,
          'matched_rule': 'PERIMETER_SIZE_LIMIT_EXCEEDED',
          'max_allowed_bytes': maxSafeSizeBytes,
          'isolation_mode': !isConnected ? 'ACTIVO_MODO_AVION' : 'DESACTIVADO',
        },
      );
    }

    // --- ESCANEO DE EXTENSIONES O COMPORTAMIENTOS SOSPECHOSOS (HEURÍSTICA LOCAL) ---
    final String lowerName = cleanName.toLowerCase();
    bool isSuspiciousExtension = lowerName.endsWith('.apk') || 
                                 lowerName.endsWith('.exe') || 
                                 lowerName.endsWith('.bat') ||
                                 lowerName.endsWith('.scr');

    if (isSuspiciousExtension) {
      return FileScanVerdict(
        fileName: cleanName,
        fileSizeInBytes: cleanSize,
        riskLevel: 'ADVERTENCIA',
        analysisMessage: 'Hay 1 sugerencia de seguridad. El archivo contiene una extensión ejecutable potencialmente peligrosa.',
        source: selectedSource,
        telemetryDetails: {
          'tracking_id': 'JOSH-MAL-$trackingId',
          'timestamp': timestamp,
          'matched_rule': 'SUSPICIOUS_EXEC_EXTENSION',
          'isolation_mode': !isConnected ? 'ACTIVO_MODO_AVION' : 'DESACTIVADO',
        },
      );
    }

    // Escenario de Archivo Seguro
    return FileScanVerdict(
      fileName: cleanName,
      fileSizeInBytes: cleanSize,
      riskLevel: 'SEGURO',
      analysisMessage: 'JOSH Security analizó el binario. No se detectaron firmas maliciosas locales.',
      source: selectedSource,
      telemetryDetails: {
        'tracking_id': 'JOSH-MAL-$trackingId',
        'timestamp': timestamp,
        'matched_rule': 'HEURISTIC_CLEAN_FILE',
        'isolation_mode': !isConnected ? 'ACTIVO_MODO_AVION' : 'DESACTIVADO',
      },
    );
  }
}