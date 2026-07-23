// ====================================================================================================
// ARCHIVO: lib/views/widgets/overlay_card.dart
// COMPONENTE: Pop-Up Flotante Interactivo (JOSH Security)
// ====================================================================================================

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayCard extends StatefulWidget {
  const OverlayCard({super.key});

  @override
  State<OverlayCard> createState() => _OverlayCardState();
}

class _OverlayCardState extends State<OverlayCard> {
  String _phoneNumber = 'Analizando...';
  String _riskLevel = 'CORTAFUEGOS';
  String _message = 'JOSH Security evaluando paquete entrante.';

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        setState(() {
          _phoneNumber = data['phone_number'] ?? _phoneNumber;
          _riskLevel = data['risk_level'] ?? _riskLevel;
          _message = data['message'] ?? _message;
        });
      }
    });
  }

  Color _getRiskColor() {
    if (_riskLevel == 'CRÍTICO') return Colors.redAccent;
    if (_riskLevel == 'ADVERTENCIA') return Colors.amberAccent;
    return Colors.cyanAccent;
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _getRiskColor();

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: riskColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: riskColor.withAlpha(80),
                blurRadius: 12,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: riskColor, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'JOSH CENTINELA',
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () async => await FlutterOverlayWindow.closeOverlay(),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Text(
                _phoneNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ESTADO: $_riskLevel',
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: riskColor,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async => await FlutterOverlayWindow.closeOverlay(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}