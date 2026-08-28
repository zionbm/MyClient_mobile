import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';
import '../models/session.dart';

class PushNotificationService {
  PushNotificationService({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const _channel = AndroidNotificationChannel(
    'task_reminders',
    'תזכורות',
    description: 'תזכורות למשימות ולקוחות',
    importance: Importance.high,
  );

  final ApiClient _apiClient;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  String? _registeredToken;
  String? _registeredBusinessId;

  Future<void> configureForSession(AppSession session) async {
    if (_apiClient.isMockAuth || !session.hasBusiness || kIsWeb) return;
    await _initialize();
    await _registerCurrentToken(session);
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen((token) => _registerToken(session, token));
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
  }

  Future<void> _registerCurrentToken(AppSession session) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _registerToken(session, token);
  }

  Future<void> _registerToken(AppSession session, String token) async {
    final businessId = session.businessId;
    if (businessId == null || businessId.isEmpty) return;
    if (_registeredToken == token && _registeredBusinessId == businessId) {
      return;
    }
    try {
      await _apiClient.registerDeviceToken(
        businessId: businessId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        token: token,
        platform: Platform.isAndroid
            ? 'android'
            : Platform.isIOS
            ? 'ios'
            : null,
      );
      _registeredToken = token;
      _registeredBusinessId = businessId;
    } catch (_) {
      // Push registration should not block login or regular app usage.
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'MyClient';
    final body = notification?.body ?? message.data['body'] ?? '';
    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
