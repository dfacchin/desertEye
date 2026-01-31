import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';

/// Servizio background per mantenere l'app attiva
class BackgroundServiceManager {
  static final BackgroundServiceManager _instance = BackgroundServiceManager._internal();
  factory BackgroundServiceManager() => _instance;
  BackgroundServiceManager._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _initialized = false;

  /// Inizializza il servizio background
  Future<void> initialize() async {
    if (_initialized) return;

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: 'desert_eye_service',
        initialNotificationTitle: 'DesertEye',
        initialNotificationContent: 'Monitoraggio rete mesh attivo',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [
          AndroidForegroundType.connectedDevice,
          AndroidForegroundType.location,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    _initialized = true;
  }

  /// Avvia il servizio background
  Future<void> startService() async {
    if (!_initialized) await initialize();
    await _service.startService();
  }

  /// Ferma il servizio background
  Future<void> stopService() async {
    _service.invoke('stopService');
  }

  /// Verifica se il servizio è in esecuzione
  Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  /// Aggiorna la notifica del servizio
  void updateNotification(String title, String content) {
    _service.invoke('updateNotification', {
      'title': title,
      'content': content,
    });
  }
}

/// Entry point per il servizio background Android/iOS foreground
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('updateNotification').listen((event) {
    if (service is AndroidServiceInstance) {
      final title = event?['title'] as String? ?? 'DesertEye';
      final content = event?['content'] as String? ?? 'Servizio attivo';
      service.setForegroundNotificationInfo(
        title: title,
        content: content,
      );
    }
  });

  // Mantieni il servizio attivo con un timer periodico
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Aggiorna timestamp nella notifica per mostrare che il servizio è attivo
        service.setForegroundNotificationInfo(
          title: 'DesertEye',
          content: 'Monitoraggio mesh attivo',
        );
      }
    }

    // Invia evento di heartbeat all'app principale
    service.invoke('heartbeat', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  });
}

/// Entry point per iOS background
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
