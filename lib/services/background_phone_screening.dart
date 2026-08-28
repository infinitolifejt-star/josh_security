import 'package:flutter/foundation.dart';
import 'security/phone_interceptor_service.dart';

class BackgroundPhoneScreening {
  final PhoneInterceptorService _interceptorService = PhoneInterceptorService();

  Future<void> initializeBackgroundService() async {
    await _interceptorService.initialize();
  }

  Future<void> onIncomingCallDetected(String phoneNumber) async {
    debugPrint('[JOSH_BACKGROUND] Procesando llamada en segundo plano: $phoneNumber');
    await _interceptorService.handleIncomingCall(phoneNumber);
  }

  Future<void> onCallEndedDetected() async {
    debugPrint('[JOSH_BACKGROUND] Finalizando sesión de llamada en segundo plano');
    await _interceptorService.handleCallEnded();
  }
}
