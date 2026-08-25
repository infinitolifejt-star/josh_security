// ====================================================================================================
// ARCHIVO: lib/main.dart
// PROJECT JOSH SECURITY
// PUNTO DE ENTRADA PRINCIPAL
// ====================================================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/security_provider.dart';
import 'services/background_shield.dart';
import 'services/security/overlay_service.dart';
import 'views/home_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/widgets/overlay_card.dart';

// ====================================================================================================
// CHANNELS
// ====================================================================================================

const MethodChannel _phoneChannel =
    MethodChannel('josh_security/phone_calls');

// ====================================================================================================
// ENTRY POINT DEL OVERLAY
// ====================================================================================================

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: OverlayCard(),
      ),
    ),
  );
}

// ====================================================================================================
// ENTRY POINT DE LLAMADAS EN SEGUNDO PLANO (BACKGROUND ENGINE)
// ====================================================================================================

@pragma('vm:entry-point')
void backgroundPhoneMain() {
  WidgetsFlutterBinding.ensureInitialized();
  const MethodChannel backgroundChannel =
      MethodChannel('josh_security/background_phone');

  backgroundChannel.setMethodCallHandler((call) async {
    if (call.method == 'incomingCall') {
      final Map<dynamic, dynamic> args =
          call.arguments as Map<dynamic, dynamic>;
      final String phoneNumber =
          args['phoneNumber']?.toString() ?? 'Número Oculto';

      debugPrint(
        '🛡️ [JOSH BG] Procesando llamada en segundo plano: $phoneNumber',
      );
    }
  });
}

// ====================================================================================================
// MAIN
// ====================================================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ----------------------------------------------------------------------------------------------
  // BACKGROUND SHIELD
  // ----------------------------------------------------------------------------------------------

  try {
    await BackgroundShield.initializeService();

    debugPrint(
      '🛡️ [JOSH SHIELD] Servicio de fondo inicializado correctamente.',
    );
  } catch (e, stackTrace) {
    debugPrint(
      '⚠️ [JOSH SHIELD] Error inicializando servicio: $e',
    );
    debugPrint(stackTrace.toString());
  }

  // ----------------------------------------------------------------------------------------------
  // OVERLAY
  // ----------------------------------------------------------------------------------------------

  try {
    final bool overlayGranted =
        await OverlayService.requestPermission();

    debugPrint(
      overlayGranted
          ? '🪟 [JOSH OVERLAY] Permiso concedido.'
          : '⚠️ [JOSH OVERLAY] Permiso no concedido.',
    );
  } catch (e, stackTrace) {
    debugPrint(
      '⚠️ [JOSH OVERLAY] Error solicitando permiso: $e',
    );
    debugPrint(stackTrace.toString());
  }

  // ----------------------------------------------------------------------------------------------
  // SECURITY PROVIDER
  // ----------------------------------------------------------------------------------------------

  final SecurityProvider securityProvider =
      SecurityProvider();

  bool onboardingVisto = false;

  try {
    await securityProvider.initialize();

    debugPrint(
      '📊 [JOSH ENGINE] SecurityProvider inicializado.',
    );
  } catch (e, stackTrace) {
    debugPrint(
      '⚠️ [JOSH ENGINE] Error inicializando SecurityProvider: $e',
    );
    debugPrint(stackTrace.toString());
  }

  // ----------------------------------------------------------------------------------------------
  // PREFERENCIAS
  // ----------------------------------------------------------------------------------------------

  try {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    onboardingVisto =
        prefs.getBool('onboarding_visto') ?? false;
  } catch (e, stackTrace) {
    debugPrint(
      '⚠️ [JOSH MAIN] Error leyendo onboarding: $e',
    );
    debugPrint(stackTrace.toString());
  }

  // ----------------------------------------------------------------------------------------------
  // APP
  // ----------------------------------------------------------------------------------------------

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SecurityProvider>.value(
          value: securityProvider,
        ),
      ],
      child: JoshSecurityApp(
        mostrarOnboarding: !onboardingVisto,
      ),
    ),
  );
}

// ====================================================================================================
// APP
// ====================================================================================================

class JoshSecurityApp extends StatefulWidget {
  final bool mostrarOnboarding;

  const JoshSecurityApp({
    super.key,
    required this.mostrarOnboarding,
  });

  @override
  State<JoshSecurityApp> createState() =>
      _JoshSecurityAppState();
}

// ====================================================================================================
// STATE
// ====================================================================================================

class _JoshSecurityAppState extends State<JoshSecurityApp> {
  final Set<String> _callsBeingProcessed = <String>{};

  @override
  void initState() {
    super.initState();
    _initializePhoneChannel();
  }

