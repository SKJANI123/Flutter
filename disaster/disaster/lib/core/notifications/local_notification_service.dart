import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:disaster/core/errors/exceptions.dart';

/// Local (on-device) notifications for alerts and SOS.
///
/// FCM push notifications can be wired later through the same abstraction —
/// see README "Firebase / FCM".
class LocalNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
      _initialized = false;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized;

  static const int alertChannelId = 1;
  static const int sosChannelId = 2;
  static const String alertChannel = 'disaster_alerts';
  static const String sosChannel = 'sos_alerts';

  Future<bool> initialize() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestSoundPermission: true,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestSoundPermission: true,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (details) => _onTap(details),
      );
      // Android 13+ runtime permission.
      await requestPermission();
      _initialized = true;
      return true;
    } catch (e) {
      _initialized = false;
      return false;
    }
  }

  void _onTap(NotificationResponse response) {
    // Payload carries a disaster id so a tapped notification can deep-link.
    _onTapCallback?.call(response.payload);
  }

  void Function(String? payload)? _onTapCallback;
  void setOnTapCallback(void Function(String? payload)? cb) =>
      _onTapCallback = cb;

  Future<bool> requestPermission() async {
    try {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await impl?.requestNotificationsPermission();
      return granted ?? true;
    } catch (e) {
      return true; // never treat plugin quirks as fatal
    }
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final enabled = await impl?.areNotificationsEnabled();
      return enabled ?? true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> showAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    return _show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelId: alertChannel,
      channelName: 'Disaster alerts',
    );
  }

  Future<bool> showSos({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    return _show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelId: sosChannel,
      channelName: 'SOS alerts',
    );
  }

  Future<bool> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
    required String channelId,
    required String channelName,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelName,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
      );
      final darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      );
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        ),
        payload: payload,
      );
      return true;
    } catch (e) {
      throw NotificationException('Could not show notification', cause: e);
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  void dispose() {}
}
