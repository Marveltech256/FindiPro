import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';

/// Centralized Presence Service for FindiPro.
///
/// Tracks online/offline status, updates `last_seen` timestamps in Supabase,
/// responds to app lifecycle changes (resumed/paused/detached), and streams real-time presence.
class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  SupabaseClient get _supabase => SupabaseConfig.client;
  Timer? _heartbeatTimer;
  StreamSubscription<User?>? _authSubscription;
  bool _isInitialized = false;
  String? _trackedUserId;

  /// Initializes lifecycle observation, auth listening, and periodic presence heartbeats.
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    WidgetsBinding.instance.addObserver(this);
    debugPrint('>>> [PresenceService] Initialized lifecycle observer');

    // Listen to Firebase Auth state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _trackedUserId = user.uid;
        setOnline(user.uid);
        _startHeartbeat();
      } else {
        if (_trackedUserId != null) {
          setOffline(_trackedUserId!);
        }
        _stopHeartbeat();
        _trackedUserId = null;
      }
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _trackedUserId = currentUser.uid;
      setOnline(currentUser.uid);
      _startHeartbeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('>>> [PresenceService] App lifecycle state changed: $state');
    final uid = _trackedUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    switch (state) {
      case AppLifecycleState.resumed:
        setOnline(uid);
        _startHeartbeat();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        setOffline(uid);
        _stopHeartbeat();
        break;
    }
  }

  /// Sets the user online in Supabase `profiles` table.
  Future<void> setOnline(String userId) async {
    if (userId.trim().isEmpty) return;
    final userUuid = UuidUtils.firebaseUidToUuid(userId);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      await _supabase.from('profiles').update({
        'is_online': true,
        'last_seen': nowIso,
        'updated_at': nowIso,
      }).eq('id', userUuid);
      debugPrint('>>> [PresenceService] User $userId set to ONLINE in Supabase (id=$userUuid)');
    } catch (e) {
      debugPrint('>>> [PresenceService.setOnline] Note (non-fatal): $e');
    }
  }

  /// Sets the user offline in Supabase `profiles` table with updated `last_seen`.
  Future<void> setOffline(String userId) async {
    if (userId.trim().isEmpty) return;
    final userUuid = UuidUtils.firebaseUidToUuid(userId);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      await _supabase.from('profiles').update({
        'is_online': false,
        'last_seen': nowIso,
        'updated_at': nowIso,
      }).eq('id', userUuid);
      debugPrint('>>> [PresenceService] User $userId set to OFFLINE in Supabase (id=$userUuid, last_seen: $nowIso)');
    } catch (e) {
      debugPrint('>>> [PresenceService.setOffline] Note (non-fatal): $e');
    }
  }

  /// Streams real-time presence data (`is_online` and `last_seen`) for any target user.
  Stream<Map<String, dynamic>> watchPresence(String userId) {
    if (userId.trim().isEmpty) {
      return Stream.value({'is_online': false, 'last_seen': null});
    }

    final userUuid = UuidUtils.firebaseUidToUuid(userId);

    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userUuid)
        .map((rows) {
          if (rows.isEmpty) return {'is_online': false, 'last_seen': null};
          final row = rows.first;
          return {
            'is_online': row['is_online'] == true,
            'last_seen': row['last_seen'] != null ? DateTime.tryParse(row['last_seen'].toString()) : null,
          };
        })
        .handleError((e) {
          debugPrint('>>> [PresenceService.watchPresence] Stream error: $e');
          return {'is_online': false, 'last_seen': null};
        });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Refresh presence heartbeat every 2 minutes while app is in foreground
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      final uid = _trackedUserId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        setOnline(uid);
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _authSubscription?.cancel();
    _isInitialized = false;
  }
}
