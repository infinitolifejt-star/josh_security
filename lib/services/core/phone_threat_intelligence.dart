// ====================================================================================================
// MODELO DE INTELIGENCIA DE AMENAZAS TELEFÓNICAS (JOSH SECURITY v6.0)
// Unifica el análisis local del Centinela con la inteligencia externa (IPQS / Backend Python)
// ====================================================================================================

class PhoneThreatIntelligence {
  final String phoneNumber;
  final double riskScore;       // Score final consolidado por JOSH (0.0 - 100.0)
  final double ipqsScore;       // Fraud score entregado por la API / Backend
  final String verdict;         // AMENAZA_CONFIRMADA, ALTO_RIESGO, ADVERTENCIA, SIN_AMENAZAS
  final String statusLabel;     // Texto formateado para la UI (ej: "🔴 ALTO RIESGO / AMENAZA")
  final String confidence;      // ALTA, MEDIA, BAJA, OFFLINE
  final bool isVoip;            // ¿Es un número VoIP / Virtual?
  final bool recentAbuse;       // ¿Registra historial de reportes o fraudes?
  final String carrier;         // Operador telefónico (ej: Claro, Movistar, Tigo)
  final List<String> reasons;   // Vector de evidencias y motivos de la alerta
  final DateTime timestamp;

  const PhoneThreatIntelligence({
    required this.phoneNumber,
    required this.riskScore,
    this.ipqsScore = 0.0,
    required this.verdict,
    required this.statusLabel,
    this.confidence = "MEDIA",
    this.isVoip = false,
    this.recentAbuse = false,
    this.carrier = "Desconocido",
    required this.reasons,
    required this.timestamp,
  });

  /// Mapea el modelo a un Map/JSON compatible con la DB local y peticiones de backend
  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
      'risk_score': riskScore,
      'ipqs_score': ipqsScore,
      'verdict': verdict,
      'status_label': statusLabel,
      'confidence': confidence,
      'is_voip': isVoip ? 1 : 0,
      'recent_abuse': recentAbuse ? 1 : 0,
      'carrier': carrier,
      'reasons': reasons,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Deserializa desde SQLite, caché local o respuesta de la API
  factory PhoneThreatIntelligence.fromJson(Map<String, dynamic> json) {
    return PhoneThreatIntelligence(
      phoneNumber: json['phone_number'] ?? json['phone'] ?? '',
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
      ipqsScore: (json['ipqs_score'] as num?)?.toDouble() ?? 0.0,
      verdict: json['verdict'] ?? 'SIN_AMENAZAS',
      statusLabel: json['status_label'] ?? '🟢 SIN AMENAZAS DETECTADAS',
      confidence: json['confidence'] ?? 'MEDIA',
      isVoip: json['is_voip'] == 1 || json['is_voip'] == true,
      recentAbuse: json['recent_abuse'] == 1 || json['recent_abuse'] == true,
      carrier: json['carrier'] ?? 'Desconocido',
      reasons: json['reasons'] is List
          ? List<String>.from(json['reasons'])
          : (json['reasons'] as String?)?.split('|') ?? [],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}
