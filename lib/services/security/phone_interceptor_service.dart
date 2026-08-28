import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PhoneInterceptorService {
  static final PhoneInterceptorService _instance =
      PhoneInterceptorService._internal();

  factory PhoneInterceptorService() => _instance;

  PhoneInterceptorService._internal();

  static const MethodChannel _channel =
      MethodChannel('josh_security/phone_calls');

  bool _isListening = false;

  bool get isListening => _isListening;

  // ================================================================================================
  // INICIALIZACIÓN
  // ================================================================================================

  Future<void> initialize() async {
    debugPrint(
      '[JOSH_PHONE_INTERCEPTOR] Inicializado '
      '(modo CallScreeningService nativo activo).',
    );
  }

  // ================================================================================================
  // ESCUCHA DE LLAMADAS
  // ================================================================================================

  void startListening([void Function(dynamic)? onIncomingCall]) {
    _isListening = true;

    debugPrint(
      '[JOSH_PHONE_INTERCEPTOR] Escucha delegada al '
      'CallScreeningService nativo.',
    );
  }

  // ================================================================================================
  // LLAMADA ENTRANTE
  // ================================================================================================

  Future<void> handleIncomingCall(dynamic phoneNumber) async {
    final String number = phoneNumber?.toString().trim().isEmpty ?? true
        ? 'Número Oculto'
        : phoneNumber.toString().trim();

    debugPrint(
      '[JOSH_PHONE_INTERCEPTOR] Llamada entrante: $number',
    );
  }

  // ================================================================================================
  // LLAMADA FINALIZADA
  // ================================================================================================

  Future<void> handleCallEnded([dynamic eventData]) async {
    debugPrint(
      '[JOSH_PHONE_INTERCEPTOR] Llamada finalizada.',
    );
  }

  // ================================================================================================
  // HISTORIAL NATIVO
  // ================================================================================================

  static Future<List<Map<String, dynamic>>> getNativeCallHistory() async {
    try {
      final List<dynamic>? rawList =
          await _channel.invokeMethod<List<dynamic>>(
        'getNativeCallHistory',
      );

      debugPrint(
        '[JOSH_INTERCEPTOR] Registros recibidos del canal nativo: '
        '${rawList?.length ?? 0}',
      );

      if (rawList == null || rawList.isEmpty) {
        return [];
      }

      return rawList.whereType<Map>().map((item) {
        final Map<String, dynamic> raw =
            Map<String, dynamic>.from(item);

        final dynamic rawRiskScore = raw['risk_score'] ?? raw['riskScore'];

        double riskScore = 0.0;

        if (rawRiskScore is num) {
          riskScore = rawRiskScore.toDouble();
        } else if (rawRiskScore != null) {
          riskScore =
              double.tryParse(rawRiskScore.toString()) ?? 0.0;
        }

        return <String, dynamic>{
          'id': raw['id'],
          'phoneNumber':
              raw['number'] ??
              raw['phoneNumber'] ??
              'Desconocido',
          'name':
              raw['name'] ??
              raw['callerName'] ??
              'Desconocido',
          'timestamp':
              raw['timestamp'] ??
              DateTime.now().millisecondsSinceEpoch,
          'type':
              raw['type'] ??
              'ENTRANTE',
          'status':
              raw['status'] ??
              'SEGURO',
          'riskScore': riskScore,
          'verified':
              raw['verified'] == true ||
              raw['isVerified'] == true,
        };
      }).toList();
    } on PlatformException catch (e) {
      debugPrint(
        '[JOSH_INTERCEPTOR] PlatformException en getNativeCallHistory: ${e.code} - ${e.message}',
      );
      return [];
    } catch (e, stackTrace) {
      debugPrint(
        '[JOSH_INTERCEPTOR] Error inesperado procesando historial: $e\n$stackTrace',
      );
      return [];
    }
  }

  // ================================================================================================
  // LIMPIAR HISTORIAL NATIVO
  // ================================================================================================

  static Future<int> clearNativeCallHistory() async {
    try {
      final int deletedRows =
          await _channel.invokeMethod<int>(
            'clearNativeCallHistory',
          ) ??
          0;

      debugPrint(
        '[JOSH_INTERCEPTOR] Se eliminaron $deletedRows filas de SQLite.',
      );

      return deletedRows;
    } on PlatformException catch (e) {
      debugPrint(
        '[JOSH_INTERCEPTOR] Error al limpiar historial: '
        '${e.code} - ${e.message}',
      );
      return 0;
    } catch (e, stackTrace) {
      debugPrint(
        '[JOSH_INTERCEPTOR] Error inesperado limpiando historial: $e\n$stackTrace',
      );
      return 0;
    }
  }

  // ================================================================================================
  // DISPOSE
  // ================================================================================================

  void dispose() {
    _isListening = false;

    debugPrint(
      '[JOSH_PHONE_INTERCEPTOR] Recursos liberados.',
    );
  }
}
