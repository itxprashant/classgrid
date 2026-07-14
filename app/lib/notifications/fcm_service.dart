import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/fcm_api.dart';
import 'class_notification_service.dart';

const broadcastTopic = 'classgrid_broadcast';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await ClassNotificationService.instance.init();
  await _displayRemoteMessage(message);
}

Future<void> _displayRemoteMessage(RemoteMessage message) async {
  final notification = message.notification;
  final title = notification?.title ?? message.data['title'];
  final body = notification?.body ?? message.data['body'];
  if (title == null || title.isEmpty) return;
  await ClassNotificationService.instance.showPushNotification(
    title: title,
    body: body ?? '',
  );
}

/// FCM broadcast notifications (admin pushes). Local class reminders stay separate.
class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  FcmApi? _fcmApi;
  String? _lastToken;
  bool _initialized = false;

  Future<void> init(ApiClient client, {required FcmApi fcmApi}) async {
    if (!Platform.isAndroid || _initialized) return;

    _fcmApi = fcmApi;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    await messaging.subscribeToTopic(broadcastTopic);

    FirebaseMessaging.onMessage.listen(_displayRemoteMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((_) {});

    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    messaging.onTokenRefresh.listen(_registerToken);

    _initialized = true;
  }

  Future<void> onAuthChanged({required bool isLoggedIn}) async {
    if (!_initialized || _fcmApi == null) return;

    if (isLoggedIn) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerToken(token);
      }
      return;
    }

    final token = _lastToken;
    if (token == null) return;
    try {
      await _fcmApi!.deleteToken(token);
    } catch (e) {
      debugPrint('[FcmService] delete token failed: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    final api = _fcmApi;
    if (api == null) return;
    _lastToken = token;
    try {
      await api.registerToken(token);
    } catch (e) {
      debugPrint('[FcmService] register token failed: $e');
    }
  }
}
