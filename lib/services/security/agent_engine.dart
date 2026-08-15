// ====================================================================================================
// ARCHIVO: lib/services/security/agent_engine.dart
// COMPONENTE: Motor Agéntico de Razonamiento y Toma de Decisiones Tácticas v1.0
// OPERACIÓN: Evaluación Contextual, Disparo Selectivo de Inteligencia y Juicio Definitivo
// ====================================================================================================

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
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
  /// Emite trazabilidad unificada para la consola Logcat de Android y DevTools
  static void _trace(String message) {
    debugPrint('[JOSH_TRACE] [AgentEngine] $message');
    developer.log(message, name: 'josh.security.agent');
  }

  /// Delibera sobre la amenaza combinando el Análisis Heurístico con la Memoria del Agente
  static Future<AgentVerdict> evaluateThreat({
    required String target,
    required String vectorType, // 'PHONE', 'PHISHING', 'MALWARE'
    required double heuristicRiskScore,
  }) async {
    _trace('Evaluación agéntica iniciada -> Objetivo: $target | Vector: $vectorType | Heurística: $heuristicRiskScore');

    // 1. Consultar la memoria contextual de interacciones pasadas
    final Map<String, dynamic>? context = await AgentMemory.getTargetContext(target);
    await AgentMemory.updateContextMemory(target, vectorType, heuristicRiskScore);

    int occurrences = 1;
    if (context != null) {
      occurrences = (context['occurrences'] as int? ?? 0) + 1;
    }

    double adjustedRisk = heuristicRiskScore;
    final List<String> reasoningLog = <String>[];
    bool needExternalQuery = false;

    // 2. REGLA AGÉNTICA 1: Factor Reincidencia / Acoso Frecuente
    if (occurrences > 3) {
      adjustedRisk += 15.0;
      reasoningLog.add('Reincidencia detectada: $occurrences interacciones registradas.');
      _trace('Factor reincidencia aplicado ($occurrences eventos acumulados).');
    }

    // 3. REGLA AGÉNTICA 2: Evaluación por Umbrales
    // CASO A: AMENAZA BAJA (0% - 20%) -> Paso directo sin consumo innecesario de recursos
    if (heuristicRiskScore <= 20.0 && occurrences <= 2) {
      reasoningLog.add('Heurística confirma origen seguro. Sin comportamiento anómalo.');

      final AgentVerdict verdict = AgentVerdict(
        finalRiskScore: adjustedRisk.clamp(0.0, 100.0),
        statusText: 'SEGURO (AUTORIZADO POR AGENTE)',
        reasoning: reasoningLog.join(' | '),
        requiresExternalLookup: false,
        actionRecommendation: 'PERMITIR',
      );

      _trace('Veredicto Agéntico: SEGURO (${verdict.finalRiskScore} pts)');
      await _persistDecision(target, heuristicRiskScore, verdict);
      return verdict;
    }

    // CASO B: AMENAZA ALTA / CRÍTICA (80% - 100%) -> Bloqueo Preventivo Directo
    if (heuristicRiskScore >= 80.0) {
      reasoningLog.add('Estructura de alto riesgo crítico detectada por vectores primarios.');

      final AgentVerdict verdict = AgentVerdict(
        finalRiskScore: adjustedRisk.clamp(0.0, 100.0),
        statusText: 'AMENAZA ALTA DETECTADA',
        reasoning: reasoningLog.join(' | '),
        requiresExternalLookup: false,
        actionRecommendation: 'BLOQUEAR / ADVERTIR',
      );

      _trace('Veredicto Agéntico: CRÍTICO (${verdict.finalRiskScore} pts)');
      await _persistDecision(target, heuristicRiskScore, verdict);
      return verdict;
    }

    // CASO C: ZONA GRIS / DUDOSA (21% - 79%) -> Se activa el análisis agéntico profundo
    reasoningLog.add('Zona gris identificada. Agente requiere verificación de reputación.');
    needExternalQuery = true;

    if (occurrences > 1 && heuristicRiskScore > 40.0) {
      adjustedRisk += 10.0;
      reasoningLog.add('Aumento del nivel de sospecha por insistencia en patrón dudoso.');
    }

    final String action = adjustedRisk > 50.0 ? 'ADVERTIR' : 'MONITOREAR';

    final AgentVerdict verdict = AgentVerdict(
      finalRiskScore: adjustedRisk.clamp(0.0, 100.0),
      statusText: adjustedRisk > 50.0 ? 'ALERTA PREVENTIVA' : 'SOSPECHOSO (ZONA GRIS)',
      reasoning: reasoningLog.join(' | '),
      requiresExternalLookup: needExternalQuery,
      actionRecommendation: action,
    );

    _trace('Veredicto Agéntico: ZONA GRIS (${verdict.finalRiskScore} pts)');
    await _persistDecision(target, heuristicRiskScore, verdict);
    return verdict;
  }

  static Future<void> _persistDecision(
    String target,
    double heuristicScore,
    AgentVerdict verdict,
  ) async {
    try {
      await AgentMemory.saveAgentDecision(
        target: target,
        heuristicScore: heuristicScore,
        agentScore: verdict.finalRiskScore,
        verdict: verdict.statusText,
        reasoning: verdict.reasoning,
      );
    } catch (e) {
      _trace('Error en persistencia de memoria agéntica: $e');
    }
  }
}
