import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';
import '../models/session.dart';
import '../utils/json_read.dart';

class PushNotificationService {
  PushNotificationService({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const _channel = AndroidNotificationChannel(
    'reminders',
    'תזכורות',
    description: 'תזכורות למשימות ולקוחות',
    importance: Importance.high,
  );

  final ApiClient _apiClient;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  Future<void> Function({
    required String type,
    required String id,
    String? title,
  })?
  onOpenNotification;

  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  String? _registeredToken;
  String? _registeredBusinessId;
  AppSession? _session;
  _NotificationTarget? _pendingTarget;

  Future<void> configureForSession(AppSession session) async {
    if (_apiClient.isMockAuth || !session.hasBusiness || kIsWeb) return;
    _session = session;
    await _initialize();
    await _registerCurrentToken(session);
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen((token) => _registerToken(session, token));
    await _openPendingTarget();
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
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
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, Object?>) {
          _handleOpenedData(decoded);
        }
      },
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
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedNotification,
    );
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedNotification(initialMessage);
    }
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
      payload: jsonEncode(message.data),
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

  void _handleOpenedNotification(RemoteMessage message) {
    _handleOpenedData(message.data);
  }

  void _handleOpenedData(Map<String, Object?> data) {
    final target = _NotificationTarget.fromData(data);
    if (target == null) return;
    _pendingTarget = target;
    unawaited(_openPendingTarget());
  }

  Future<void> _openPendingTarget() async {
    final target = _pendingTarget;
    final session = _session;
    final onOpen = onOpenNotification;
    if (target == null ||
        session == null ||
        !session.hasBusiness ||
        onOpen == null) {
      return;
    }

    _pendingTarget = null;
    await onOpen(type: target.type, id: target.id, title: target.title);
  }
}

class _NotificationTarget {
  const _NotificationTarget({required this.type, required this.id, this.title});

  final String type;
  final String id;
  final String? title;

  static _NotificationTarget? fromData(Map<String, Object?> data) {
    final type =
        nullableString(data['itemType']) ??
        nullableString(data['type']) ??
        (nullableString(data['reminderId']) == null ? null : 'reminder');
    final id =
        nullableString(data['itemId']) ??
        nullableString(data['reminderId']) ??
        nullableString(data['notificationId']);
    if (type == null || id == null || id.isEmpty) return null;
    return _NotificationTarget(
      type: type,
      id: id,
      title: nullableString(data['title']),
    );
  }
}
