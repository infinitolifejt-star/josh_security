import 'dart:math';

class MathUtils {
  // Constante precalculada de logaritmo natural de 2 para optimizar el rendimiento de la CPU
  static const double _log2Constant = 0.6931471805599453;

  /// Calcula el logaritmo en base 2 con blindaje de seguridad contra valores de error
  static double log2(double x) {
    if (x <= 0.0 || x.isNaN || x.isInfinite) return 0.0;
    return log(x) / _log2Constant;
  }

  /// Calcula la entropía de Shannon optimizando la gestión de memoria sin desdoblar arrays
  static double shannonEntropy(String input) {
    if (input.isEmpty) return 0.0;

    final Map<String, int> freq = {};
    
    // Optimización de rendimiento: iteración directa por caracteres sin usar .split()
    for (int i = 0; i < input.length; i++) {
      final String char = input[i];
      freq[char] = (freq[char] ?? 0) + 1;
    }

    double entropy = 0.0;
    final int len = input.length;

    freq.forEach((_, int value) {
      final double p = value / len;
      entropy -= p * log2(p);
    });

    return (entropy.isNaN || entropy.isInfinite || entropy < 0.0) ? 0.0 : entropy;
  }

  /// Normaliza un valor dentro de un rango dinámico previniendo divisiones por cero
  static double normalize(double value, double min, double max) {
    final double range = max - min;
    if (range == 0.0) return 0.0;
    
    // Asegura el retorno dentro del espectro estricto [0.0 - 1.0]
    final double normalized = (value - min) / range;
    return normalized.clamp(0.0, 1.0);
  }

  /// Función de activación Sigmoide con blindaje numérico contra sobreflujos (overflow) y valores NaN
  static double sigmoid(double x) {
    if (x.isNaN) return 0.5;
    
    // Acotamiento de seguridad exponencial para proteger la pila del procesador móvil
    if (x >= 20.0) return 1.0;
    if (x <= -20.0) return 0.0;
    
    return 1.0 / (1.0 + exp(-x));
  }
}