import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _messaging.requestPermission();

    final token = await _messaging.getToken();

    debugPrint('FCM Token: $token');

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        'Foreground message: ${message.notification?.title}',
      );
    });
  }
}