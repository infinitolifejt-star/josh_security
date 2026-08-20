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
    } on PlatformException catch (e, stackTrace) {
      debugPrint(
        '⚠️ [JOSH PERMISSIONS] Error Android CALL LOG: '
        '${e.code} - ${e.message}',
      );

      debugPrint(stackTrace.toString());
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
  // CONTROL DE DUPLICADOS
  // ================================================================================================

  final Set<String> _callsBeingProcessed = <String>{};

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
    final dynamic arguments = call.arguments;

    if (arguments is! Map) {
      debugPrint(
        '⚠️ [JOSH PHONE] onCallIntercepted sin argumentos válidos.',
      );
      return;
    }

    final String phoneNumber =
        _extractPhoneNumber(arguments);

    debugPrint(
      '📞 [JOSH PHONE] Número entrante: $phoneNumber',
    );

    final bool processed =
        await _processIncomingCall(phoneNumber);

    // ----------------------------------------------------------------------------------------------
    // IMPORTANTE:
    // Si el evento fue procesado correctamente, eliminamos el respaldo pendiente.
    // Así evitamos reprocesar la misma llamada al abrir/reanudar la aplicación.
    // ----------------------------------------------------------------------------------------------

    if (processed) {
      try {
        await _phoneChannel.invokeMethod(
          'clearPendingCall',
        );

        debugPrint(
          '📞 [JOSH PHONE] Pending call limpiado después del procesamiento.',
        );
      } catch (e, stackTrace) {
        debugPrint(
          '⚠️ [JOSH PHONE] No fue posible limpiar pending call: $e',
        );

        debugPrint(stackTrace.toString());
      }
    }
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
          _extractPhoneNumber(result);

      debugPrint(
        '📞 [JOSH PHONE] Llamada pendiente recuperada: '
        '$phoneNumber',
      );

      final bool processed =
          await _processIncomingCall(phoneNumber);

      // --------------------------------------------------------------------------------------------
      // SOLO SE LIMPIA SI EL PROCESAMIENTO TERMINÓ CORRECTAMENTE
      // --------------------------------------------------------------------------------------------

      if (processed) {
        await _phoneChannel.invokeMethod(
          'clearPendingCall',
        );

        debugPrint(
          '📞 [JOSH PHONE] Llamada pendiente limpiada.',
        );
      } else {
        debugPrint(
          '⚠️ [JOSH PHONE] Llamada pendiente conservada '
          'porque el procesamiento no terminó correctamente.',
        );
      }
    } on PlatformException catch (e, stackTrace) {
      debugPrint(
        '⚠️ [JOSH PHONE] Error Android recuperando llamada pendiente: '
        '${e.code} - ${e.message}',
      );

      debugPrint(stackTrace.toString());
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

  Future<bool> _processIncomingCall(
    String phoneNumber,
  ) async {
    final String normalizedNumber =
        _normalizePhoneNumber(phoneNumber);

    debugPrint(
      '🛡️ [JOSH PHONE] Procesando llamada: $normalizedNumber',
    );

    if (normalizedNumber.isEmpty) {
      debugPrint(
        '⚠️ [JOSH PHONE] Número vacío. No se procesa.',
      );
      return false;
    }

    // ----------------------------------------------------------------------------------------------
    // EVITAR DUPLICADOS
    // ----------------------------------------------------------------------------------------------

    if (_callsBeingProcessed.contains(normalizedNumber)) {
      debugPrint(
        'ℹ️ [JOSH PHONE] Llamada ya está siendo procesada. '
        'Evento duplicado ignorado: $normalizedNumber',
      );

      return true;
    }

    _callsBeingProcessed.add(normalizedNumber);

    try {
      // --------------------------------------------------------------------------------------------
      // SI FLUTTER NO ESTÁ MONTADO
      // --------------------------------------------------------------------------------------------

      if (!mounted) {
        debugPrint(
          '⚠️ [JOSH PHONE] Activity Flutter no está montada.',
        );

        await _showFallbackOverlay(
          normalizedNumber,
        );

        return false;
      }

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
        normalizedNumber,
        0,
      );

      if (!mounted) {
        debugPrint(
          '⚠️ [JOSH PHONE] Widget desmontado después del análisis.',
        );

        await _showFallbackOverlay(
          normalizedNumber,
        );

        return false;
      }

      // --------------------------------------------------------------------------------------------
      // RESULTADO
      // --------------------------------------------------------------------------------------------

      final double riskScore =
          _safeRiskScore(
        provider.vulnerabilityScore,
      );

      final String verdict =
          _safeText(
        provider.verdictText,
        fallback: 'LLAMADA ANALIZADA',
      );

      final String reasoning =
          _safeText(
        provider.agentReasoningText,
        fallback: 'Sin razonamiento adicional disponible.',
      );

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
        phoneNumber: normalizedNumber,
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

      return true;
    } catch (e, stackTrace) {
      debugPrint(
        '❌ [JOSH PHONE] Error procesando llamada: $e',
      );

      debugPrint(stackTrace.toString());

      await _showFallbackOverlay(
        normalizedNumber,
      );

      return false;
    } finally {
      _callsBeingProcessed.remove(normalizedNumber);
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
        message:
            'Llamada recibida. Centinela activo.',
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
  // EXTRACCIÓN SEGURA DEL NÚMERO
  // ================================================================================================

  String _extractPhoneNumber(
    Map<dynamic, dynamic> data,
  ) {
    final dynamic raw =
        data['phoneNumber'] ??
        data['phone_number'] ??
        data['number'] ??
        data['phone'];

    if (raw == null) {
      return 'Número Oculto';
    }

    final String value =
        raw.toString().trim();

    return value.isEmpty
        ? 'Número Oculto'
        : value;
  }

  // ================================================================================================
  // NORMALIZACIÓN
  // ================================================================================================

  String _normalizePhoneNumber(
    String value,
  ) {
    final String normalized =
        value.trim();

    if (normalized.isEmpty) {
      return 'Número Oculto';
    }

    return normalized;
  }

  // ================================================================================================
  // SCORE SEGURO
  // ================================================================================================

  double _safeRiskScore(
    dynamic value,
  ) {
    if (value is num) {
      final double score =
          value.toDouble();

      if (!score.isFinite) {
        return 0.0;
      }

      return score.clamp(0.0, 100.0);
    }

    if (value is String) {
      final double? parsed =
          double.tryParse(value);

      if (parsed != null &&
          parsed.isFinite) {
        return parsed.clamp(0.0, 100.0);
      }
    }

    return 0.0;
  }

  // ================================================================================================
  // TEXTO SEGURO
  // ================================================================================================

  String _safeText(
    dynamic value, {
    required String fallback,
  }) {
    if (value == null) {
      return fallback;
    }

    final String text =
        value.toString().trim();

    return text.isEmpty
        ? fallback
        : text;
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
    _callsBeingProcessed.clear();

    _phoneChannel.setMethodCallHandler(null);

    super.dispose();
  }
}
