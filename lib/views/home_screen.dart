// ====================================================================================================
// ARCHIVO: lib/views/home_screen.dart
// COMPONENTE: Adaptación de Flujo Híbrido Proactivo Centinela v4.5.8
// OPERACIÓN: HUD, Auto-Scroll, Bitácora, Overlay y activación de Call Screening
// ====================================================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../services/security/overlay_service.dart';
import 'widgets/hud_display.dart';
import 'widgets/proactive_shields_monitor.dart';
import 'widgets/forensic_history_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @pragma('vm:entry-point')
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  static const MethodChannel _phoneChannel =
      MethodChannel('josh_security/phone_calls');

  final TextEditingController _targetController = TextEditingController();
  final ScrollController _logsScrollController = ScrollController();

  late TabController _tabController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  int _currentTab = 0;
  int _lastLogCount = 0;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _tabController.addListener(() {
      if (!mounted) return;

      if (_tabController.index != _currentTab) {
        setState(() {
          _currentTab = _tabController.index;
          _targetController.clear();
        });

        Provider.of<SecurityProvider>(
          context,
          listen: false,
        ).updateTabState(_currentTab);
      }
    });

    // 📞 ESCUCHA DE EVENTOS DESDE EL ISOLATE DE SEGUNDO PLANO
    FlutterBackgroundService().on('incoming_call').listen((event) {
      if (event != null && mounted) {
        final String number = event['number'] ?? '';
        final String riskLevel = event['riskLevel'] ?? 'DESCONOCIDO';
        final String message = event['message'] ?? '';

        final provider = Provider.of<SecurityProvider>(
          context,
          listen: false,
        );

        if (number.isNotEmpty) {
          provider.executeAuditoria(number, 0);
        }

        OverlayService.showWarningOverlay(
          phoneNumber: number,
          riskLevel: riskLevel,
          message: message,
        );
      }
    });

    FlutterBackgroundService().on('call_ended').listen((event) {
      if (mounted) {
        OverlayService.closeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _targetController.dispose();
    _logsScrollController.dispose();
    super.dispose();
  }

  Future<void> _requestCallScreeningRole() async {
    try {
      final bool granted =
          await _phoneChannel.invokeMethod<bool>(
                'requestCallScreeningRole',
              ) ??
              false;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Solicitud de Centinela telefónico enviada.'
                : 'No fue posible solicitar el rol de Call Screening.',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        '[JOSH PHONE] Error solicitando Call Screening: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error al solicitar el rol de Call Screening.',
          ),
        ),
      );
    }
  }

  Widget _buildCallScreeningButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _requestCallScreeningRole,
        icon: const Icon(Icons.shield_outlined),
        label: const Text(
          'ACTIVAR CENTINELA DE LLAMADAS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5BC0BE),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  void _scrollToBottomLogs() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logsScrollController.hasClients) {
        _logsScrollController.animateTo(
          _logsScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final securityProvider = Provider.of<SecurityProvider>(context);

    if (securityProvider.forensicLogs.length != _lastLogCount) {
      _lastLogCount = securityProvider.forensicLogs.length;
      _scrollToBottomLogs();
    }

    if (securityProvider.isLoading) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
        _rotationController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }

    final bool isPatrolling = securityProvider.isEnginePatrolling;

    final Color patrolStatusColor = isPatrolling
        ? const Color(0xFF2ECC71)
        : const Color(0xFF3498DB);

    final String patrolStatusText = isPatrolling
        ? 'MOTOR CENTINELA: PATRULLANDO'
        : 'MOTOR CENTINELA: EN ESPERA';

    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: patrolStatusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: patrolStatusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: patrolStatusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      patrolStatusText,
                      style: TextStyle(
                        color: patrolStatusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              HudDisplay(
                vulnerabilityScore: securityProvider.vulnerabilityScore,
                verdictText: securityProvider.verdictText,
                agentReasoning: securityProvider.agentReasoning,
                hudColor: securityProvider.hudColor,
                pulseController: _pulseController,
                rotationController: _rotationController,
              ),

              const SizedBox(height: 16),

              ProactiveShieldsMonitor(
                linksChecked: securityProvider.linksChecked,
                callsChecked: securityProvider.callsChecked,
                malwarePrevented: securityProvider.malwarePrevented,
              ),

              const SizedBox(height: 16),

              _buildCallScreeningButton(),

              const SizedBox(height: 16),

              _buildVectorSelector(),

              const SizedBox(height: 16),

              _buildInputSection(securityProvider),

              const SizedBox(height: 16),

              SizedBox(
                height: 180,
                child: _buildBottomLogsSection(
                  securityProvider,
                  patrolStatusColor,
                ),
              ),

              const SizedBox(height: 16),

              ForensicHistoryList(
                onClear: () => securityProvider.clearMasterBitacora(),
              ),

              const SizedBox(height: 16),
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
          border: Border.all(
            color: Colors.blueAccent.withValues(alpha: 0.4),
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.blueGrey[300],
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        tabs: const [
          Tab(text: 'LLAMADAS'),
          Tab(text: 'PHISHING'),
          Tab(text: 'MALWARE'),
        ],
      ),
    );
  }

  Widget _buildInputSection(
    SecurityProvider securityProvider,
  ) {
    IconData inputIcon = Icons.phone_android;
    String hintText = 'Ingrese terminal telefónico (Ej. 300...)';

    if (_currentTab == 1) {
      inputIcon = Icons.link;
      hintText = 'Ingrese dirección URL fraudulenta';
    } else if (_currentTab == 2) {
      inputIcon = Icons.bug_report_outlined;
      hintText =
          securityProvider.selectedFileName ??
          'Seleccione binario corporativo';
    }

    return Column(
      children: [
        TextField(
          controller: _targetController,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.blueGrey[400],
              fontSize: 13,
            ),
            prefixIcon: Icon(
              inputIcon,
              color: const Color(0xFF5BC0BE),
            ),
            filled: true,
            fillColor: const Color(0xFF1C2541),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            suffixIcon: _currentTab == 2
                ? IconButton(
                    icon: const Icon(
                      Icons.folder_open,
                      color: Color(0xFF5BC0BE),
                    ),
                    onPressed: securityProvider.isLoading
                        ? null
                        : () async {
                            final bool success =
                                await securityProvider.pickLocalFile();

                            if (success &&
                                securityProvider.selectedFileName != null) {
                              _targetController.text =
                                  securityProvider.selectedFileName!;
                            }
                          },
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3A506B),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF5BC0BE),
                width: 1.5,
              ),
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
                : () {
                    FocusScope.of(context).unfocus();

                    securityProvider.executeAuditoria(
                      _targetController.text.trim(),
                      _currentTab,
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: securityProvider.hudColor,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.blueGrey[800],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: securityProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'AUDITAR EN CALIENTE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomLogsSection(
    SecurityProvider securityProvider,
    Color patrolStatusColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1C2541),
        ),
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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.cleaning_services_rounded,
                      color: Color(0xFF5BC0BE),
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Despejar Consola Visual',
                    onPressed: () {
                      securityProvider.clearForensicLogs();
                    },
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: securityProvider.isLoading
                          ? Colors.amber
                          : patrolStatusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(
              color: Color(0xFF1C2541),
              thickness: 1.5,
            ),
          ),

          Expanded(
            child: ListView.builder(
              controller: _logsScrollController,
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
}
