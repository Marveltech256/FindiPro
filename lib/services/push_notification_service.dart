import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../screens/chat_screen.dart';
import '../screens/my_requests_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/provider/provider_detail_screen.dart';
import '../screens/provider/provider_plan_screen.dart';

/// Top-level background message handler for FCM.
///
/// Must be a top-level function with `@pragma('vm:entry-point')`
/// to be invoked by the Flutter engine when the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    debugPrint('>>> [FCM Background] Firebase initialization note: $e');
  }

  debugPrint('>>> [FCM Background] Message received: ID=${message.messageId}, Type=${message.data['type']}, Title=${message.notification?.title ?? message.data['title']}');
}

/// Centralized push notification service using Firebase Cloud Messaging (FCM)
/// and Flutter Local Notifications.
class PushNotificationService {
  // Singleton pattern
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final UserRepository _userRepo = UserRepository();

  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDescription = 'This channel is used for important FindiPro notifications.';

  /// Global navigator key for notification tap routing.
  static GlobalKey<NavigatorState>? navigatorKey;

  bool _isInitialized = false;
  String? _currentFcmToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;

  String? get currentFcmToken => _currentFcmToken;

  /// Initializes Firebase Messaging, Android channels, local notifications,
  /// permission requests, and foreground/background/tap listeners.
  Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_isInitialized) {
      debugPrint('>>> [PushNotificationService] Already initialized. Skipping duplicate init.');
      if (navKey != null) navigatorKey = navKey;
      return;
    }

    if (navKey != null) {
      navigatorKey = navKey;
    }

    debugPrint('>>> [PushNotificationService] Starting initialization...');

    try {
      // 1. Register top-level background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2. Initialize Flutter Local Notifications & Android channel
      await _initializeLocalNotifications();

      // 3. Request Notification Permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('>>> [PushNotificationService] Permission status: ${settings.authorizationStatus}');

      // 4. Set foreground notification presentation options
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Fetch initial FCM device token
      try {
        _currentFcmToken = await _messaging.getToken();
        debugPrint('>>> [PushNotificationService] FCM Token obtained: $_currentFcmToken');

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && _currentFcmToken != null) {
          await syncTokenForUser(currentUser.uid);
        }
      } catch (e) {
        debugPrint('>>> [PushNotificationService] getToken note (non-fatal): $e');
      }

      // 6. Listen for token refresh events
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('>>> [PushNotificationService] FCM Token refreshed: $newToken');
        _currentFcmToken = newToken;
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await syncTokenForUser(currentUser.uid, tokenOverride: newToken);
        }
      }, onError: (e) {
        debugPrint('>>> [PushNotificationService] onTokenRefresh error: $e');
      });

      // 7. Listen for foreground notifications
      _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('>>> [PushNotificationService] Foreground message received: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // 8. Listen for notification tap when app is in background
      _onMessageOpenedAppSub?.cancel();
      _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('>>> [PushNotificationService] Notification opened from background: ${message.messageId}');
        handleNotificationPayload(message.data);
      });

      // 9. Check if app was launched from a terminated state notification tap
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('>>> [PushNotificationService] App launched from terminated state notification: ${initialMessage.messageId}');
        // Allow the UI to finish building before routing
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationPayload(initialMessage.data);
        });
      }

      _isInitialized = true;
      debugPrint('>>> [PushNotificationService] Initialization SUCCESS');
    } catch (e) {
      debugPrint('>>> [PushNotificationService] Initialization error (non-fatal): $e');
    }
  }

  /// Sets up Android notification channels and local notification settings.
  Future<void> _initializeLocalNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
      await androidPlugin.requestNotificationsPermission();
    }

    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('>>> [PushNotificationService] Local notification response tapped: ${response.payload}');
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> data = Map<String, dynamic>.from(
              jsonDecode(response.payload!),
            );
            handleNotificationPayload(data);
          } catch (e) {
            debugPrint('>>> [PushNotificationService] Error parsing notification payload: $e');
          }
        }
      },
    );
  }

  /// Displays an in-app local notification when a message is received in the foreground.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title']?.toString() ?? 'FindiPro Notification';
    final body = notification?.body ?? data['body']?.toString() ?? 'You have a new update';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final payloadString = jsonEncode(data);

    try {
      await _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payloadString,
      );
    } catch (e) {
      debugPrint('>>> [PushNotificationService] Failed to show local notification: $e');
    }
  }

  /// Saves or updates the FCM device token in Supabase `public.user_device_tokens`.
  Future<void> syncTokenForUser(String userId, {String? tokenOverride}) async {
    if (userId.trim().isEmpty) return;

    final token = tokenOverride ?? _currentFcmToken ?? await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      debugPrint('>>> [PushNotificationService.syncTokenForUser] Token is null or empty. Skipping sync.');
      return;
    }

    _currentFcmToken = token;
    final userUuid = UuidUtils.firebaseUidToUuid(userId);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final deviceTokenPayload = {
      'user_id': userUuid,
      'fcm_token': token.trim(),
      'platform': defaultTargetPlatform.name,
      'device_name': defaultTargetPlatform.name,
      'is_active': true,
      'updated_at': nowIso,
    };

    debugPrint('>>> [PushNotificationService.syncTokenForUser] Upserting device token for user $userId (UUID $userUuid)');

    try {
      await SupabaseConfig.client
          .from('user_device_tokens')
          .upsert(
            deviceTokenPayload,
            onConflict: 'user_id, fcm_token',
          );
      debugPrint('>>> [PushNotificationService.syncTokenForUser] Device token synced SUCCESS');
    } on PostgrestException catch (e) {
      debugPrint('>>> [PushNotificationService.syncTokenForUser] PostgrestException (code=${e.code}): ${e.message}');
    } catch (e) {
      debugPrint('>>> [PushNotificationService.syncTokenForUser] Token sync note (non-fatal): $e');
    }
  }

  /// Deactivates the current device's FCM token upon logout.
  Future<void> deactivateToken({String? userId}) async {
    final token = _currentFcmToken ?? await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;

    debugPrint('>>> [PushNotificationService.deactivateToken] Deactivating device token...');

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      if (userId != null && userId.trim().isNotEmpty) {
        final userUuid = UuidUtils.firebaseUidToUuid(userId);
        await SupabaseConfig.client
            .from('user_device_tokens')
            .update({
              'is_active': false,
              'updated_at': nowIso,
            })
            .eq('user_id', userUuid)
            .eq('fcm_token', token.trim());
      } else {
        await SupabaseConfig.client
            .from('user_device_tokens')
            .update({
              'is_active': false,
              'updated_at': nowIso,
            })
            .eq('fcm_token', token.trim());
      }
      debugPrint('>>> [PushNotificationService.deactivateToken] Token deactivated SUCCESS');
    } catch (e) {
      debugPrint('>>> [PushNotificationService.deactivateToken] Deactivation note (non-fatal): $e');
    }
  }

  /// Handles routing when a notification (foreground, background, or terminated) is tapped.
  Future<void> handleNotificationPayload(Map<String, dynamic> data) async {
    debugPrint('>>> [PushNotificationService.handleNotificationPayload] Processing payload: $data');

    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    final navState = navigatorKey?.currentState;

    if (navState == null) {
      debugPrint('>>> [PushNotificationService] NavigatorState not available yet. Retrying in 500ms...');
      Future.delayed(const Duration(milliseconds: 500), () => handleNotificationPayload(data));
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    try {
      switch (type) {
        case 'message':
          await _routeToChat(data, navState, currentUid);
          break;

        case 'hire_request':
        case 'hire_accepted':
        case 'hire_declined':
        case 'hire_rejected':
        case 'hire_cancelled':
        case 'job_completed':
          navState.push(
            MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
          );
          break;

        case 'review':
          await _routeToReview(data, navState);
          break;

        case 'payment':
        case 'subscription':
          navState.push(
            MaterialPageRoute(builder: (_) => const ProviderPlanScreen()),
          );
          break;

        case 'general':
        default:
          navState.push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
          break;
      }
    } catch (e) {
      debugPrint('>>> [PushNotificationService] Navigation routing error: $e');
      // Graceful fallback to NotificationsScreen
      try {
        navState.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      } catch (_) {}
    }
  }

  /// Routes to the correct ChatScreen based on notification payload.
  Future<void> _routeToChat(
    Map<String, dynamic> data,
    NavigatorState navState,
    String? currentUid,
  ) async {
    if (currentUid == null) return;

    final senderId = (data['sender_id'] ?? data['senderId'] ?? '').toString();
    final recipientId = (data['recipient_id'] ?? data['recipientId'] ?? '').toString();
    final conversationId = (data['conversation_id'] ?? data['conversationId'] ?? '').toString();
    final bookingId = (data['booking_id'] ?? data['bookingId'] ?? data['job_id'] ?? data['jobId'] ?? '').toString();

    final otherUserId = (senderId.isNotEmpty && senderId != currentUid)
        ? senderId
        : (recipientId.isNotEmpty && recipientId != currentUid ? recipientId : senderId);

    if (otherUserId.isEmpty) {
      navState.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      return;
    }

    UserModel? otherUser;
    try {
      otherUser = await _userRepo.getUser(otherUserId);
    } catch (e) {
      debugPrint('>>> [PushNotificationService] Error fetching chat partner user: $e');
    }

    navState.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: currentUid,
          otherUserId: otherUserId,
          otherUserName: otherUser?.name ?? 'User',
          otherUserPhotoUrl: otherUser?.photoUrl,
          conversationId: conversationId.isNotEmpty ? conversationId : null,
          bookingId: bookingId.isNotEmpty ? bookingId : null,
        ),
      ),
    );
  }

  /// Routes to the provider detail screen or reviews for review notifications.
  Future<void> _routeToReview(
    Map<String, dynamic> data,
    NavigatorState navState,
  ) async {
    final providerId = (data['provider_id'] ?? data['providerId'] ?? '').toString();

    if (providerId.isNotEmpty) {
      UserModel? providerUser;
      try {
        providerUser = await _userRepo.getUser(providerId);
      } catch (_) {}

      if (providerUser != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => ProviderDetailScreen(provider: providerUser!),
          ),
        );
        return;
      }
    }

    // Default fallback for review
    navState.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }
}