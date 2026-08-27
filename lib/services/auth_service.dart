import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../repositories/user_repository.dart';

import 'push_notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _users = UserRepository();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Self-heal: make sure this Firebase user has a matching Supabase
  /// `profiles` row, creating one if it's missing. Safe to call for any
  /// signed-in user, any number of times (idempotent upsert). Used both
  /// right after a fresh login and from the app's root auth listener, so
  /// it also covers sessions that were already persisted on the device
  /// and never went through login() again.
  Future<void> ensureProfileSynced(User user) async {
    try {
      final existing = await _users.getUser(user.uid);
      debugPrint('>>> [AuthService.ensureProfileSynced] Existing profile for UID ${user.uid}: role=${existing?.role}');

      final userUuid = UuidUtils.firebaseUidToUuid(user.uid);

      if (existing != null) {
        // Keep the Firebase UID linked to the canonical Supabase profile UUID.
        try {
          await SupabaseConfig.client.from('profiles').update({
            'firebase_uid': user.uid,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', userUuid);
        } catch (e) {
          debugPrint('>>> [AuthService.ensureProfileSynced] Firebase UID profile link note: $e');
        }

        // Sync FCM push token for existing session
        PushNotificationService().syncTokenForUser(user.uid);
        return;
      }

      // No profile row found — create a minimal one now so the app has
      // data to read instead of silently falling back to defaults forever.
      debugPrint('>>> [AuthService.ensureProfileSynced] No profile row found — creating one now for UID ${user.uid}');
      final profileData = {
        'id': userUuid,
        'firebase_uid': user.uid,
        'uid': user.uid,
        'full_name': (user.displayName != null && user.displayName!.trim().isNotEmpty)
            ? user.displayName!.trim()
            : (user.email?.split('@').first ?? 'FindiPro User'),
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'avatar_url': user.photoURL,
        'role': 'customer',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      try {
        await SupabaseConfig.client.from('profiles').upsert(profileData).select();
        debugPrint('>>> [AuthService.ensureProfileSynced] Self-heal profile upsert SUCCESS');
      } on PostgrestException catch (e) {
        debugPrint('>>> [AuthService.ensureProfileSynced] Self-heal PostgrestException: code=${e.code}, message=${e.message}');
      } catch (e) {
        debugPrint('>>> [AuthService.ensureProfileSynced] Self-heal general error: $e');
      }

      // Sync FCM push token for new profile
      PushNotificationService().syncTokenForUser(user.uid);
    } catch (e) {
      debugPrint('>>> [AuthService.ensureProfileSynced] Profile check note: $e');
    }
  }

  Future<UserCredential> login({required String email, required String password}) async {
    debugPrint('>>> [AuthService.login] Firebase signIn attempt: $email');
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    debugPrint('>>> [AuthService.login] Firebase auth SUCCESS! User UID: ${user?.uid}');

    if (user != null) {
      await ensureProfileSynced(user);
      await PushNotificationService().syncTokenForUser(user.uid);
    }

    return credential;
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'customer',
  }) async {
    final normalizedRole = (role == 'provider' || role == 'technician') ? 'provider' : 'customer';
    debugPrint('>>> [AuthService.register] Creating Firebase account: email=$email, role=$normalizedRole');
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    debugPrint('>>> [AuthService.register] Firebase account created SUCCESS. UID: ${user.uid}');
    try {
      await user.updateDisplayName(name.trim());
    } catch (_) {}

    final userUuid = UuidUtils.firebaseUidToUuid(user.uid);

    final profileData = {
      'id': userUuid,
      'firebase_uid': user.uid,
      'full_name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'avatar_url': null,
      'role': normalizedRole,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    debugPrint('>>> [AuthService.register] Supabase initial profile payload: $profileData');

    try {
      final res = await SupabaseConfig.client.from('profiles').upsert(profileData).select();
      debugPrint('>>> [AuthService.register] Supabase profiles initial upsert SUCCESS: $res');
    } on PostgrestException catch (e) {
      debugPrint('>>> [AuthService.register] PostgrestException: code=${e.code}, message=${e.message}');
    } catch (e) {
      debugPrint('>>> [AuthService.register] General error in initial profiles sync: $e');
    }

    await PushNotificationService().syncTokenForUser(user.uid);

    return credential;
  }

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> logout() async {
    debugPrint('>>> [AuthService.logout] Logging out user');
    final currentUserId = _auth.currentUser?.uid;
    try {
      await PushNotificationService().deactivateToken(userId: currentUserId);
    } catch (e) {
      debugPrint('>>> [AuthService.logout] Token deactivation note: $e');
    }
    try {
      await SupabaseConfig.client.auth.signOut();
    } catch (e) {
      debugPrint('>>> [AuthService.logout] Supabase signOut note: $e');
    }
    await _auth.signOut();
    debugPrint('>>> [AuthService.logout] Logout complete');
  }

  /// Safely deletes/deactivates the user's account and signs out.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    debugPrint('>>> [AuthService.deleteAccount] Starting account deletion for user: ${user?.uid}');

    if (user != null) {
      final uid = user.uid;

      // 1. Deactivate backend profile data in Supabase
      try {
        await _users.deactivateOrDeleteAccount(uid);
      } catch (e) {
        debugPrint('>>> [AuthService.deleteAccount] Backend deactivation note: $e');
      }

      // 2. Delete Firebase Auth user record
      try {
        await user.delete();
        debugPrint('>>> [AuthService.deleteAccount] Firebase user.delete SUCCESS');
      } catch (e) {
        debugPrint('>>> [AuthService.deleteAccount] Firebase user.delete note: $e');
      }
    }

    // 3. Complete sign out to ensure all state is cleared
    await logout();
  }
}