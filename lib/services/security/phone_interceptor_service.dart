// ============================================================================
// ARCHIVO: lib/services/security/phone_interceptor_service.dart
// JOSH SECURITY
// SERVICIO CENTRAL DE PROTECCIÓN Y SCREENING TELEFÓNICO
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PhoneInterceptorService {
  static final PhoneInterceptorService _instance =
      PhoneInterceptorService._internal();

  factory PhoneInterceptorService() {
    return _instance;
  }

  PhoneInterceptorService._internal();

  // ==========================================================================
  // CANALES NATIVOS
  // ==========================================================================

  static const MethodChannel _channel =
      MethodChannel('josh_security/phone_calls');

  // ==========================================================================
  // ESTADO
  // ==========================================================================

  bool _initialized = false;
  bool _listening = false;

  bool _callScreeningRoleAvailable = false;
  bool _callScreeningRoleHeld = false;

  bool get isInitialized => _initialized;
  bool get isListening => _listening;

  bool get isCallScreeningRoleAvailable =>
      _callScreeningRoleAvailable;

  bool get isCallScreeningRoleHeld =>
      _callScreeningRoleHeld;

  // ==========================================================================
  // CALLBACKS
  // ==========================================================================

  Future<void> Function(String phoneNumber)? onIncomingCall;
  Future<void> Function()? onCallEnded;

  void Function(
    bool available,
    bool held,
  )? onCallScreeningRoleChanged;

  // ==========================================================================
  // INITIALIZE
  // ==========================================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _channel.setMethodCallHandler(_handleNativeMethod);

    _initialized = true;

    await refreshCallScreeningRole();

    debugPrint(
      '[JOSH PHONE] PhoneInterceptorService inicializado.',
    );
  }

  // ==========================================================================
  // REFRESH CALL SCREENING ROLE
  // ==========================================================================

  Future<void> refreshCallScreeningRole() async {
    try {
      final bool? available =
          await _channel.invokeMethod<bool>(
        'isCallScreeningRoleAvailable',
      );

      final bool? held =
          await _channel.invokeMethod<bool>(
        'isCallScreeningRoleHeld',
      );

      _callScreeningRoleAvailable = available ?? false;
      _callScreeningRoleHeld = held ?? false;

      debugPrint(
        '[JOSH PHONE] Call Screening disponible: '
        '$_callScreeningRoleAvailable',
      );

      debugPrint(
        '[JOSH PHONE] Call Screening concedido: '
        '$_callScreeningRoleHeld',
      );

      onCallScreeningRoleChanged?.call(
        _callScreeningRoleAvailable,
        _callScreeningRoleHeld,
      );
    } on PlatformException catch (error) {
      debugPrint(
        '[JOSH PHONE] Error consultando rol de screening: '
        '${error.code} ${error.message}',
      );

      _callScreeningRoleAvailable = false;
      _callScreeningRoleHeld = false;
    } catch (error) {
      debugPrint(
        '[JOSH PHONE] Error inesperado consultando rol: $error',
      );

      _callScreeningRoleAvailable = false;
      _callScreeningRoleHeld = false;
    }
  }

  // ==========================================================================
  // REQUEST CALL SCREENING ROLE
  // ==========================================================================

  Future<bool> requestCallScreeningRole() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>(
        'requestCallScreeningRole',
      );

      await refreshCallScreeningRole();

      final bool success = result ?? false;

      debugPrint(
        '[JOSH PHONE] Solicitud de rol de screening enviada: $success',
      );

      return success;
    } on PlatformException catch (error) {
      debugPrint(
        '[JOSH PHONE] Error solicitando rol de screening: '
        '${error.code} ${error.message}',
      );

      return false;
    } catch (error) {
      debugPrint(
        '[JOSH PHONE] Error inesperado solicitando rol: $error',
      );

      return false;
    }
  }

  // ==========================================================================
  // START LISTENING
  // ==========================================================================

  Future<void> startListening() async {
    await initialize();

    if (!_callScreeningRoleHeld) {
      debugPrint(
        '[JOSH PHONE] El rol CALL_SCREENING todavía no está concedido.',
      );

      return;
    }

    if (_listening) {
      return;
    }

    _listening = true;

    debugPrint(
      '[JOSH PHONE] startListening() activo.',
    );
  }

  // ==========================================================================
  // STOP LISTENING
  // ==========================================================================

  Future<void> stopListening() async {
    _listening = false;

    debugPrint(
      '[JOSH PHONE] stopListening() ejecutado.',
    );
  }

  // ==========================================================================
  // HANDLE INCOMING CALL
  // ==========================================================================

  Future<void> handleIncomingCall(
    String phoneNumber,
  ) async {
    final String number = phoneNumber.trim();

    debugPrint(
      '[JOSH PHONE] handleIncomingCall(): $number',
    );

    if (number.isEmpty) {
      debugPrint(
        '[JOSH PHONE] Número vacío.',
      );

      return;
    }

    final callback = onIncomingCall;

    if (callback != null) {
      try {
        await callback(number);
      } catch (error) {
        debugPrint(
          '[JOSH PHONE] Error en onIncomingCall: $error',
        );
      }
    }
  }

  // ==========================================================================
  // HANDLE CALL ENDED
  // ==========================================================================

  Future<void> handleCallEnded() async {
    debugPrint(
      '[JOSH PHONE] handleCallEnded().',
    );

    final callback = onCallEnded;

    if (callback != null) {
      try {
        await callback();
      } catch (error) {
        debugPrint(
          '[JOSH PHONE] Error en onCallEnded: $error',
        );
      }
    }
  }

  // ==========================================================================
  // HANDLE NATIVE METHOD
  // ==========================================================================

  Future<void> _handleNativeMethod(
    MethodCall call,
  ) async {
    debugPrint(
      '[JOSH PHONE] Evento nativo recibido: ${call.method}',
    );

    switch (call.method) {
      case 'onCallScreeningRoleChanged':
        final dynamic arguments = call.arguments;

        if (arguments is Map) {
          _callScreeningRoleAvailable =
              arguments['available'] == true;

          _callScreeningRoleHeld =
              arguments['held'] == true;

          debugPrint(
            '[JOSH PHONE] Cambio de rol recibido. '
            'available=$_callScreeningRoleAvailable '
            'held=$_callScreeningRoleHeld',
          );

          onCallScreeningRoleChanged?.call(
            _callScreeningRoleAvailable,
            _callScreeningRoleHeld,
          );
        }
        break;

      case 'onIncomingCall':
        final dynamic arguments = call.arguments;

        if (arguments is Map) {
          final dynamic rawNumber =
              arguments['phoneNumber'];

          final String number =
              rawNumber?.toString().trim() ?? '';

          if (number.isNotEmpty) {
            await handleIncomingCall(number);
          }
        }
        break;

      case 'onCallScreening':
        final dynamic arguments = call.arguments;

        if (arguments is Map) {
          final dynamic rawNumber =
              arguments['phoneNumber'];

          final String number =
              rawNumber?.toString().trim() ?? '';

          if (number.isNotEmpty) {
            await handleIncomingCall(number);
          }
        }
        break;

      case 'onCallEnded':
        await handleCallEnded();
        break;

      default:
        debugPrint(
          '[JOSH PHONE] Evento Android desconocido: '
          '${call.method}',
        );
        break;
    }
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  Future<void> dispose() async {
    _listening = false;

    if (_initialized) {
      _channel.setMethodCallHandler(null);
    }

    _initialized = false;

    debugPrint(
      '[JOSH PHONE] PhoneInterceptorService liberado.',
    );
  }
}
