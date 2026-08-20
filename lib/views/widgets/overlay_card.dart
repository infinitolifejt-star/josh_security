// ====================================================================================================
// ARCHIVO: lib/views/widgets/overlay_card.dart
// COMPONENTE: Pop-Up Flotante Interactivo con Razonamiento Agéntico (JOSH Security v6.0)
// ====================================================================================================

import 'dart:async';
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
  String? _agentReasoning;
  int _lastTimestamp = 0;
  StreamSubscription? _overlaySubscription;

  @override
  void initState() {
    super.initState();
    _initOverlayListener();
  }

  void _initOverlayListener() {
    _overlaySubscription = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map && mounted) {
        final int currentTimestamp = data['timestamp'] is int ? data['timestamp'] : 0;

        if (currentTimestamp >= _lastTimestamp || currentTimestamp == 0) {
          _lastTimestamp = currentTimestamp;
          _updateUI(data);
        }
      }
    });
  }

  void _updateUI(Map data) {
    setState(() {
      _phoneNumber = data['phone_number']?.toString() ?? _phoneNumber;
      _riskLevel = data['risk_level']?.toString() ?? _riskLevel;
      _message = data['message']?.toString() ?? _message;
      _agentReasoning = data['agent_reasoning']?.toString();
    });
  }

  @override
  void dispose() {
    _overlaySubscription?.cancel();
    super.dispose();
  }

  Color _getRiskColor() {
    switch (_riskLevel) {
      case 'CRÍTICO':
      case 'PELIGRO':
      case 'ALTO':
        return Colors.redAccent;
      case 'ADVERTENCIA':
      case 'MEDIO':
      case 'SOSPECHOSO':
        return Colors.amberAccent;
      case 'SEGURO':
      case 'BAJO':
      case 'LIMPIO':
        return Colors.greenAccent;
      default:
        return Colors.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _getRiskColor();

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: riskColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: riskColor.withAlpha(80),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: riskColor, size: 26),
                  const SizedBox(width: 8),
                  Text(
                    'JOSH CENTINELA',
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                    onPressed: () async => await FlutterOverlayWindow.closeOverlay(),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 16),

              // Cuerpo con Scroll Responsivo
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _phoneNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
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
                      const SizedBox(height: 10),
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      if (_agentReasoning != null && _agentReasoning!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: riskColor.withAlpha(100),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.psychology, color: riskColor, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _agentReasoning!,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(230),
                                    fontSize: 11,
                                    fontFamily: 'Monospace',
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Botón de Cierre Nativo Directo
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: riskColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    'ENTENDIDO',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
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
