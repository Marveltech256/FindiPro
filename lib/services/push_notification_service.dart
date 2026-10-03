import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
import '../screens/quotation/quotation_detail_screen.dart';
import '../screens/quotation/quotations_list_screen.dart';

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

  final title = message.notification?.title ?? message.data['title']?.toString() ?? 'FindiPro Notification';
  final body = message.notification?.body ?? message.data['body']?.toString() ?? 'You have a new update';

  debugPrint('>>> [FCM Background] Message received: ID=${message.messageId}, Type=${message.data['type']}, Title=$title');

  // If the payload did not include a system notification block, display a high-priority local notification banner
  if (message.notification == null) {
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important FindiPro notifications.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        showWhen: true,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('>>> [FCM Background] Local notification fallback error: $e');
    }
  }
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
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeNotifSub;
  String? _activeListeningUserId;
  final Set<String> _notifiedIds = {};

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

      // 10. Automatically sync device token and listen for real-time notifications on login/switch
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null) {
          debugPrint('>>> [PushNotificationService] Auth state changed: Logged in (${user.uid})');
          await syncTokenForUser(user.uid);
          startRealtimeNotificationListener(user.uid);
        } else {
          debugPrint('>>> [PushNotificationService] Auth state changed: Logged out');
          stopRealtimeNotificationListener();
        }
      });

      _isInitialized = true;
      debugPrint('>>> [PushNotificationService] Initialization SUCCESS');
    } catch (e) {
      debugPrint('>>> [PushNotificationService] Initialization error (non-fatal): $e');
    }
  }

  /// Sets up Android notification channels and local notification settings.
  Future<void> _initializeLocalNotifications() async {
    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('>>> [PushNotificationService] Timezone init note: $e');
    }

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

  /// Starts a real-time notification stream for the active user.
  void startRealtimeNotificationListener(String userId) {
    if (userId.trim().isEmpty) return;
    if (_activeListeningUserId == userId && _realtimeNotifSub != null) return;

    _realtimeNotifSub?.cancel();
    _activeListeningUserId = userId;
    final userUuid = UuidUtils.firebaseUidToUuid(userId);
    final listenerStartedAt = DateTime.now().toUtc();
    bool isFirstEmission = true;

    debugPrint('>>> [PushNotificationService] Starting Realtime notification listener for $userId ($userUuid)');

    try {
      _realtimeNotifSub = SupabaseConfig.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userUuid)
          .order('created_at', ascending: false)
          .limit(10)
          .listen((List<Map<String, dynamic>> rows) {
            if (isFirstEmission) {
              isFirstEmission = false;
              for (final row in rows) {
                final id = row['id']?.toString();
                if (id != null) _notifiedIds.add(id);
              }
              debugPrint('>>> [PushNotificationService] Seeded ${rows.length} existing notifications without alerting.');
              return;
            }

            for (final row in rows) {
              final id = row['id']?.toString();
              final isRead = row['is_read'] == true;
              final createdAtRaw = row['created_at']?.toString();
              DateTime? createdAt;
              if (createdAtRaw != null) {
                createdAt = DateTime.tryParse(createdAtRaw);
              }

              if (id != null && !_notifiedIds.contains(id) && !isRead) {
                _notifiedIds.add(id);

                // Skip historical notifications created before this session
                if (createdAt != null && createdAt.isBefore(listenerStartedAt)) {
                  continue;
                }

                final title = (row['title'] ?? 'FindiPro Notification').toString();
                final body = (row['body'] ?? 'You have a new update').toString();
                final data = row['data'] is Map<String, dynamic>
                    ? Map<String, dynamic>.from(row['data'] as Map)
                    : <String, dynamic>{
                        'type': row['type']?.toString() ?? 'general',
                        'title': title,
                        'body': body,
                      };

                // Show high-priority local notification banner with sound & vibration
                showLocalBanner(
                  id: id.hashCode,
                  title: title,
                  body: body,
                  payload: data,
                );
              }
            }
          }, onError: (e) {
            debugPrint('>>> [PushNotificationService] Realtime notification listener error: $e');
          });
    } catch (e) {
      debugPrint('>>> [PushNotificationService] Realtime stream note: $e');
    }
  }

  /// Stops the active real-time notification listener.
  void stopRealtimeNotificationListener() {
    _realtimeNotifSub?.cancel();
    _realtimeNotifSub = null;
    _activeListeningUserId = null;
    debugPrint('>>> [PushNotificationService] Realtime notification listener stopped.');
  }

  /// Public helper to trigger a local push notification banner.
  Future<void> showLocalBanner({
    required int id,
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      showWhen: true,
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

    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('>>> [PushNotificationService] Error showing local banner: $e');
    }
  }

  /// Schedules a future local notification (e.g. 24-hour service reminder).
  Future<void> scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final scheduledDate = tz.TZDateTime.now(tz.local).add(delay);

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

      await _localNotifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        payload: jsonEncode(payload),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('>>> [PushNotificationService] Scheduled local notification ($id) for $scheduledDate');
    } catch (e) {
      debugPrint('>>> [PushNotificationService] Error scheduling local notification: $e');
    }
  }

  /// Cancels a scheduled local notification by ID.
  Future<void> cancelLocalNotification(int id) async {
    try {
      await _localNotifications.cancel(id: id);
      debugPrint('>>> [PushNotificationService] Cancelled local notification ($id)');
    } catch (e) {
      debugPrint('>>> [PushNotificationService] Error cancelling local notification: $e');
    }
  }

  /// Saves or updates the FCM device token in Supabase `public.user_device_tokens`.
  Future<void> syncTokenForUser(String userId, {String? tokenOverride}) async {
    if (userId.trim().isEmpty) return;

    // Start real-time notification listener for active user
    startRealtimeNotificationListener(userId);

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
    } catch (e) {
      debugPrint('>>> [PushNotificationService.syncTokenForUser] Upsert note ($e), attempting resilient fallback...');
      try {
        final existing = await SupabaseConfig.client
            .from('user_device_tokens')
            .select('id')
            .eq('user_id', userUuid)
            .eq('fcm_token', token.trim())
            .maybeSingle();

        if (existing != null) {
          await SupabaseConfig.client
              .from('user_device_tokens')
              .update({'is_active': true, 'updated_at': nowIso})
              .eq('id', existing['id']);
        } else {
          await SupabaseConfig.client
              .from('user_device_tokens')
              .insert(deviceTokenPayload);
        }
        debugPrint('>>> [PushNotificationService.syncTokenForUser] Resilient device token synced SUCCESS');
      } catch (innerError) {
        debugPrint('>>> [PushNotificationService.syncTokenForUser] Resilient sync note: $innerError');
      }
    }

    // Also update profiles.fcm_token for legacy schema compatibility
    try {
      await SupabaseConfig.client
          .from('profiles')
          .update({'fcm_token': token.trim(), 'updated_at': nowIso})
          .eq('id', userUuid);
    } catch (_) {}
  }

  /// Deactivates the current device's FCM token upon logout.
  Future<void> deactivateToken({String? userId}) async {
    stopRealtimeNotificationListener();

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

        case 'quotation_request':
        case 'quotation_received':
        case 'quotation_accepted':
        case 'quotation_rejected':
        case 'quotation':
          final quotationId = (data['quotation_id'] ?? data['quotationId'] ?? '').toString();
          if (quotationId.isNotEmpty) {
            navState.push(
              MaterialPageRoute(
                builder: (_) => QuotationDetailScreen(quotationId: quotationId),
              ),
            );
          } else {
            navState.push(
              MaterialPageRoute(builder: (_) => const QuotationsListScreen()),
            );
          }
          break;

        case 'hire_request':
        case 'hire_accepted':
        case 'hire_declined':
        case 'hire_rejected':
        case 'hire_cancelled':
        case 'job_started':
        case 'job_completed':
        case 'job_cancelled':
          navState.push(
            MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
          );
          break;

        case 'review':
          await _routeToReview(data, navState);
          break;

        case 'payment':
        case 'payment_success':
        case 'payment_failed':
        case 'payment_refunded':
        case 'subscription':
          navState.push(
            MaterialPageRoute(builder: (_) => const ProviderPlanScreen()),
          );
          break;

        case 'service_reminder':
          final providerId = (data['provider_id'] ?? data['providerId'] ?? '').toString();
          if (providerId.isNotEmpty) {
            try {
              final provider = await _userRepo.getUser(providerId);
              if (provider != null) {
                navState.push(
                  MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: provider)),
                );
                break;
              }
            } catch (_) {}
          }
          navState.push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
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

  /// Triggers push notification(s) to all active FCM tokens for a recipient user.
  ///
  /// Supports notification types: 'message', 'hire_request', 'hire_accepted',
  /// 'hire_rejected', 'hire_cancelled', 'job_started', 'job_completed', 'job_cancelled', 'review', etc.
  ///
  /// Safe and resilient: never throws or disrupts the calling flow.
  Future<void> sendPushNotificationToUser({
    required String recipientUserId,
    required String senderUserId,
    String? senderName,
    String? messageText,
    String? title,
    String? body,
    String type = 'message',
    String? conversationId,
    String? messageId,
    String? bookingId,
    String? jobId,
    String? requestId,
    Map<String, dynamic>? extraData,
  }) async {
    if (recipientUserId.trim().isEmpty) return;

    final senderUuid = UuidUtils.firebaseUidToUuid(senderUserId);
    final recipientUuid = UuidUtils.firebaseUidToUuid(recipientUserId);

    // Rule 8: Do not send a push notification back to the sender
    if (senderUuid == recipientUuid ||
        senderUserId == recipientUserId ||
        senderUuid == recipientUserId ||
        senderUserId == recipientUuid) {
      debugPrint('>>> [PushNotificationService.sendPushNotificationToUser] Skipping self-notification.');
      return;
    }

    try {
      // Rule 3: Look up User B's active FCM device tokens from public.user_device_tokens
      final rows = await SupabaseConfig.client
          .from('user_device_tokens')
          .select('id, fcm_token, platform')
          .or('user_id.eq.$recipientUuid,user_id.eq.$recipientUserId')
          .eq('is_active', true);

      final List<Map<String, dynamic>> tokenRecords = List<Map<String, dynamic>>.from(rows);

      if (tokenRecords.isEmpty) {
        debugPrint('>>> [PushNotificationService.sendPushNotificationToUser] No active tokens in user_device_tokens. Checking profiles fallback...');
        try {
          final profileRow = await SupabaseConfig.client
              .from('profiles')
              .select('fcm_token')
              .or('id.eq.$recipientUuid,id.eq.$recipientUserId')
              .maybeSingle();

          final profToken = profileRow?['fcm_token']?.toString();
          if (profToken != null && profToken.trim().isNotEmpty) {
            tokenRecords.add({
              'fcm_token': profToken.trim(),
              'platform': 'android',
            });
            debugPrint('>>> [PushNotificationService.sendPushNotificationToUser] Resolved fallback token from profiles: $profToken');
          }
        } catch (e) {
          debugPrint('>>> [PushNotificationService.sendPushNotificationToUser] Profiles fallback note: $e');
        }
      }

      if (tokenRecords.isEmpty) {
        debugPrint('>>> [PushNotificationService.sendPushNotificationToUser] No active tokens found for recipient: $recipientUuid');
        return;
      }

      // Title & Body resolution
      final notificationTitle = (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : (senderName != null && senderName.trim().isNotEmpty ? senderName.trim() : 'FindiPro Notification');

      final notificationBody = (body != null && body.trim().isNotEmpty)
          ? body.trim()
          : (messageText != null ? messageText.trim() : 'You have a new update');

      final effectiveConversationId = (conversationId != null && conversationId.isNotEmpty)
          ? conversationId
          : (type == 'message' ? '${senderUuid}_$recipientUuid' : null);

      final Map<String, dynamic> dataPayload = {
        'type': type,
        'sender_id': senderUserId,
        'recipient_id': recipientUserId,
        if (effectiveConversationId != null) 'conversation_id': effectiveConversationId,
        if (messageId != null && messageId.isNotEmpty) 'message_id': messageId,
        if (requestId != null && requestId.isNotEmpty) 'request_id': requestId,
        if (bookingId != null && bookingId.isNotEmpty) 'booking_id': bookingId,
        if (jobId != null && jobId.isNotEmpty) 'job_id': jobId,
        'title': notificationTitle,
        'body': notificationBody,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        if (extraData != null) ...extraData,
      };

      debugPrint('>>> [PushNotificationService.sendPushNotificationToUser] Dispatching [$type] to ${tokenRecords.length} active token(s) for user $recipientUuid');

      // Rule 9: If recipient has multiple devices, send to all active tokens
      for (final record in tokenRecords) {
        final token = record['fcm_token']?.toString();
        final tokenId = record['id']?.toString();

        if (token == null || token.trim().isEmpty) continue;

        // Skip current device if it belongs to the sender
        if (token == _currentFcmToken) continue;

        try {
          await _sendFcmPayload(
            targetToken: token.trim(),
            title: notificationTitle,
            body: notificationBody,
            data: dataPayload,
            onInvalidToken: () async {
              // Rule 10: Deactivate invalid/expired token without breaking message sending
              if (tokenId != null && tokenId.isNotEmpty) {
                try {
                  await SupabaseConfig.client
                      .from('user_device_tokens')
                      .update({
                        'is_active': false,
                        'updated_at': DateTime.now().toUtc().toIso8601String(),
                      })
                      .eq('id', tokenId);
                  debugPrint('>>> [PushNotificationService] Deactivated expired/invalid token: $tokenId');
                } catch (e) {
                  debugPrint('>>> [PushNotificationService] Note deactivating token: $e');
                }
              }
            },
          );
        } catch (e) {
          debugPrint('>>> [PushNotificationService] Error sending to token ($token): $e');
        }
      }
    } catch (e) {
      // Rule 11: Push notification failure MUST NEVER cause message sending to fail
      debugPrint('>>> [PushNotificationService.sendPushNotificationToUser] Note (non-fatal): $e');
    }
  }

  /// Dispatches the FCM payload to a single device token safely.
  Future<void> _sendFcmPayload({
    required String targetToken,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required Future<void> Function() onInvalidToken,
  }) async {
    try {
      final payload = {
        'token': targetToken,
        'title': title,
        'body': body,
        'channel_id': _channelId,
        'priority': 'high',
        'data': data,
      };

      debugPrint('>>> [PushNotificationService] Invoking send-push-notification edge function...');
      final edgeResponse = await SupabaseConfig.client.functions.invoke(
        'send-push-notification',
        body: payload,
      );

      debugPrint('>>> [PushNotificationService] Edge function status: ${edgeResponse.status}, data: ${edgeResponse.data}');

      if (edgeResponse.status == 200) {
        debugPrint('>>> [PushNotificationService] Push dispatched via Supabase function SUCCESS');
        return;
      }

      final respData = edgeResponse.data?.toString() ?? '';
      if (respData.contains('invalid') ||
          respData.contains('not-registered') ||
          respData.contains('UNREGISTERED') ||
          respData.contains('INVALID_ARGUMENT')) {
        await onInvalidToken();
      }
    } catch (e) {
      debugPrint('>>> [PushNotificationService] _sendFcmPayload error (non-fatal): $e');
    }
  }
}