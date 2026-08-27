import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: <String>['email', 'profile']);

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) return null;

    final userUuid = UuidUtils.firebaseUidToUuid(user.uid);
    final supabaseProfileData = {
      'id': userUuid,
      'full_name': user.displayName ?? '',
      'email': user.email ?? '',
      'phone': user.phoneNumber ?? '',
      'avatar_url': user.photoURL,
      'role': 'customer',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    debugPrint('>>> [GoogleAuthService.signInWithGoogle] Syncing Google user to Supabase profiles: $supabaseProfileData');

    try {
      await SupabaseConfig.client.from('profiles').upsert(supabaseProfileData);
      debugPrint('>>> [GoogleAuthService.signInWithGoogle] Supabase sync SUCCESS');
    } catch (e) {
      debugPrint('>>> [GoogleAuthService.signInWithGoogle] Supabase sync error: $e');
    }

    return result;
  }

  Future<void> signOut() async {
    try {
      await SupabaseConfig.client.auth.signOut();
    } catch (_) {}
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
