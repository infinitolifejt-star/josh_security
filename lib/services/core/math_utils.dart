// lib/services/core/math_utils.dart

import 'dart:math';

class MathUtils {
  static double log2(double x) => log(x) / log(2);

  static double shannonEntropy(String input) {
    final Map<String, int> freq = {};
    for (var char in input.split('')) {
      freq[char] = (freq[char] ?? 0) + 1;
    }

    double entropy = 0.0;
    int len = input.length;

    freq.forEach((key, value) {
      double p = value / len;
      entropy -= p * log2(p);
    });

    return entropy;
  }

  static double normalize(double value, double min, double max) {
    if (max - min == 0) return 0;
    return (value - min) / (max - min);
  }

  static double sigmoid(double x) {
    return 1 / (1 + exp(-x));
  }
}