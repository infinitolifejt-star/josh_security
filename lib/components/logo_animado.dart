import 'package:flutter/material.dart';
import 'dart:math' as math;

class LogoAnimado extends StatelessWidget {
  final AnimationController rotationController;

  const LogoAnimado({Key? key, required this.rotationController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF111827)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: rotationController,
            builder: (context, child) {
              final double angle = rotationController.value * 2 * math.pi;
              final bool isBackside = angle % (2 * math.pi) > math.pi / 2 && angle % (2 * math.pi) < 3 * math.pi / 2;

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: Container(
                  height: 180,
                  width: 180,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        blurRadius: 25,
                        spreadRadius: 5,
                      )
                    ]
                  ),
                  child: Transform(
                    transform: isBackside ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/logo_escudo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.security, size: 100, color: Color(0xFF818CF8));
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "JOSH SECURITY SYSTEM",
            style: TextStyle(
              color: Colors.white, 
              fontSize: 22, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 1.8,
              shadows: [
                Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4),
              ]
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: const Text(
              "🛡️ Core Security Suite v2.5",
              style: TextStyle(color: Color(0xFF818CF8), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}