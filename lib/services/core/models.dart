// lib/services/core/models.dart

/// Representa el registro estructural de una llamada entrante capturada por el Centinela
class CallRecord {
  final String phone;
  final DateTime timestamp;
  final int durationSeconds;

  // Constructor constante para optimización de memoria en colecciones extensas
  const CallRecord({
    required this.phone,
    required this.timestamp,
    required this.durationSeconds,
  });
}

/// Contenedor inmutable de los resultados de diagnóstico y heurística calculados
class AnalysisResult {
  final double riskScore; // Espectro normalizado de 0.0 a 1.0
  final String classification; // SAFE, SUSPICIOUS o CRITICAL
  final Map<String, double> metrics; // Desglose interno de vectores analíticos

  // Constructor constante que blinda el resultado contra mutaciones en tiempo de ejecución
  const AnalysisResult({
    required this.riskScore,
    required this.classification,
    required this.metrics,
  });
}