import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:findipro/models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<UserModel?> getUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }

      return UserModel.fromFirestore(
        doc.data()!,
        doc.id,
      );
    });
  }

  Future<void> updatePhoto(String uid, String url) {
    return _firestore.collection('users').doc(uid).update({
      'photoUrl': url
    });
  }
}