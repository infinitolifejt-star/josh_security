// ====================================================================================================
// ARCHIVO: lib/main.dart
// PROJECT JOSH SECURITY
// PUNTO DE ENTRADA PRINCIPAL
// ====================================================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/security_provider.dart';
import 'services/background_shield.dart';
import 'services/security/overlay_service.dart';
import 'views/home_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/widgets/overlay_card.dart';

// ====================================================================================================
// CHANNEL PHONE
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
// MAIN
// ====================================================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ----------------------------------------------------------------------------------------------
  // PERMISOS
  // ----------------------------------------------------------------------------------------------

  await _requestRuntimePermissions();

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
// PERMISOS
// ====================================================================================================

Future<void> _requestRuntimePermissions() async {
  try {
    // ----------------------------------------------------------------------------------------------
    // PHONE
    // ----------------------------------------------------------------------------------------------

    final PermissionStatus phoneStatus =
        await Permission.phone.request();

    debugPrint(
      '📱 [JOSH PERMISSIONS] PHONE: $phoneStatus',
    );

    // ----------------------------------------------------------------------------------------------
    // NOTIFICATION
    // ----------------------------------------------------------------------------------------------

    final PermissionStatus notificationStatus =
        await Permission.notification.request();

    debugPrint(
      '🔔 [JOSH PERMISSIONS] NOTIFICATION: $notificationStatus',
    );

    // ----------------------------------------------------------------------------------------------
    // CALL LOG
    // ----------------------------------------------------------------------------------------------

    try {
      final bool callLogGranted =
          await _phoneChannel.invokeMethod<bool>(
                'isCallLogPermissionGranted',
              ) ??
              false;

      debugPrint(
        '📞 [JOSH PERMISSIONS] CALL LOG actual: $callLogGranted',
      );

      if (!callLogGranted) {
        await _phoneChannel.invokeMethod(
          'requestCallLogPermission',
        );

        debugPrint(
          '📞 [JOSH PERMISSIONS] Solicitud de READ_CALL_LOG enviada.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ [JOSH PERMISSIONS] Error solicitando CALL LOG: $e',
      );

      debugPrint(stackTrace.toString());
    }

    // ----------------------------------------------------------------------------------------------
    // VALIDACIÓN
    // ----------------------------------------------------------------------------------------------

    if (!phoneStatus.isGranted) {
      debugPrint(
        '⚠️ [JOSH PERMISSIONS] PHONE no concedido.',
      );
    }

    if (!notificationStatus.isGranted) {
      debugPrint(
        '⚠️ [JOSH PERMISSIONS] NOTIFICATION no concedido.',
      );
    }
  } catch (e, stackTrace) {
    debugPrint(
      '⚠️ [JOSH PERMISSIONS] Error general solicitando permisos: $e',
    );

    debugPrint(stackTrace.toString());
  }
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
  // ================================================================================================
  // INIT
  // ================================================================================================

  @override
  void initState() {
    super.initState();

    _initializePhoneChannel();
  }

  // ================================================================================================
  // PHONE CHANNEL
  // ================================================================================================

  void _initializePhoneChannel() {
    _phoneChannel.setMethodCallHandler(
      _handlePhoneMethod,
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        unawaited(
          _checkPendingCall(),
        );
      },
    );
  }

  // ================================================================================================
  // EVENTOS DESDE ANDROID
  // ================================================================================================

  Future<void> _handlePhoneMethod(
    MethodCall call,
  ) async {
    debugPrint(
      '📞 [JOSH PHONE] Evento recibido: ${call.method}',
    );

    switch (call.method) {
      case 'onCallIntercepted':
        await _handleIncomingCallEvent(call);
        break;

      case 'onCallEnded':
        debugPrint(
          '📞 [JOSH PHONE] Llamada finalizada.',
        );
        break;

      default:
        debugPrint(
          '⚠️ [JOSH PHONE] Método desconocido: ${call.method}',
        );
    }
  }

  // ================================================================================================
  // EVENTO LLAMADA ENTRANTE
  // ================================================================================================

  Future<void> _handleIncomingCallEvent(
    MethodCall call,
  ) async {
    if (call.arguments is! Map) {
      debugPrint(
        '⚠️ [JOSH PHONE] onCallIntercepted sin argumentos válidos.',
      );
      return;
    }

    final Map<dynamic, dynamic> data =
        call.arguments as Map<dynamic, dynamic>;

    final String phoneNumber =
        data['phoneNumber']?.toString().trim() ??
            '';

    final String normalizedNumber =
        phoneNumber.isEmpty
            ? 'Número Oculto'
            : phoneNumber;

    debugPrint(
      '📞 [JOSH PHONE] Número entrante: $normalizedNumber',
    );

    await _processIncomingCall(
      normalizedNumber,
    );
  }

  // ================================================================================================
  // LLAMADA PENDIENTE
  // ================================================================================================

  Future<void> _checkPendingCall() async {
    try {
      final dynamic result =
          await _phoneChannel.invokeMethod(
        'getPendingCall',
      );

      if (result == null) {
        debugPrint(
          '📞 [JOSH PHONE] No hay llamadas pendientes.',
        );
        return;
      }

      if (result is! Map) {
        debugPrint(
          '⚠️ [JOSH PHONE] Llamada pendiente con formato inválido.',
        );
        return;
      }

      final String phoneNumber =
          result['phoneNumber']?.toString().trim() ??
              '';

      final String normalizedNumber =
          phoneNumber.isEmpty
              ? 'Número Oculto'
              : phoneNumber;

      debugPrint(
        '📞 [JOSH PHONE] Llamada pendiente recuperada: '
        '$normalizedNumber',
      );

      await _processIncomingCall(
        normalizedNumber,
      );

      await _phoneChannel.invokeMethod(
        'clearPendingCall',
      );

      debugPrint(
        '📞 [JOSH PHONE] Llamada pendiente limpiada.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ [JOSH PHONE] Error recuperando llamada pendiente: $e',
      );

      debugPrint(stackTrace.toString());
    }
  }

  // ================================================================================================
  // PROCESAR LLAMADA
  // ================================================================================================

  Future<void> _processIncomingCall(
    String phoneNumber,
  ) async {
    debugPrint(
      '🛡️ [JOSH PHONE] Procesando llamada: $phoneNumber',
    );

    if (phoneNumber.trim().isEmpty) {
      debugPrint(
        '⚠️ [JOSH PHONE] Número vacío. No se procesa.',
      );
      return;
    }

    // ----------------------------------------------------------------------------------------------
    // IMPORTANTE:
    // El overlay puede funcionar aunque la pantalla Flutter no esté visible.
    // Sin embargo, para ejecutar el análisis mediante SecurityProvider
    // necesitamos que el árbol Provider siga disponible.
    // ----------------------------------------------------------------------------------------------

    if (!mounted) {
      debugPrint(
        '⚠️ [JOSH PHONE] Activity Flutter no está montada.',
      );

      await _showFallbackOverlay(
        phoneNumber,
      );

      return;
    }

    try {
      // --------------------------------------------------------------------------------------------
      // SECURITY PROVIDER
      // --------------------------------------------------------------------------------------------

      final SecurityProvider provider =
          Provider.of<SecurityProvider>(
        context,
        listen: false,
      );

      // --------------------------------------------------------------------------------------------
      // ANÁLISIS
      // --------------------------------------------------------------------------------------------

      debugPrint(
        '🧠 [JOSH PHONE] Iniciando análisis de seguridad...',
      );

      await provider.executeAuditoria(
        phoneNumber,
        0,
      );

      // --------------------------------------------------------------------------------------------
      // RESULTADO
      // --------------------------------------------------------------------------------------------

      final double riskScore =
          provider.vulnerabilityScore;

      final String verdict =
          provider.verdictText;

      final String reasoning =
          provider.agentReasoningText;

      debugPrint(
        '🧠 [JOSH PHONE] Riesgo: '
        '${riskScore.toStringAsFixed(1)}%',
      );

      debugPrint(
        '🧠 [JOSH PHONE] Veredicto: $verdict',
      );

      debugPrint(
        '🧠 [JOSH PHONE] Razonamiento: $reasoning',
      );

      // --------------------------------------------------------------------------------------------
      // OVERLAY
      // --------------------------------------------------------------------------------------------

      debugPrint(
        '🪟 [JOSH OVERLAY] Mostrando alerta flotante...',
      );

      await OverlayService.showWarningOverlay(
        phoneNumber: phoneNumber,
        riskLevel: verdict,
        message: _buildOverlayMessage(
          riskScore,
          verdict,
        ),
        agentReasoning: reasoning,
      );

      debugPrint(
        '🪟 [JOSH OVERLAY] Solicitud de overlay completada.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ [JOSH PHONE] Error procesando llamada: $e',
      );

      debugPrint(stackTrace.toString());

      await _showFallbackOverlay(
        phoneNumber,
      );
    }
  }

  // ================================================================================================
  // FALLBACK OVERLAY
  // ================================================================================================

  Future<void> _showFallbackOverlay(
    String phoneNumber,
  ) async {
    try {
      debugPrint(
        '🪟 [JOSH OVERLAY] Ejecutando fallback...',
      );

      await OverlayService.showWarningOverlay(
        phoneNumber: phoneNumber,
        riskLevel: 'LLAMADA ENTRANTE',
        message: 'Llamada recibida. Centinela activo.',
        agentReasoning:
            'No fue posible completar el análisis automático.',
      );

      debugPrint(
        '🪟 [JOSH OVERLAY] Fallback mostrado correctamente.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ [JOSH OVERLAY] Error mostrando fallback: $e',
      );

      debugPrint(stackTrace.toString());
    }
  }

  // ================================================================================================
  // MENSAJE DEL OVERLAY
  // ================================================================================================

  String _buildOverlayMessage(
    double score,
    String verdict,
  ) {
    if (score >= 70) {
      return '⚠️ LLAMADA DE ALTO RIESGO\n$verdict';
    }

    if (score >= 30) {
      return '⚠️ LLAMADA SOSPECHOSA\n$verdict';
    }

    return '🛡️ LLAMADA ANALIZADA\n$verdict';
  }

  // ================================================================================================
  // BUILD
  // ================================================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      title: 'JOSH Security',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1E293B),
        scaffoldBackgroundColor:
            const Color(0xFF0F172A),
        useMaterial3: true,
      ),
      home: widget.mostrarOnboarding
          ? const OnboardingScreen()
          : const HomeScreen(),
    );
  }

  // ================================================================================================
  // DISPOSE
  // ================================================================================================

  @override
  void dispose() {
    _phoneChannel.setMethodCallHandler(null);
    super.dispose();
  }
}
