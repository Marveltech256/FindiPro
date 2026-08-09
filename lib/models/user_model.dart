import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? photoUrl;
  final double? latitude;
  final double? longitude;

  // Authentication
  final bool emailVerified;

  // Provider-specific fields
  final String? category;
  final String? location;
  final bool isApproved;
  final String? about;
  final List<String>? skills;
  final int? yearsExperience;
  final bool? available;
  final double? rating;
  final int? reviewCount;

  // Common moderation field
  final bool isBlocked;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.photoUrl,
    this.latitude,
    this.longitude,
    this.emailVerified = false,
    this.category,
    this.location,
    this.isApproved = false,
    this.about,
    this.skills,
    this.yearsExperience,
    this.available,
    this.rating,
    this.reviewCount,
    this.isBlocked = false,
  });

  /// Create from a plain Map
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'client',
      photoUrl: map['photoUrl'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      emailVerified: map['emailVerified'] ?? false,
      category: map['category'],
      location: map['location'],
      isApproved: map['isApproved'] ?? false,
      about: map['about'],
      skills: map['skills'] != null ? List<String>.from(map['skills']) : null,
      yearsExperience: map['yearsExperience'],
      available: map['available'],
      rating: (map['rating'] as num?)?.toDouble(),
      reviewCount: map['reviewCount'],
      isBlocked: map['isBlocked'] ?? false,
    );
  }

  /// Create directly from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'photoUrl': photoUrl,
      'emailVerified': emailVerified,
      'category': category,
      'location': location,
      'isApproved': isApproved,
      'isBlocked': isBlocked,
    };
  }
}