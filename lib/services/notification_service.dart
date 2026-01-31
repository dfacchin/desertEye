import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servizio per gestire le notifiche di sistema
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Canali di notifica
  static const String _channelIdMessages = 'desert_eye_messages';
  static const String _channelNameMessages = 'Messaggi Mesh';
  static const String _channelDescMessages = 'Notifiche per messaggi ricevuti dalla rete mesh';

  static const String _channelIdSos = 'desert_eye_sos';
  static const String _channelNameSos = 'Emergenze SOS';
  static const String _channelDescSos = 'Notifiche urgenti per emergenze SOS';

  static const String _channelIdService = 'desert_eye_service';
  static const String _channelNameService = 'Servizio Background';
  static const String _channelDescService = 'Notifica del servizio in background';

  /// Inizializza il servizio notifiche
  Future<bool> initialize() async {
    if (_initialized) return true;

    // Richiedi permesso notifiche su Android 13+
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        return false;
      }
    }

    // Configurazione Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configurazione iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Crea canali Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }

    _initialized = true;
    return true;
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Canale messaggi (priorità normale)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelIdMessages,
        _channelNameMessages,
        description: _channelDescMessages,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Canale SOS (priorità massima)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelIdSos,
        _channelNameSos,
        description: _channelDescSos,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );

    // Canale servizio background (priorità bassa)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelIdService,
        _channelNameService,
        description: _channelDescService,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    // Gestisci tap sulla notifica
    // Il payload contiene informazioni sulla notifica
    final payload = response.payload;
    if (payload != null) {
      // ignore: avoid_print
      print('[Notification] Tapped: $payload');
    }
  }

  /// Mostra notifica per messaggio ricevuto
  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    String? nodeId,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      _channelIdMessages,
      _channelNameMessages,
      channelDescription: _channelDescMessages,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      'Messaggio da $senderName',
      message,
      details,
      payload: 'message:$nodeId',
    );
  }

  /// Mostra notifica per emergenza SOS
  Future<void> showSosNotification({
    required String senderName,
    required String message,
    String? nodeId,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      _channelIdSos,
      _channelNameSos,
      channelDescription: _channelDescSos,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      colorized: true,
      color: const Color(0xFFFF0000),
      styleInformation: BigTextStyleInformation(
        message,
        contentTitle: 'EMERGENZA SOS',
        summaryText: 'da $senderName',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1000, // ID fisso per SOS (sovrascrive precedenti)
      'EMERGENZA SOS da $senderName',
      message,
      details,
      payload: 'sos:$nodeId',
    );
  }

  /// Annulla notifica SOS
  Future<void> cancelSosNotification() async {
    await _notifications.cancel(1000);
  }

  /// Mostra notifica persistente per servizio background
  Future<void> showServiceNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      _channelIdService,
      _channelNameService,
      channelDescription: _channelDescService,
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      0, // ID fisso per servizio
      title,
      body,
      details,
    );
  }

  /// Aggiorna notifica servizio
  Future<void> updateServiceNotification({
    required String title,
    required String body,
  }) async {
    await showServiceNotification(title: title, body: body);
  }

  /// Annulla notifica servizio
  Future<void> cancelServiceNotification() async {
    await _notifications.cancel(0);
  }

  /// Annulla tutte le notifiche
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
