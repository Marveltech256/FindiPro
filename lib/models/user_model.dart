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
  final bool emailVerified;
  final String? category;
  final String? location;
  final bool isApproved;
  final String? about;
  final String? bio;
  final List<String> skills;
  final int yearsExperience;
  final bool available;
  final double rating;
  final int reviewCount;
  final String priceRange;
  final String? businessName;
  final List<String> images;
  final bool verified;
  final bool premium;
  final bool isBlocked;
  final bool isAdmin;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = 'client',
    this.photoUrl,
    this.latitude,
    this.longitude,
    this.emailVerified = false,
    this.category,
    this.location,
    this.isApproved = false,
    this.about,
    this.bio,
    this.skills = const [],
    this.yearsExperience = 0,
    this.available = true,
    this.rating = 0,
    this.reviewCount = 0,
    this.priceRange = '',
    this.businessName,
    this.images = const [],
    this.verified = false,
    this.premium = false,
    this.isBlocked = false,
    this.isAdmin = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      role: (map['role'] ?? 'client').toString(),
      photoUrl: _stringOrNull(map['photoUrl']),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      emailVerified: map['emailVerified'] == true,
      category: _stringOrNull(map['category']),
      location: _stringOrNull(map['location']),
      isApproved: map['isApproved'] == true,
      about: _stringOrNull(map['about']),
      bio: _stringOrNull(map['bio']),
      skills: List<String>.from(map['skills'] ?? const []),
      yearsExperience: (map['yearsExperience'] as num?)?.toInt() ?? 0,
      available: map['available'] != false,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      priceRange: (map['priceRange'] ?? '').toString(),
      businessName: _stringOrNull(map['businessName']),
      images: List<String>.from(map['images'] ?? const []),
      verified: map['verified'] == true,
      premium: map['premium'] == true,
      isBlocked: map['isBlocked'] == true,
      isAdmin: map['isAdmin'] == true,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.data() ?? <String, dynamic>{}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'photoUrl': photoUrl,
        'latitude': latitude,
        'longitude': longitude,
        'emailVerified': emailVerified,
        'category': category,
        'location': location,
        'isApproved': isApproved,
        'about': about,
        'bio': bio,
        'skills': skills,
        'yearsExperience': yearsExperience,
        'available': available,
        'rating': rating,
        'reviewCount': reviewCount,
        'priceRange': priceRange,
        'businessName': businessName,
        'images': images,
        'verified': verified,
        'premium': premium,
        'isBlocked': isBlocked,
        'isAdmin': isAdmin,
      };

  static String? _stringOrNull(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
