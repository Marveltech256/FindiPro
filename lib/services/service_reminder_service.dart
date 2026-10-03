import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/notification_repository.dart';
import 'push_notification_service.dart';

class ServiceReminderService {
  static final ServiceReminderService _instance = ServiceReminderService._internal();
  factory ServiceReminderService() => _instance;
  ServiceReminderService._internal();

  static const String _keyViewedProviderId = 'findipro_reminder_provider_id';
  static const String _keyViewedProviderName = 'findipro_reminder_provider_name';
  static const String _keyViewedCategory = 'findipro_reminder_category';
  static const String _keyViewedServiceName = 'findipro_reminder_service_name';
  static const String _keyViewedTimestamp = 'findipro_reminder_timestamp';
  static const String _keyBooked = 'findipro_reminder_booked';
  static const String _keyNotified = 'findipro_reminder_notified';
  static const String _keyScheduledProviderId = 'findipro_reminder_scheduled_provider_id';

  static const int reminderNotificationId = 99901;

  /// Records when a user views a service or provider and schedules a 24-hour reminder.
  /// Guarantees that the reminder is scheduled once and not repeatedly duplicated.
  Future<void> recordServiceViewed({
    required String providerId,
    required String providerName,
    required String category,
    String? serviceName,
  }) async {
    if (providerId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastScheduledId = prefs.getString(_keyScheduledProviderId);
      final isNotified = prefs.getBool(_keyNotified) ?? false;
      final isBooked = prefs.getBool(_keyBooked) ?? false;
      final lastTimestamp = prefs.getInt(_keyViewedTimestamp) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // If already scheduled for this provider within the last 12 hours and not yet handled, avoid duplicate rescheduling
      if (lastScheduledId == providerId && !isNotified && !isBooked && (nowMs - lastTimestamp < 43200000)) {
        debugPrint('>>> [ServiceReminderService] Reminder already active for $providerName ($providerId). Skipping duplicate schedule.');
        return;
      }

      await prefs.setString(_keyViewedProviderId, providerId);
      await prefs.setString(_keyScheduledProviderId, providerId);
      await prefs.setString(_keyViewedProviderName, providerName);
      await prefs.setString(_keyViewedCategory, category);
      if (serviceName != null && serviceName.isNotEmpty) {
        await prefs.setString(_keyViewedServiceName, serviceName);
      }
      await prefs.setInt(_keyViewedTimestamp, nowMs);
      await prefs.setBool(_keyBooked, false);
      await prefs.setBool(_keyNotified, false);

      final reminderTitle = category.isNotEmpty
          ? 'Still need help with $category?'
          : 'Still looking for service help?';
      final reminderBody = providerName.isNotEmpty
          ? 'You recently checked out $providerName on FindiPro. Tap to pick up where you left off!'
          : 'You recently viewed services on FindiPro. Tap to find available professionals!';

      final payload = {
        'type': 'service_reminder',
        'provider_id': providerId,
        'category': category,
        'service_name': serviceName ?? '',
      };

      // Schedule 24-hour offline-capable local reminder notification (wakes device up even when app is closed)
      await PushNotificationService().scheduleLocalNotification(
        id: reminderNotificationId,
        title: reminderTitle,
        body: reminderBody,
        delay: const Duration(hours: 24),
        payload: payload,
      );

      debugPrint('>>> [ServiceReminderService] Recorded view for $providerName ($category) & scheduled 24h reminder.');
    } catch (e) {
      debugPrint('>>> [ServiceReminderService] recordServiceViewed note: $e');
    }
  }

  /// Cancels pending reminder if the user proceeds to book or hire.
  Future<void> recordServiceBooked({required String providerId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastProviderId = prefs.getString(_keyViewedProviderId);
      if (lastProviderId == providerId || providerId.isEmpty) {
        await prefs.setBool(_keyBooked, true);
        await prefs.setBool(_keyNotified, true);
        await PushNotificationService().cancelLocalNotification(reminderNotificationId);
        debugPrint('>>> [ServiceReminderService] Service booked. Cancelled 24h reminder.');
      }
    } catch (e) {
      debugPrint('>>> [ServiceReminderService] recordServiceBooked note: $e');
    }
  }

  /// Checks if 24 hours have elapsed without booking on app startup/resume.
  /// Guarantees that the reminder is fired AT MOST ONCE and NEVER on subsequent opens.
  Future<void> checkPendingRemindersOnAppResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_keyViewedTimestamp);
      if (timestamp == null) return;

      final isBooked = prefs.getBool(_keyBooked) ?? false;
      final isNotified = prefs.getBool(_keyNotified) ?? false;
      if (isBooked || isNotified) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - timestamp;
      // 24 hours = 24 * 60 * 60 * 1000 = 86400000 ms
      if (diff >= 86400000) {
        // Mark as notified FIRST to prevent race conditions or duplicate triggers
        await prefs.setBool(_keyNotified, true);

        final category = prefs.getString(_keyViewedCategory) ?? '';
        final providerName = prefs.getString(_keyViewedProviderName) ?? '';
        final providerId = prefs.getString(_keyViewedProviderId) ?? '';

        final reminderTitle = category.isNotEmpty
            ? 'Still need help with $category?'
            : 'Still looking for service help?';
        final reminderBody = providerName.isNotEmpty
            ? 'You recently viewed $providerName on FindiPro. Tap to pick up where you left off!'
            : 'You recently viewed services on FindiPro. Tap to find available professionals!';

        final payload = {
          'type': 'service_reminder',
          'provider_id': providerId,
          'category': category,
        };

        await PushNotificationService().showLocalBanner(
          id: reminderNotificationId,
          title: reminderTitle,
          body: reminderBody,
          payload: payload,
        );

        // Also record in user's in-app notification center if logged in
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          try {
            await NotificationRepository().createNotification(
              userId: currentUser.uid,
              title: reminderTitle,
              body: reminderBody,
              type: 'service_reminder',
              data: payload,
            );
          } catch (_) {}
        }

        debugPrint('>>> [ServiceReminderService] 24h elapsed: Triggered reminder banner (once).');
      }
    } catch (e) {
      debugPrint('>>> [ServiceReminderService] checkPendingReminders note: $e');
    }
  }
}
