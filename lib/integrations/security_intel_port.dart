import 'dart:async';

/// Contratos para inteligencia de amenazas externa (VirusTotal, Have I Been Pwned, etc.).
/// Implementaciones deben ser asíncronas, con timeouts y sin bloquear el hilo de UI.
abstract interface class SecurityIntelPort {
  Future<bool> submitArtifactForAnalysis(String artifactDescriptor);
}

/// Implementación nula hasta conectar APIs retras y claves seguras.
final class NoOpSecurityIntel implements SecurityIntelPort {
  @override
  Future<bool> submitArtifactForAnalysis(String artifactDescriptor) async => false;
}
