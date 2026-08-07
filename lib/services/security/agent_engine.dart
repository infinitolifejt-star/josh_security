// ====================================================================================================
// ARCHIVO: lib/services/security/agent_engine.dart
// COMPONENTE: Motor Agéntico de Razonamiento y Toma de Decisiones Tácticas v1.0
// OPERACIÓN: Evaluación Contextual, Disparo Selectivo de Inteligencia y Juicio Definitivo
// ====================================================================================================

import 'agent_memory.dart';

class AgentVerdict {
  final double finalRiskScore;
  final String statusText;
  final String reasoning;
  final bool requiresExternalLookup;
  final String actionRecommendation;

  AgentVerdict({
    required this.finalRiskScore,
    required this.statusText,
    required this.reasoning,
    required this.requiresExternalLookup,
    required this.actionRecommendation,
  });
}

class AgentEngine {
  /// Delibera sobre la amenaza combinando el Análisis Heurístico con la Memoria del Agente
  static Future<AgentVerdict> evaluateThreat({
    required String target,
    required String vectorType, // 'PHONE', 'PHISHING', 'MALWARE'
    required double heuristicRiskScore,
  }) async {
    // 1. Consultar la memoria contextual de interacciones pasadas
    final context = await AgentMemory.getTargetContext(target);
    await AgentMemory.updateContextMemory(target, vectorType, heuristicRiskScore);

    int occurrences = 1;
    if (context != null) {
      occurrences = (context['occurrences'] as int) + 1;
    }

    double adjustedRisk = heuristicRiskScore;
    List<String> reasoningLog = [];
    bool needExternalQuery = false;

    // 2. REGLA AGÉNTICA 1: Factor Reincidencia / Acoso Frecuente
    if (occurrences > 3) {
      adjustedRisk += 15.0;
      reasoningLog.add("Reincidencia detectada: $occurrences interacciones registradas.");
    }

    // 3. REGLA AGÉNTICA 2: Evaluación por Umbrales
    // CASO A: AMENAZA BAJA (0% - 20%) -> Paso directo sin gasto de recursos
    if (heuristicRiskScore <= 20.0 && occurrences <= 2) {
      reasoningLog.add("Heurística confirma origen seguro. Sin comportamiento anómalo.");
      
      final verdict = AgentVerdict(
        finalRiskScore: adjustedRisk.clamp(0.0, 100.0),
        statusText: "SEGURO (AUTORIZADO POR AGENTE)",
        reasoning: reasoningLog.join(" | "),
        requiresExternalLookup: false,
        actionRecommendation: "PERMITIR",
      );

      await _persistDecision(target, heuristicRiskScore, verdict);
      return verdict;
    }

    // CASO B: AMENAZA ALTA / CRÍTICA (80% - 100%) -> Bloqueo Preventivo Directo
    if (heuristicRiskScore >= 80.0) {
      reasoningLog.add("Estructura de alto riesgo crítico detectada por vectores primarios.");
      
      final verdict = AgentVerdict(
        finalRiskScore: adjustedRisk.clamp(0.0, 100.0),
        statusText: "AMENAZA ALTA DETECTADA",
        reasoning: reasoningLog.join(" | "),
        requiresExternalLookup: false,
        actionRecommendation: "BLOQUEAR / ADVERTIR",
      );

      await _persistDecision(target, heuristicRiskScore, verdict);
      return verdict;
    }

    // CASO C: ZONA GRIS / DUDOSA (21% - 79%) -> Se activa el análisis agéntico profundo
    reasoningLog.add("Zona gris identificada. Agente requiere verificación de reputación.");
    needExternalQuery = true;

    // Ajuste contextual si llama en horarios no habituales o repetitivamente
    if (occurrences > 1 && heuristicRiskScore > 40.0) {
      adjustedRisk += 10.0;
      reasoningLog.add("Aumento del nivel de sospecha por insistencia en patrón dudoso.");
    }

    String action = adjustedRisk > 50.0 ? "ADVERTIR" : "MONITOREAR";

    final verdict = AgentVerdict(
      finalRiskScore: adjustedRisk.clamp(0.0, 100.0),
      statusText: adjustedRisk > 50.0 ? "ALERTA PREVENTIVA" : "SOSPECHOSO (ZONA GRIS)",
      reasoning: reasoningLog.join(" | "),
      requiresExternalLookup: needExternalQuery,
      actionRecommendation: action,
    );

    await _persistDecision(target, heuristicRiskScore, verdict);
    return verdict;
  }

  static Future<void> _persistDecision(String target, double heuristicScore, AgentVerdict verdict) async {
    await AgentMemory.saveAgentDecision(
      target: target,
      heuristicScore: heuristicScore,
      agentScore: verdict.finalRiskScore,
      verdict: verdict.statusText,
      reasoning: verdict.reasoning,
    );
  }
}