import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Creates and stores a notification in public.notifications in Supabase.
  ///
  /// This operation is best-effort and will not throw errors to disrupt
  /// the calling business flow (e.g. messaging, hire requests, reviews).
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    if (userId.isEmpty) return;

    final userUuid = UuidUtils.firebaseUidToUuid(userId);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final payload = {
      'user_id': userUuid,
      'title': title.trim(),
      'body': body.trim(),
      'type': type.trim(),
      if (data != null) 'data': data,
      'created_at': nowIso,
    };

    debugPrint('>>> [NotificationRepository.createNotification] Sending notification: $payload');

    try {
      await _supabase.from('notifications').insert(payload);
      debugPrint('>>> [NotificationRepository.createNotification] Notification created SUCCESS');
    } catch (e) {
      debugPrint('>>> [NotificationRepository.createNotification] Notification insert note (non-fatal): $e');
    }
  }

  /// Real-time stream of notifications for the given user.
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value(<NotificationModel>[]);
    }

    final userUuid = UuidUtils.firebaseUidToUuid(userId);

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userUuid)
        .order('created_at', ascending: false)
        .map((rows) {
          final List<NotificationModel> list = [];
          for (final r in rows) {
            list.add(NotificationModel.fromMap(r));
          }
          return list;
        })
        .handleError((error) {
          debugPrint('>>> [NotificationRepository.getNotificationsStream] Stream note: $error');
          return <NotificationModel>[];
        });
  }

  /// Fetch all notifications for a user as a one-shot Future.
  Future<List<NotificationModel>> getUserNotifications(String userId) async {
    if (userId.isEmpty) return [];

    final userUuid = UuidUtils.firebaseUidToUuid(userId);

    try {
      final res = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userUuid)
          .order('created_at', ascending: false);

      final List<NotificationModel> list = [];
      for (final r in res) {
        list.add(NotificationModel.fromMap(r));
      }
      return list;
    } catch (e) {
      debugPrint('>>> [NotificationRepository.getUserNotifications] Error: $e');
      return [];
    }
  }

  /// Stream unread notification count for the given user.
  Stream<int> getUnreadCountStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value(0);
    }

    return getNotificationsStream(userId).map((list) {
      return list.where((n) => !n.isRead).length;
    });
  }

  /// Mark a single notification as read by setting read_at.
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await _supabase
          .from('notifications')
          .update({'read_at': nowIso})
          .eq('id', notificationId);
      debugPrint('>>> [NotificationRepository.markAsRead] Marked $notificationId as read');
    } catch (e) {
      debugPrint('>>> [NotificationRepository.markAsRead] Error: $e');
    }
  }

  /// Mark all unread notifications for a user as read.
  Future<void> markAllAsRead(String userId) async {
    if (userId.isEmpty) return;

    final userUuid = UuidUtils.firebaseUidToUuid(userId);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      await _supabase
          .from('notifications')
          .update({'read_at': nowIso})
          .eq('user_id', userUuid)
          .isFilter('read_at', null);
      debugPrint('>>> [NotificationRepository.markAllAsRead] Marked all unread as read for $userUuid');
    } catch (e) {
      debugPrint('>>> [NotificationRepository.markAllAsRead] Error: $e');
    }
  }
}

