import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';

class GoogleAuthData {
  final UserCredential userCredential;
  final String name;
  final String email;
  final String? photoUrl;
  final String uid;

  const GoogleAuthData({
    required this.userCredential,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.uid,
  });
}

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
    serverClientId: '456209894195-q7rp6q0t6o07f866oeqhmpevgssnv7mt.apps.googleusercontent.com',
  );

  /// Authenticates with Google and extracts user profile info (name, email, photo) for form auto-fill.
  Future<GoogleAuthData?> authenticateWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser;
      try {
        await _googleSignIn.signOut().catchError((_) => null);
        googleUser = await _googleSignIn.signIn();
      } on PlatformException catch (pe) {
        final code = pe.code.toLowerCase();
        final message = (pe.message ?? '').toLowerCase();
        if (code.contains('cancel') || message.contains('cancel') || code == '12501') {
          debugPrint('>>> [GoogleAuthService] User cancelled Google account picker.');
          return null;
        }
        debugPrint('>>> [GoogleAuthService.authenticateWithGoogle] PlatformException (${pe.code}): ${pe.message}, details: ${pe.details}');
        if (pe.message?.contains('10') == true || pe.code == '10') {
          throw Exception('Google Sign-in configuration error (code 10). Ensure SHA-1 & package com.findipro.com match Firebase: ${pe.message}');
        }
        throw Exception('Google Sign-in failed [code ${pe.code}]: ${pe.message ?? 'Unknown error'}');
      } catch (primaryError) {
        debugPrint('>>> [GoogleAuthService.authenticateWithGoogle] Primary error: $primaryError');
        throw Exception('Google Sign-in failed: $primaryError');
      }

      if (googleUser == null) {
        debugPrint('>>> [GoogleAuthService.authenticateWithGoogle] User cancelled Google sign-in.');
        return null;
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception('Could not retrieve security tokens from Google. Please try again.');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw Exception('Failed to sign into Firebase with Google credentials.');
      }

      return GoogleAuthData(
        userCredential: result,
        name: user.displayName ?? googleUser.displayName ?? '',
        email: user.email ?? googleUser.email,
        photoUrl: user.photoURL ?? googleUser.photoUrl,
        uid: user.uid,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('>>> [GoogleAuthService.authenticateWithGoogle] FirebaseAuthException (${e.code}): ${e.message}');
      if (e.code == 'operation-not-allowed') {
        throw Exception('Google Sign-In is disabled in Firebase Console. Please enable Google provider in Authentication.');
      } else if (e.code == 'account-exists-with-different-credential') {
        throw Exception('An account already exists with this email using a different sign-in method.');
      }
      throw Exception(e.message ?? 'Authentication failed with code: ${e.code}');
    } catch (e) {
      debugPrint('>>> [GoogleAuthService.authenticateWithGoogle] Exception: $e');
      rethrow;
    }
  }

  /// Synchronizes Google-authenticated user data directly to Supabase with role without prompting again.
  Future<void> syncGoogleUserData({
    required GoogleAuthData authData,
    required String selectedRole,
    String? category,
    String? phone,
    String? location,
    String? about,
    String? businessName,
  }) async {
    final user = authData.userCredential.user;
    if (user == null) return;

    final userUuid = UuidUtils.firebaseUidToUuid(user.uid);
    final isProviderUser = selectedRole == 'provider' || selectedRole == 'technician';
    final effectiveRole = isProviderUser ? 'provider' : 'customer';

    final supabaseProfileData = {
      'id': userUuid,
      'firebase_uid': user.uid,
      'full_name': authData.name.isNotEmpty ? authData.name : (isProviderUser ? 'Service Provider' : 'Client'),
      'email': authData.email,
      'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : (user.phoneNumber ?? ''),
      'avatar_url': authData.photoUrl,
      'role': effectiveRole,
      'plan': isProviderUser ? 'premium' : 'basic',
      'verified': isProviderUser,
      'is_verified': isProviderUser,
      'premium': isProviderUser,
      'is_premium': isProviderUser,
      'verification_status': isProviderUser ? 'approved' : 'none',
      'subscription_status': 'active',
      'is_online': true,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await SupabaseConfig.client.from('profiles').upsert(supabaseProfileData);
      debugPrint('>>> [GoogleAuthService.syncGoogleUserData] Profiles upsert SUCCESS (role: $effectiveRole)');
    } catch (e) {
      debugPrint('>>> [GoogleAuthService.syncGoogleUserData] Profiles upsert error: $e');
    }

    if (isProviderUser) {
      final providerData = {
        'id': userUuid,
        'user_id': userUuid,
        'firebase_uid': user.uid,
        'uid': user.uid,
        'full_name': authData.name.isNotEmpty ? authData.name : 'Service Provider',
        'business_name': businessName,
        'email': authData.email,
        'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : (user.phoneNumber ?? ''),
        'role': 'provider',
        'avatar_url': authData.photoUrl,
        'category': category ?? 'General Services',
        'location': location ?? 'Uganda',
        'about': about ?? 'Professional service provider on FindiPro.',
        'bio': about ?? 'Professional service provider on FindiPro.',
        'available': true,
        'plan': 'premium',
        'verified': true,
        'is_verified': true,
        'premium': true,
        'is_premium': true,
        'verification_status': 'approved',
        'subscription_status': 'active',
        'rating': 0,
        'review_count': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      try {
        await SupabaseConfig.client.from('providers').upsert(providerData);
        debugPrint('>>> [GoogleAuthService.syncGoogleUserData] Providers upsert SUCCESS');
      } catch (e) {
        debugPrint('>>> [GoogleAuthService.syncGoogleUserData] Providers upsert error: $e');
      }
    }
  }

  /// Handles Google Sign-Up: registers new users with their chosen role ('customer' or 'provider').
  Future<UserCredential?> signUpWithGoogle({
    required String selectedRole,
    String? category,
    String? phone,
    String? location,
    String? about,
    String? businessName,
  }) async {
    try {
      final authData = await authenticateWithGoogle();
      if (authData == null) return null;
      
      await syncGoogleUserData(
        authData: authData,
        selectedRole: selectedRole,
        category: category,
        phone: phone,
        location: location,
        about: about,
        businessName: businessName,
      );

      return authData.userCredential;
    } catch (e) {
      debugPrint('>>> [GoogleAuthService.signUpWithGoogle] Exception: $e');
      rethrow;
    }
  }

  /// Handles Google Login: signs in existing users directly into their dashboard.
  Future<UserCredential?> signInWithGoogleLoginOnly() async {
    try {
      final authData = await authenticateWithGoogle();
      if (authData == null) return null;
      final user = authData.userCredential.user;
      if (user == null) return null;

      final userUuid = UuidUtils.firebaseUidToUuid(user.uid);

      // Check existing profile and provider status in Supabase
      String existingRole = 'customer';
      try {
        final existing = await SupabaseConfig.client
            .from('profiles')
            .select('role')
            .eq('id', userUuid)
            .maybeSingle();

        if (existing != null && existing['role'] != null && existing['role'].toString().isNotEmpty) {
          existingRole = existing['role'].toString();
          debugPrint('>>> [GoogleAuthService.signInWithGoogleLoginOnly] Found existing role in profiles: $existingRole');
        }

        // Also check providers table to prevent a registered provider from being downgraded
        final prov = await SupabaseConfig.client
            .from('providers')
            .select('id')
            .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.${user.uid},uid.eq.${user.uid}')
            .maybeSingle();
        if (prov != null) {
          existingRole = 'provider';
          debugPrint('>>> [GoogleAuthService.signInWithGoogleLoginOnly] Found provider record, setting role: provider');
        }
      } catch (e) {
        debugPrint('>>> [GoogleAuthService.signInWithGoogleLoginOnly] Role lookup note: $e');
      }

      // Update presence
      try {
        await SupabaseConfig.client.from('profiles').upsert({
          'id': userUuid,
          'firebase_uid': user.uid,
          'full_name': authData.name.isNotEmpty ? authData.name : 'FindiPro User',
          'email': authData.email,
          'avatar_url': authData.photoUrl,
          'role': existingRole,
          'is_online': true,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('>>> [GoogleAuthService.signInWithGoogleLoginOnly] Presence update error: $e');
      }

      return authData.userCredential;
    } catch (e) {
      debugPrint('>>> [GoogleAuthService.signInWithGoogleLoginOnly] Exception: $e');
      rethrow;
    }
  }

  /// General Google sign-in entrypoint that supports optional role assignment.
  Future<UserCredential?> signInWithGoogle({String? selectedRole}) async {
    if (selectedRole != null && selectedRole.isNotEmpty) {
      return signUpWithGoogle(selectedRole: selectedRole);
    }
    return signInWithGoogleLoginOnly();
  }

  /// Checks whether a profile exists for the given Firebase UID in Supabase.
  Future<bool> hasExistingProfile(String firebaseUid) async {
    try {
      final userUuid = UuidUtils.firebaseUidToUuid(firebaseUid);
      final existing = await SupabaseConfig.client
          .from('profiles')
          .select('role')
          .eq('id', userUuid)
          .maybeSingle();
      return existing != null && existing['role'] != null && existing['role'].toString().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateRole({required String firebaseUid, required String role}) async {
    final userUuid = UuidUtils.firebaseUidToUuid(firebaseUid);
    final normalized = (role == 'provider') ? 'provider' : 'customer';
    try {
      await SupabaseConfig.client.from('profiles').update({
        'role': normalized,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userUuid);
    } catch (e) {
      debugPrint('>>> [GoogleAuthService.updateRole] Error updating role: $e');
    }
  }
}
