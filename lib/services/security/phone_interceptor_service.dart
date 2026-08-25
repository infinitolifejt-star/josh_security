// ====================================================================================================
// ARCHIVO: lib/services/security/phone_interceptor_service.dart
// PROJECT JOSH SECURITY v6.0
// ====================================================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PhoneInterceptorService {
  static final PhoneInterceptorService _instance =
      PhoneInterceptorService._internal();

  factory PhoneInterceptorService() => _instance;

  PhoneInterceptorService._internal();

  static const MethodChannel _channel =
      MethodChannel('josh_security/phone_calls');
  static const EventChannel _eventChannel =
      EventChannel('josh_security/phone_calls_events');

  StreamSubscription<dynamic>? _incomingCallSubscription;
  bool _isListening = false;

  /// Getter público para acceder al canal de comandos
  static MethodChannel get channel => _channel;

  /// Getter público para el estado de la escucha
  bool get isListening => _isListening;

  /// Inicializa el servicio en segundo plano o durante el arranque del sistema
  Future<void> initialize() async {
    debugPrint('📱 [JOSH_PHONE_INTERCEPTOR] Inicializando servicio nativo...');
    try {
      await _channel.invokeMethod<void>('initializeService');
    } on PlatformException catch (e) {
      debugPrint('⚠️ [JOSH_PHONE_INTERCEPTOR] Error al inicializar servicio: ${e.message}');
    }
  }

  /// Inicializa los oyentes en primer plano (UI activada)
  static void initializeForegroundListener() {
    debugPrint('📱 [JOSH_PHONE_INTERCEPTOR] Listener de primer plano configurado.');
  }

  /// Inicia la escucha activa de eventos telefónicos desde el canal nativo
  void startListening({
    void Function(String phoneNumber)? onIncomingCall,
    void Function()? onCallEnded,
  }) {
    if (_isListening) return;

    _incomingCallSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen((dynamic event) {
      if (event is Map) {
        final String? state = event['state'] as String?;
        final String? phoneNumber = event['phoneNumber'] as String?;

        if (state == 'INCOMING' && phoneNumber != null) {
          debugPrint('📱 [JOSH_PHONE_INTERCEPTOR] Evento entrante: $phoneNumber');
          if (onIncomingCall != null) onIncomingCall(phoneNumber);
        } else if (state == 'ENDED') {
          debugPrint('📱 [JOSH_PHONE_INTERCEPTOR] Evento finalizado.');
          if (onCallEnded != null) onCallEnded();
        }
      }
    }, onError: (dynamic error) {
      debugPrint('⚠️ [JOSH_PHONE_INTERCEPTOR] Error en stream de llamadas: $error');
    });

    _isListening = true;
    debugPrint('📱 [JOSH_PHONE_INTERCEPTOR] Escucha de llamadas iniciada.');
  }

  /// Notifica al motor nativo la intercepción de una llamada entrante
  Future<void> handleIncomingCall(String phoneNumber) async {
    try {
      debugPrint('📱 [JOSH_PHONE_INTERCEPTOR] Procesando llamada entrante: $phoneNumber');
      await _channel.invokeMethod<void>('onCallIntercepted', {
        'phoneNumber': phoneNumber,
      });
    } on PlatformException catch (e) {
      debugPrint('⚠️ [JOSH_PHONE_INTERCEPTOR] Error enviando a canal nativo: ${e.message}');
    }
  }

  /// Notifica al motor nativo la finalización de una llamada
  Future<void> handleCallEnded() async {
    try {
      debugPrint('📱 [JOSH_PHONE_INTERCEPTOR] Llamada finalizada procesada.');
      await _channel.invokeMethod<void>('onCallEnded');
    } on PlatformException catch (e) {
      debugPrint('⚠️ [JOSH_PHONE_INTERCEPTOR] Error enviando fin de llamada: ${e.message}');
    }
  }

  /// Libera recursos y remueve suscripciones activas
  void dispose() {
    _incomingCallSubscription?.cancel();
    _incomingCallSubscription = null;
    _isListening = false;
    debugPrint('📱 [JOSH_PHONE_INTERCEPTOR] Servicio liberado.');
  }
}
