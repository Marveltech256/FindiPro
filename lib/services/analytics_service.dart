import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';

/// Centralized analytics, telemetry, and platform activity monitoring service for FindiPro.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  SupabaseClient get _supabase => SupabaseConfig.client;

  final List<Map<String, dynamic>> _eventQueue = [];
  Timer? _flushTimer;
  bool _isFlushing = false;

  /// Initializes analytics batch timer
  void initialize() {
    _flushTimer?.cancel();
    // Flush event buffer every 30 seconds or when threshold reached
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => flushEvents());
    debugPrint('>>> [AnalyticsService] Initialized telemetry and event monitoring.');
  }

  /// Disposes timer resources
  void dispose() {
    _flushTimer?.cancel();
    flushEvents();
  }

  /// Logs a generic or custom analytics event
  Future<void> logEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final uid = currentUser?.uid ?? 'guest';
      final userUuid = currentUser != null ? UuidUtils.firebaseUidToUuid(currentUser.uid) : null;
      final nowIso = DateTime.now().toUtc().toIso8601String();

      final eventPayload = {
        'event_name': eventName.trim().toLowerCase(),
        'user_id': userUuid,
        'firebase_uid': uid,
        'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
        'parameters': parameters ?? <String, dynamic>{},
        'created_at': nowIso,
      };

      _eventQueue.add(eventPayload);

      // Immediate flush for critical conversion events
      if (eventName.contains('hire') || eventName.contains('payment') || _eventQueue.length >= 10) {
        await flushEvents();
      }
    } catch (e) {
      debugPrint('>>> [AnalyticsService.logEvent] Note (non-fatal): $e');
    }
  }

  /// Track a generic event (alias for logEvent)
  Future<void> trackEvent(String eventName, {Map<String, dynamic>? parameters}) async {
    await logEvent(eventName, parameters: parameters);
  }

  /// Logs screen views for journey tracking
  Future<void> logScreenView(String screenName) async {
    await logEvent('screen_view', parameters: {'screen_name': screenName});
  }

  /// Track a screen view (alias for logScreenView)
  Future<void> trackScreenView(String screenName) async {
    await logScreenView(screenName);
  }

  /// Logs search terms and category selections
  Future<void> logSearch({
    required String query,
    String? category,
    int? resultCount,
  }) async {
    await logEvent('search_performed', parameters: {
      'query': query,
      if (category != null) 'category': category,
      if (resultCount != null) 'result_count': resultCount,
    });
  }

  /// Track a search (alias for logSearch)
  Future<void> trackSearch({
    required String query,
    String? category,
    int? resultCount,
  }) async {
    await logSearch(query: query, category: category, resultCount: resultCount);
  }

  /// Logs provider profile exploration
  Future<void> logProviderView({
    required String providerId,
    String? providerName,
    String? category,
  }) async {
    await logEvent('provider_profile_viewed', parameters: {
      'provider_id': providerId,
      if (providerName != null) 'provider_name': providerName,
      if (category != null) 'category': category,
    });
  }

  /// Logs booking and hire requests
  Future<void> logHireRequest({
    required String providerId,
    required String serviceName,
    double? amount,
  }) async {
    await logEvent('hire_request_initiated', parameters: {
      'provider_id': providerId,
      'service_name': serviceName,
      if (amount != null) 'amount': amount,
    });
  }

  /// Logs chat messaging activity
  Future<void> logMessageSent({
    required String recipientId,
    required int messageLength,
    bool hasAttachment = false,
  }) async {
    await logEvent('chat_message_sent', parameters: {
      'recipient_id': recipientId,
      'char_count': messageLength,
      'has_attachment': hasAttachment,
    });
  }

  /// Flushes in-memory events to Supabase public.analytics_events
  Future<void> flushEvents() async {
    if (_isFlushing || _eventQueue.isEmpty) return;
    _isFlushing = true;

    final batch = List<Map<String, dynamic>>.from(_eventQueue);
    _eventQueue.clear();

    try {
      await _supabase.from('analytics_events').insert(batch);
      debugPrint('>>> [AnalyticsService] Flushed ${batch.length} analytics events to Supabase.');
    } catch (e) {
      debugPrint('>>> [AnalyticsService] Failed to flush events to Supabase (restoring queue): $e');
      // Re-queue events on transient network failure up to 50 max
      if (_eventQueue.length < 50) {
        _eventQueue.insertAll(0, batch);
      }
    } finally {
      _isFlushing = false;
    }
  }

  /// Fetches platform statistics summary for Admin Intelligence
  Future<Map<String, dynamic>> getPlatformMetrics() async {
    try {
      final now = DateTime.now().toUtc();
      final last24Hours = now.subtract(const Duration(hours: 24)).toIso8601String();
      final last7Days = now.subtract(const Duration(days: 7)).toIso8601String();

      final results = await Future.wait([
        _supabase.from('profiles').select('id, role').count(CountOption.exact),
        _supabase.from('providers').select('id').count(CountOption.exact),
        _supabase.from('bookings').select('id, status').count(CountOption.exact),
        _supabase.from('messages').select('id').count(CountOption.exact),
        _supabase.from('analytics_events').select('id').gte('created_at', last24Hours).count(CountOption.exact),
        _supabase.from('analytics_events').select('id').gte('created_at', last7Days).count(CountOption.exact),
      ]);

      return {
        'total_users': results[0].count,
        'total_providers': results[1].count,
        'total_bookings': results[2].count,
        'total_messages': results[3].count,
        'events_24h': results[4].count,
        'events_7d': results[5].count,
      };
    } catch (e) {
      debugPrint('>>> [AnalyticsService.getPlatformMetrics] Error: $e');
      return {
        'total_users': 0,
        'total_providers': 0,
        'total_bookings': 0,
        'total_messages': 0,
        'events_24h': 0,
        'events_7d': 0,
      };
    }
  }
}
