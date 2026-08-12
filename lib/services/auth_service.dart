import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../repositories/user_repository.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final UserRepository _users = UserRepository();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> login({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _syncAuthUser(credential.user);
    return credential;
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'client',
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(name.trim());
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': role,
      'photoUrl': null,
      'emailVerified': user.emailVerified,
      'isBlocked': false,
      'isAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final token = await FirebaseMessaging.instance.getToken();
    await _db.collection('users').doc(user.uid).update({'fcmToken': token});

    return credential;
  }

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> logout() => _auth.signOut();

  Future<void> _syncAuthUser(User? user) async {
    if (user == null) return;
    final existing = await _users.getUser(user.uid);
    if (existing == null) {
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'role': 'client',
        'photoUrl': user.photoURL,
        'emailVerified': user.emailVerified,
        'isBlocked': false,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _db.collection('users').doc(user.uid).update({
        'email': user.email ?? existing.email,
        'emailVerified': user.emailVerified,
        if (user.photoURL != null) 'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final token = await FirebaseMessaging.instance.getToken();
      await _db.collection('users').doc(user.uid).update({'fcmToken': token});
    }
  }
}
