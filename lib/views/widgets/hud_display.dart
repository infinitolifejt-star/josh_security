// ====================================================================================================
// ARCHIVO: lib/views/widgets/hud_display.dart
// COMPONENTE: HUD Superior Modularizado para JOSH Security
// ====================================================================================================

import 'package:flutter/material.dart';
import 'cyber_shield_painter.dart';

class HudDisplay extends StatelessWidget {
  final double vulnerabilityScore;
  final String verdictText;
  final Color hudColor;
  final AnimationController pulseController;
  final AnimationController rotationController;

  const HudDisplay({
    super.key,
    required this.vulnerabilityScore,
    required this.verdictText,
    required this.hudColor,
    required this.pulseController,
    required this.rotationController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        double glowIntensity = 0.05 + (pulseController.value * 0.05);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: hudColor.withAlpha((0.4 * 255).round()), width: 2),
            boxShadow: [
              BoxShadow(
                color: hudColor.withAlpha((glowIntensity * 255).round()),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, color: hudColor, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "JOSH SECURITY • CENTINELA v4.4.6",
                      style: TextStyle(
                        color: Colors.blueGrey[200],
                        letterSpacing: 2.5,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: hudColor.withAlpha((0.4 * 255).round()), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: hudColor.withAlpha((0.1 * 255).round()),
                      blurRadius: 12,
                    )
                  ],
                ),
                child: RotationTransition(
                  turns: rotationController,
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: CyberShieldPainter(glowColor: hudColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                verdictText,
                style: TextStyle(
                  color: hudColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${vulnerabilityScore.toStringAsFixed(1)}%",
                style: TextStyle(
                  color: hudColor,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}