  void _initializePhoneChannel() {
    _phoneChannel.setMethodCallHandler(
      _handlePhoneMethod,
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;
        unawaited(_checkPendingCall());
      },
    );
  }

  Future<void> _handlePhoneMethod(MethodCall call) async {
    debugPrint('📞 [JOSH PHONE] Evento recibido: ${call.method}');

    switch (call.method) {
      case 'onCallIntercepted':
      case 'incomingCall':
        await _handleIncomingCallEvent(call);
        break;

      case 'onCallEnded':
      case 'callEnded':
        debugPrint('📞 [JOSH PHONE] Llamada finalizada.');
        break;

      default:
        debugPrint('⚠️ [JOSH PHONE] Método desconocido: ${call.method}');
    }
  }

  Future<void> _handleIncomingCallEvent(MethodCall call) async {
    final dynamic arguments = call.arguments;

    if (arguments is! Map) {
      debugPrint('⚠️ [JOSH PHONE] Evento de llamada sin argumentos válidos.');
      return;
    }

    final String phoneNumber = _extractPhoneNumber(arguments);
    debugPrint('📞 [JOSH PHONE] Número entrante: $phoneNumber');

    final bool processed = await _processIncomingCall(phoneNumber);

    if (processed) {
      try {
        await _phoneChannel.invokeMethod('clearPendingCall');
        debugPrint('📞 [JOSH PHONE] Pending call limpiado.');
      } catch (e, stackTrace) {
        debugPrint('⚠️ [JOSH PHONE] Error al limpiar pending call: $e');
        debugPrint(stackTrace.toString());
      }
    }
  }

  Future<void> _checkPendingCall() async {
    try {
      final dynamic result = await _phoneChannel.invokeMethod('getPendingCall');

      if (result == null || result is! Map) return;

      final String phoneNumber = _extractPhoneNumber(result);
      final bool processed = await _processIncomingCall(phoneNumber);

      if (processed) {
        await _phoneChannel.invokeMethod('clearPendingCall');
      }
    } on PlatformException catch (e, stackTrace) {
      debugPrint('⚠️ [JOSH PHONE] Error Android en llamada pendiente: ${e.message}');
      debugPrint(stackTrace.toString());
    } catch (e, stackTrace) {
      debugPrint('⚠️ [JOSH PHONE] Error recuperando llamada pendiente: $e');
      debugPrint(stackTrace.toString());
    }
  }

  Future<bool> _processIncomingCall(String phoneNumber) async {
    final String normalizedNumber = _normalizePhoneNumber(phoneNumber);

    if (normalizedNumber.isEmpty) return false;

    if (_callsBeingProcessed.contains(normalizedNumber)) {
      debugPrint('ℹ️ [JOSH PHONE] Evento duplicado ignorado: $normalizedNumber');
      return true;
    }

    _callsBeingProcessed.add(normalizedNumber);

    try {
      if (!mounted) {
        await _showFallbackOverlay(normalizedNumber);
        return false;
      }

      final SecurityProvider provider = Provider.of<SecurityProvider>(
        context,
        listen: false,
      );

      await provider.executeAuditoria(normalizedNumber, 0);

      if (!mounted) {
        await _showFallbackOverlay(normalizedNumber);
        return false;
      }

      final double riskScore = _safeRiskScore(provider.vulnerabilityScore);
      final String verdict = _safeText(provider.verdictText, fallback: 'LLAMADA ANALIZADA');
      final String reasoning = _safeText(provider.agentReasoningText, fallback: 'Sin razonamiento adicional.');

      await OverlayService.showWarningOverlay(
        phoneNumber: normalizedNumber,
        riskLevel: verdict,
        message: _buildOverlayMessage(riskScore, verdict),
        agentReasoning: reasoning,
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [JOSH PHONE] Error procesando llamada: $e');
      debugPrint(stackTrace.toString());
      await _showFallbackOverlay(normalizedNumber);
      return false;
    } finally {
      _callsBeingProcessed.remove(normalizedNumber);
    }
  }

  Future<void> _showFallbackOverlay(String phoneNumber) async {
    try {
      await OverlayService.showWarningOverlay(
        phoneNumber: phoneNumber,
        riskLevel: 'LLAMADA ENTRANTE',
        message: 'Llamada recibida. Centinela activo.',
        agentReasoning: 'No fue posible completar el análisis automático.',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [JOSH OVERLAY] Error en fallback: $e');
      debugPrint(stackTrace.toString());
    }
  }

  String _extractPhoneNumber(Map<dynamic, dynamic> data) {
    final dynamic raw = data['phoneNumber'] ?? data['phone_number'] ?? data['number'] ?? data['phone'];
    if (raw == null) return 'Número Oculto';
    final String value = raw.toString().trim();
    return value.isEmpty ? 'Número Oculto' : value;
  }

  String _normalizePhoneNumber(String value) {
    final String normalized = value.trim();
    return normalized.isEmpty ? 'Número Oculto' : normalized;
  }

  double _safeRiskScore(dynamic value) {
    if (value is num) {
      final double score = value.toDouble();
      return score.isFinite ? score.clamp(0.0, 100.0) : 0.0;
    }
    if (value is String) {
      final double? parsed = double.tryParse(value);
      if (parsed != null && parsed.isFinite) return parsed.clamp(0.0, 100.0);
    }
    return 0.0;
  }

  String _safeText(dynamic value, {required String fallback}) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _buildOverlayMessage(double score, String verdict) {
    if (score >= 70) return '⚠️ LLAMADA DE ALTO RIESGO\n$verdict';
    if (score >= 30) return '⚠️ LLAMADA SOSPECHOSA\n$verdict';
    return '🛡️ LLAMADA ANALIZADA\n$verdict';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JOSH Security',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1E293B),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        useMaterial3: true,
      ),
      home: widget.mostrarOnboarding
          ? const OnboardingScreen()
          : const HomeScreen(),
    );
  }

  @override
  void dispose() {
    _callsBeingProcessed.clear();
    _phoneChannel.setMethodCallHandler(null);
    super.dispose();
  }
}
