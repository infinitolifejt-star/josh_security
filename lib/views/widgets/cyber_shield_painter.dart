import 'package:flutter/material.dart';

class CyberShieldPainter extends CustomPainter {
  final Color glowColor;

  CyberShieldPainter({required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Capa de Sombra Externa (Efecto de brillo)
    final Paint glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // 2. Fondo del cuerpo del escudo
    final Paint basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // 3. Borde exterior brillante
    final Paint borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [glowColor, glowColor.withValues(alpha: 0.5)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // 4. Trazado geométrico del escudo
    final Path shieldPath = Path();
    shieldPath.moveTo(w * 0.5, h * 0.1);                  
    shieldPath.lineTo(w * 0.85, h * 0.18);                
    shieldPath.lineTo(w * 0.85, h * 0.55);                
    shieldPath.quadraticBezierTo(w * 0.85, h * 0.82, w * 0.5, h * 0.95); 
    shieldPath.quadraticBezierTo(w * 0.15, h * 0.82, w * 0.15, h * 0.55); 
    shieldPath.lineTo(w * 0.15, h * 0.18);                
    shieldPath.close();

    // Dibujar las capas en pantalla
    canvas.drawPath(shieldPath, glowPaint); 
    canvas.drawPath(shieldPath, basePaint); 
    canvas.drawPath(shieldPath, borderPaint); 

    // 5. Detalles de líneas de circuito internas
    final Paint corePaint = Paint()
      ..color = glowColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Path corePath = Path();
    corePath.moveTo(w * 0.5, h * 0.25);
    corePath.lineTo(w * 0.5, h * 0.75);
    corePath.moveTo(w * 0.35, h * 0.45);
    corePath.lineTo(w * 0.65, h * 0.45);
    
    canvas.drawPath(corePath, corePaint);
  }

  @override
  bool shouldRepaint(covariant CyberShieldPainter oldDelegate) {
    return oldDelegate.glowColor != glowColor;
  }
}