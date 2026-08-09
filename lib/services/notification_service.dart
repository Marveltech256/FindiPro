import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:findipro/repositories/user_repository.dart';
import 'package:flutter/foundation.dart';

/// A top-level function to handle background messages, as required by Firebase.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // For this phase, we'll just log that a message was received.
  // In a full implementation, you might initialize Firebase here to process data.
  debugPrint("Handling a background message: ${message.messageId}");
}

/// A service to manage all Firebase Cloud Messaging (FCM) functionality.
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _isInitialized = false;

  /// Initializes notification permissions, token handling, and message listeners.
  /// This should be called once after a user is authenticated.
  Future<void> initNotifications(String uid, UserRepository userRepository) async {
    if (_isInitialized) return;

    // Request permission from the user (for iOS and web).
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');

      // Get the initial FCM token for this device.
      final fcmToken = await _fcm.getToken();
      if (fcmToken != null) {
        // Save the token to the user's document in Firestore.
        await userRepository.updateFcmToken(uid, fcmToken);
      }

      // Listen for any future token refreshes.
      _fcm.onTokenRefresh.listen((newToken) {
        userRepository.updateFcmToken(uid, newToken);
      });

      // Set up the background message handler.
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle messages that arrive while the app is in the foreground.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          // Here you could display an in-app notification banner.
        }
      });

      // Handle a notification tap when the app is in the background.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
        // Here you can navigate to a specific screen based on message data.
      });

      // Handle a notification tap that opens the app from a terminated state.
      _fcm.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('App opened from terminated state by a notification!');
          // Here you can navigate to a specific screen based on message data.
        }
      });

      _isInitialized = true;
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }
}