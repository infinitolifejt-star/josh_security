// ====================================================================================================
// ARCHIVO: lib/services/security/phone_interceptor_service.dart
// RECEPTOR Y PROCESADOR DE LLAMADAS - JOSH SECURITY v6.1
// Coordinador de Eventos Nativos y Sincronización de UI (Sin peticiones HTTP duplicadas)
// ====================================================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'database_service.dart';

class PhoneInterceptorService {
  static final PhoneInterceptorService _instance =
      PhoneInterceptorService._internal();

  factory PhoneInterceptorService() => _instance;

  PhoneInterceptorService._internal();

  static const MethodChannel _channel =
      MethodChannel('josh_security/phone_calls');

  static const EventChannel _refreshEventChannel =
      EventChannel('com.josh.security/call_refresh');

  final StreamController<void> _callLogUpdateController =
      StreamController<void>.broadcast();

  /// Stream para que la interfaz gráfica escuche actualizaciones en vivo del historial
  Stream<void> get onCallLogUpdated => _callLogUpdateController.stream;

  StreamSubscription? _eventSubscription;
  bool _isListening = false;

  bool get isListening => _isListening;

  // ================================================================================================
  // INICIALIZACIÓN Y CONFIGURACIÓN DE CANALES NATIVOS
  // ================================================================================================

  Future<void> initialize() async {
    _setupMethodChannelHandler();
    _setupNativeRefreshListener();
    debugPrint(
      '[JOSH_PHONE_INTERCEPTOR] Inicializado con listener de canal nativo y sincronización en vivo.',
    );
  }

  void _setupMethodChannelHandler() {
    _channel.setMethodCallHandler((MethodCall call) async {
      debugPrint('[JOSH_PHONE_INTERCEPTOR] Método nativo invocado: ${call.method}');
      switch (call.method) {
        case 'onIncomingCall':
          final dynamic phoneNumber = call.arguments;
          await handleIncomingCall(phoneNumber);
          break;
        case 'onCallEnded':
          await handleCallEnded(call.arguments);
          break;
        default:
          debugPrint('[JOSH_PHONE_INTERCEPTOR] Método no implementado: ${call.method}');
          break;
      }
    });
  }

  void _setupNativeRefreshListener() {
    _eventSubscription?.cancel();
    try {
      _eventSubscription = _refreshEventChannel
          .receiveBroadcastStream()
          .listen(
            (dynamic event) {
              debugPrint(
                '[JOSH_PHONE_INTERCEPTOR] Notificación de refresco recibida desde Android.',
              );
              _callLogUpdateController.add(null);
            },
            onError: (dynamic error) {
              debugPrint(
                '[JOSH_PHONE_INTERCEPTOR] Error en EventChannel de refresco: $error',
              );
            },
          );
    } catch (e) {
      debugPrint(
        '[JOSH_PHONE_INTERCEPTOR] EventChannel no disponible: $e',
      );
    }
  }

  // ================================================================================================
  // ESCUCHA DE LLAMADAS
  // ================================================================================================

  void startListening([void Function(dynamic)? onIncomingCall]) {
    _isListening = true;
    _setupMethodChannelHandler();
    _setupNativeRefreshListener();

    debugPrint(
      '[JOSH_PHONE_INTERCEPTOR] Escucha delegada y canales sincronizados con CallScreeningService.',
    );
  }

  // ================================================================================================
  // MANEJO DE LLAMADA ENTRANTE (SIN DUPLICACIÓN DE PETICIONES HTTP)
  // ================================================================================================

  Future<void> handleIncomingCall(dynamic phoneNumber) async {
    final String number = phoneNumber?.toString().trim().isEmpty ?? true
        ? 'Número Oculto'
        : phoneNumber.toString().trim();

    debugPrint(
      '[JOSH_PHONE_INTERCEPTOR] Notificación de llamada recibida desde Android: $number',
    );

    try {
      // Registrar en la bitácora forense el evento de recepción sin duplicar la petición HTTP
      await DatabaseService.instance.insertForensicLog({
        'timestamp': DateTime.now().toIso8601String(),
        'service': 'PhoneInterceptorService',
        'activity': 'Llamada Entrante Detectada: $number',
        'verdict': 'EVALUANDO',
        'matched_rule': 'INCOMING_CALL_SCREENING',
        'extra_data': '{"phoneNumber": "$number", "source": "JoshCallScreeningService"}',
      });

      // Emitir evento para refrescar UI en Flutter
      _callLogUpdateController.add(null);
    } catch (e, stackTrace) {
      debugPrint(
        '[JOSH_PHONE_INTERCEPTOR] Error al registrar evento forense: $e\n$stackTrace',
      );
    }
  }

  // ================================================================================================
  // LLAMADA FINALIZADA
  // ================================================================================================

  Future<void> handleCallEnded([dynamic eventData]) async {
    debugPrint(
      '[JOSH_PHONE_INTERCEPTOR] Llamada finalizada.',
    );
    _callLogUpdateController.add(null);
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
        final Map<String, dynamic> raw = Map<String, dynamic>.from(item);

        final dynamic rawRiskScore = raw['risk_score'] ?? raw['riskScore'];

        double riskScore = -1.0;

        if (rawRiskScore is num) {
          riskScore = rawRiskScore.toDouble();
        } else if (rawRiskScore != null) {
          riskScore = double.tryParse(rawRiskScore.toString()) ?? -1.0;
        }

        return <String, dynamic>{
          'id': raw['id'],
          'phoneNumber':
              raw['number'] ?? raw['phoneNumber'] ?? 'Desconocido',
          'name': raw['name'] ?? raw['callerName'] ?? 'Desconocido',
          'timestamp':
              raw['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
          'type': raw['type'] ?? 'ENTRANTE',
          'status': raw['status'] ?? 'NO_VERIFICADO',
          'riskScore': riskScore,
          'verified':
              raw['verified'] == true || raw['isVerified'] == true,
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
        '[JOSH_INTERCEPTOR] Error al limpiar historial: ${e.code} - ${e.message}',
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
    _eventSubscription?.cancel();
    _callLogUpdateController.close();

    debugPrint(
      '[JOSH_PHONE_INTERCEPTOR] Recursos liberados.',
    );
  }
}
