// ====================================================================================================
// ARCHIVO: lib/services/background_phone_screening.dart
// ISOLATE Y SCREENING EN SEGUNDO PLANO PARA LLAMADAS ENTRANTE
// ====================================================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'security/phone_interceptor_service.dart';

const MethodChannel _backgroundPhoneChannel =
    MethodChannel('josh_security/background_phone');

late final PhoneInterceptorService _phoneInterceptorService;
bool _initialized = false;

@pragma('vm:entry-point')
Future<void> backgroundPhoneMain() async {
  await _initializeBackgroundPhone();

  _backgroundPhoneChannel.setMethodCallHandler(
    _handleBackgroundPhoneMethod,
  );
}

Future<void> _initializeBackgroundPhone() async {
  if (_initialized) return;

  _initialized = true;
  _phoneInterceptorService = PhoneInterceptorService();
  await _phoneInterceptorService.initialize();
}

Future<void> _handleBackgroundPhoneMethod(MethodCall call) async {
  switch (call.method) {
    case 'incomingCall':
      await _handleIncomingCall(call.arguments);
      break;

    case 'callEnded':
      await _handleCallEnded();
      break;
  }
}

Future<void> _handleIncomingCall(dynamic arguments) async {
  if (arguments is! Map) return;

  final dynamic rawNumber = arguments['phoneNumber'];
  final String phoneNumber =
      rawNumber?.toString().trim() ?? 'Número Oculto';

  if (phoneNumber.isEmpty) return;

  try {
    await _phoneInterceptorService.handleIncomingCall(phoneNumber);
  } catch (e) {
    debugPrint('⚠️ [JOSH_BACKGROUND_PHONE] Error al procesar llamada entrante: $e');
  }
}

Future<void> _handleCallEnded() async {
  try {
    await _phoneInterceptorService.handleCallEnded();
  } catch (e) {
    debugPrint('⚠️ [JOSH_BACKGROUND_PHONE] Error al procesar fin de llamada: $e');
  }
}
