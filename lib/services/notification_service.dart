import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_service.dart';

/// Shows system notifications (notification shade) for budget alerts
/// and receives FCM pushes when configured.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'spendwise_budget';
  static const _channelName = 'Budget alerts';
  static const _budgetNotificationId = 1001;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  String? _fcmToken;

  bool get isReady => _ready;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    if (_ready) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Alerts when you go over your monthly budget',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();

    if (FirebaseService.isReady) {
      await _setupFcm();
    }

    _ready = true;
  }

  Future<void> _setupFcm() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    FirebaseMessaging.onMessage.listen(_showRemoteMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('FCM opened app: ${msg.messageId}');
    });

    try {
      _fcmToken = await messaging.getToken();
      debugPrint('FCM token: $_fcmToken');
      await _saveTokenToFirestore(_fcmToken);
      messaging.onTokenRefresh.listen(_saveTokenToFirestore);
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null || !FirebaseService.isReady) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmUpdatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Saving FCM token failed: $e');
    }
  }

  /// Call after sign-in so the token is linked to the user.
  Future<void> syncTokenForSignedInUser() async {
    if (!FirebaseService.isReady) return;
    try {
      _fcmToken ??= await FirebaseMessaging.instance.getToken();
      await _saveTokenToFirestore(_fcmToken);
    } catch (_) {}
  }

  Future<void> showBudgetExceeded({
    required String currency,
    required double spent,
    required double budget,
  }) async {
    final over = spent - budget;
    final spentText = '$currency${spent.toStringAsFixed(2)}';
    final budgetText = '$currency${budget.toStringAsFixed(2)}';
    final overText = '$currency${over.toStringAsFixed(2)}';

    await _show(
      id: _budgetNotificationId,
      title: 'Budget exceeded',
      body:
          'You’ve spent $spentText this month (budget $budgetText). Over by $overText.',
      payload: jsonEncode({'type': 'budget_exceeded'}),
    );
  }

  Future<void> showSimple({
    required String title,
    required String body,
    int id = 2000,
  }) async {
    await _show(id: id, title: title, body: body);
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Alerts when you go over your monthly budget',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _local.show(id, title, body, details, payload: payload);
  }

  void _showRemoteMessage(RemoteMessage message) {
    final title = message.notification?.title ??
        message.data['title'] ??
        'SpendWise';
    final body = message.notification?.body ??
        message.data['body'] ??
        '';
    _show(
      id: message.hashCode,
      title: title,
      body: body,
      payload: jsonEncode(message.data),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }
}

/// Must be a top-level function for FCM background isolates.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background/terminated: system may display notification payload automatically.
  debugPrint('FCM background: ${message.messageId}');
}
