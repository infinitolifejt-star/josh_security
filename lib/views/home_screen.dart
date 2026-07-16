// ====================================================================================================
// ARCHIVO: lib/views/home_screen.dart
// COMPONENTE: Adaptación de Flujo Híbrido Proactivo Centinela v4.5.0 (Modularizado + Provider)
// ====================================================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import 'widgets/hud_display.dart';
import 'widgets/proactive_shields_monitor.dart';
import 'widgets/forensic_history_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @pragma('vm:entry-point')
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _targetController = TextEditingController();
  late TabController _tabController;
  late AnimationController _rotationController; 
  late AnimationController _pulseController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Escuchamos el cambio de pestañas para actualizar el estado del proveedor
    _tabController.addListener(() {
      if (!mounted) return;
      if (_tabController.index != _currentTab) {
        setState(() {
          _currentTab = _tabController.index;
          _targetController.clear();
        });
        // Sincronizamos la pestaña con el proveedor
        Provider.of<SecurityProvider>(context, listen: false).updateTabState(_currentTab);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rotationController.dispose(); 
    _pulseController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  /// Helper táctico para simular llamadas sospechosas en ráfaga y probar la heurística local
  void _simulateTacticalCall(SecurityProvider provider) {
    final List<String> suspiciousNumbers = [
      "+57 300 456 7890",
      "+57 315 987 6543",
      "+57 311 222 3333"
    ];
    // Tomamos un número pseudo-aleatorio basado en los segundos actuales
    final int index = DateTime.now().second % suspiciousNumbers.length;
    final String targetNumber = suspiciousNumbers[index];

    // Colocamos el número en el controlador de texto de llamadas
    setState(() {
      _tabController.animateTo(0); // Forzar tab de llamadas
      _targetController.text = targetNumber;
    });

    // Ejecutamos la auditoría de inmediato
    provider.executeAuditoria(targetNumber, 0);
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos el SecurityProvider reactivamente
    final securityProvider = Provider.of<SecurityProvider>(context);

    // Sincronizamos la animación de rotación del HUD con el estado de carga
    if (securityProvider.isLoading) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
        _rotationController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. El HUD superior modularizado
              HudDisplay(
                vulnerabilityScore: securityProvider.vulnerabilityScore,
                verdictText: securityProvider.verdictText,
                hudColor: securityProvider.hudColor,
                pulseController: _pulseController,
                rotationController: _rotationController,
              ),
              const SizedBox(height: 16),
              // 2. El monitor de escudos proactivos en tiempo real
              ProactiveShieldsMonitor(
                linksChecked: securityProvider.linksChecked,
                callsChecked: securityProvider.callsChecked,
                malwarePrevented: securityProvider.malwarePrevented,
              ),
              const SizedBox(height: 16),
              _buildVectorSelector(),
              const SizedBox(height: 16),
              _buildInputSection(securityProvider),
              const SizedBox(height: 16),
              SizedBox(height: 180, child: _buildBottomLogsSection(securityProvider)),
              const SizedBox(height: 16),
              // Botón táctico de inyección de telemetría / llamadas simuladas
              _buildSimulationShortcutCard(securityProvider),
              const SizedBox(height: 16),
              // 3. La bitácora integral de resguardo histórica
              ForensicHistoryList(
                masterBitacora: securityProvider.masterBitacora,
                onClear: () => securityProvider.clearMasterBitacora(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVectorSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF3A506B),
          border: Border.all(color: Colors.blueAccent.withAlpha((0.4 * 255).round())),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.blueGrey[300],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: const [
          Tab(text: "LLAMADAS"),
          Tab(text: "PHISHING"),
          Tab(text: "MALWARE"),
        ],
      ),
    );
  }

  Widget _buildInputSection(SecurityProvider securityProvider) {
    IconData inputIcon = Icons.phone_android;
    String hintText = "Ingrese terminal telefónico (Ej. 300...)";

    if (_currentTab == 1) {
      inputIcon = Icons.link;
      hintText = "Ingrese dirección URL fraudulenta";
    } else if (_currentTab == 2) {
      inputIcon = Icons.bug_report_outlined;
      hintText = securityProvider.selectedFileName ?? "Seleccione binario corporativo";
    }

    return Column(
      children: [
        TextField(
          controller: _targetController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.blueGrey[400], fontSize: 13),
            prefixIcon: Icon(inputIcon, color: const Color(0xFF5BC0BE)),
            filled: true,
            fillColor: const Color(0xFF1C2541),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            suffixIcon: _currentTab == 2
                ? IconButton(
                    icon: const Icon(Icons.folder_open, color: Color(0xFF5BC0BE)),
                    onPressed: securityProvider.isLoading
                        ? null
                        : () async {
                            bool success = await securityProvider.pickLocalFile();
                            if (success && securityProvider.selectedFileName != null) {
                              _targetController.text = securityProvider.selectedFileName!;
                            }
                          },
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3A506B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF5BC0BE), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: securityProvider.isLoading
                ? null
                : () => securityProvider.executeAuditoria(_targetController.text.trim(), _currentTab),
            style: ElevatedButton.styleFrom(
              backgroundColor: securityProvider.hudColor,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.blueGrey[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: securityProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                  )
                : const Text(
                    "AUDITAR EN CALIENTE",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomLogsSection(SecurityProvider securityProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2541)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  securityProvider.statusCategory,
                  style: const TextStyle(
                    color: Color(0xFF5BC0BE),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: securityProvider.isLoading ? Colors.amber : securityProvider.hudColor,
                ),
              )
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(color: Color(0xFF1C2541), thickness: 1.5),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: securityProvider.forensicLogs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    securityProvider.forensicLogs[index],
                    style: TextStyle(
                      color: Colors.blueGrey[100],
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationShortcutCard(SecurityProvider securityProvider) {
    return Card(
      color: const Color(0xFF1C2541),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.redAccent.withAlpha((0.3 * 255).round()), width: 1),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: Colors.amberAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "ENTRENAMIENTO HEURÍSTICO",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Simula llamadas sospechosas rápidas.",
                    style: TextStyle(color: Colors.blueGrey, fontSize: 10),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: securityProvider.isLoading ? null : () => _simulateTacticalCall(securityProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C3E50),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "SIMULAR",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}