import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<UserModel?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  Stream<List<UserModel>> getProvidersStream() {
    return _db
        .collection('providers')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(UserModel.fromFirestore).toList());
  }

  Future<void> createClient({
    required String uid,
    required String name,
    required String email,
    required String phone,
    String? photoUrl,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': 'client',
      'photoUrl': photoUrl,
      'emailVerified': false,
      'isBlocked': false,
      'isAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> createProvider({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String category,
    required String location,
    required int yearsExperience,
    String? about,
    required String bio,
    required List<String> skills,
    required String priceRange,
    required bool available,
    required double? latitude,
    required double? longitude,
    String? photoUrl,
    String? businessName,
  }) async {
    final data = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': 'provider',
      'category': category,
      'location': location,
      'about': about,
      'yearsExperience': yearsExperience,
      'bio': bio,
      'skills': skills,
      'priceRange': priceRange,
      'available': available,
      'latitude': latitude,
      'images': <String>[], // Initialize images array
      'longitude': longitude,
      'photoUrl': photoUrl,
      'businessName': businessName,
      'rating': 0,
      'reviewCount': 0,
      'plan': 'basic',
      'verified': false,
      'premium': false,
      'planExpiry': null,
      'featuredUntil': null,
      'boostUntil': null,
      'verificationStatus': 'none',
      'isBlocked': false,
      'isAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('providers').doc(uid).set(data);
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': 'provider',
      'photoUrl': photoUrl,
      'category': category,
      'about': about,
      'location': location,
      'yearsExperience': yearsExperience,
      'bio': bio,
      'skills': skills,
      'priceRange': priceRange,
      'available': available,
      'latitude': latitude,
      'images': <String>[], // Initialize images array
      'longitude': longitude,
      'isBlocked': false,
      'plan': 'basic',
      'verified': false,
      'premium': false,
      'planExpiry': null,
      'featuredUntil': null,
      'boostUntil': null,
      'verificationStatus': 'none',
      'emailVerified': false,
      'isAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addPortfolioImage(String uid, String imageUrl) async {
    await _db.collection('users').doc(uid).update({
      'images': FieldValue.arrayUnion([imageUrl]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
