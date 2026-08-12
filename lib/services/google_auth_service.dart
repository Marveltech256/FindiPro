import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
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

    final ref = _db.collection('users').doc(user.uid);
    final existing = await ref.get();
    final data = <String, dynamic>{
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL,
      'emailVerified': user.emailVerified,
      'fcmToken': await FirebaseMessaging.instance.getToken(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      data.addAll({'role': 'client', 'phone': '', 'isBlocked': false, 'createdAt': FieldValue.serverTimestamp()});
    }
    await ref.set(data, SetOptions(merge: true));
    return result;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
