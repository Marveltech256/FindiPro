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

  // Phase 34: Subscription & Monetization fields
  final String plan; // 'basic', 'verified', 'premium'
  final String subscriptionStatus; // 'active', 'pending', 'expired', 'cancelled'
  final String? subscriptionRegion; // 'Africa', 'Europe', 'USA'
  final String? subscriptionCurrency; // 'UGX', 'EUR', 'USD'
  final DateTime? subscriptionExpiresAt;
  final String? verificationStatus; // 'pending', 'approved', 'rejected', 'suspended'

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = 'customer',
    this.photoUrl,
    this.latitude,
    this.longitude,
    this.emailVerified = false,
    this.category,
    this.location,
    this.isApproved = true,
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
    this.plan = 'basic',
    this.subscriptionStatus = 'active',
    this.subscriptionRegion,
    this.subscriptionCurrency,
    this.subscriptionExpiresAt,
    this.verificationStatus,
  });

  bool get isProvider => role == 'provider' || role == 'technician';
  bool get isCustomer => role == 'customer' || role == 'client';

  /// Whether provider's paid plan is currently active and not expired.
  bool get isSubscriptionActive {
    if (subscriptionExpiresAt != null && subscriptionExpiresAt!.isBefore(DateTime.now())) {
      return false;
    }
    return subscriptionStatus.toLowerCase() == 'active';
  }

  /// Active plan after checking expiration. If expired, safely downgrades to 'basic'.
  String get effectivePlan {
    if (!isProvider) return 'basic';
    final p = plan.toLowerCase();
    if (p == 'basic') return 'basic';
    if (!isSubscriptionActive) return 'basic';
    return p;
  }

  /// Whether the provider qualifies for the blue Verified badge.
  /// Conditions: plan is 'verified' (or legacy verified) AND verification_status is 'approved' AND active subscription.
  bool get isVerifiedBadge {
    if (!isProvider) return false;
    final p = effectivePlan;
    final isApprovedVerif = (verificationStatus ?? '').toLowerCase() == 'approved' || verified;
    return (p == 'verified' || (verified && isSubscriptionActive)) && isApprovedVerif;
  }

  /// Whether the provider qualifies for the golden Premium badge.
  /// Conditions: effective plan is 'premium'.
  bool get isPremiumBadge {
    if (!isProvider) return false;
    final p = effectivePlan;
    return p == 'premium' || (premium && isSubscriptionActive);
  }

  factory UserModel.fromMap(Map<String, dynamic> map, [String? fallbackUid]) {
    final uid = (map['uid'] ?? map['firebase_uid'] ?? map['id'] ?? fallbackUid ?? '').toString();
    final rawRole = (map['role'] ?? map['user_role'] ?? map['type'] ?? '').toString().toLowerCase().trim();

    final String parsedRole;
    if (rawRole == 'provider' || rawRole == 'service_provider' || rawRole == 'technician') {
      parsedRole = rawRole == 'technician' ? 'technician' : 'provider';
    } else if (rawRole == 'admin') {
      parsedRole = 'admin';
    } else if (rawRole == 'customer' || rawRole == 'client' || rawRole == 'user') {
      parsedRole = 'customer';
    } else if (rawRole.isNotEmpty) {
      parsedRole = rawRole;
    } else {
      parsedRole = 'customer';
    }

    DateTime? parseNullableDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    final parsedPlan = (map['plan'] ?? (map['premium'] == true || map['is_premium'] == true ? 'premium' : (map['verified'] == true || map['is_verified'] == true ? 'verified' : 'basic'))).toString().toLowerCase();

    return UserModel(
      uid: uid,
      name: (map['full_name'] ?? map['display_name'] ?? map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      role: parsedRole,
      photoUrl: _stringOrNull(map['photoUrl'] ?? map['photo_url'] ?? map['avatar_url']),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      emailVerified: map['emailVerified'] == true || map['email_verified'] == true,
      category: _stringOrNull(map['category'] ?? map['category_name']),
      location: _stringOrNull(map['location'] ?? map['address']),
      isApproved: map['isApproved'] != false && map['is_approved'] != false,
      about: _stringOrNull(map['about'] ?? map['description']),
      bio: _stringOrNull(map['bio']),
      skills: List<String>.from(map['skills'] ?? const []),
      yearsExperience: (map['yearsExperience'] ?? map['years_experience'] as num?)?.toInt() ?? 0,
      available: map['available'] != false && map['is_available'] != false,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] ?? map['review_count'] as num?)?.toInt() ?? 0,
      priceRange: (map['priceRange'] ?? map['price_range'] ?? '').toString(),
      businessName: _stringOrNull(map['businessName'] ?? map['business_name']),
      images: List<String>.from(map['images'] ?? map['portfolio_images'] ?? const []),
      verified: map['verified'] == true || map['is_verified'] == true,
      premium: map['premium'] == true || map['is_premium'] == true,
      isBlocked: map['isBlocked'] == true || map['is_blocked'] == true,
      isAdmin: map['isAdmin'] == true || map['is_admin'] == true || parsedRole == 'admin',
      plan: parsedPlan,
      subscriptionStatus: (map['subscription_status'] ?? map['subscriptionStatus'] ?? 'active').toString().toLowerCase(),
      subscriptionRegion: _stringOrNull(map['subscription_region'] ?? map['subscriptionRegion']),
      subscriptionCurrency: _stringOrNull(map['subscription_currency'] ?? map['subscriptionCurrency']),
      subscriptionExpiresAt: parseNullableDate(map['subscription_expires_at'] ?? map['subscriptionExpiresAt']),
      verificationStatus: _stringOrNull(map['verification_status'] ?? map['verificationStatus']),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'firebase_uid': uid,
        'name': name,
        'display_name': name,
        'full_name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'photoUrl': photoUrl,
        'photo_url': photoUrl,
        'avatar_url': photoUrl,
        'latitude': latitude,
        'longitude': longitude,
        'emailVerified': emailVerified,
        'email_verified': emailVerified,
        'category': category,
        'location': location,
        'isApproved': isApproved,
        'is_approved': isApproved,
        'about': about,
        'bio': bio,
        'skills': skills,
        'yearsExperience': yearsExperience,
        'years_experience': yearsExperience,
        'available': available,
        'rating': rating,
        'reviewCount': reviewCount,
        'review_count': reviewCount,
        'priceRange': priceRange,
        'price_range': priceRange,
        'businessName': businessName,
        'business_name': businessName,
        'images': images,
        'verified': verified,
        'is_verified': verified,
        'premium': premium,
        'is_premium': premium,
        'isBlocked': isBlocked,
        'is_blocked': isBlocked,
        'isAdmin': isAdmin,
        'is_admin': isAdmin,
        'plan': plan,
        'subscription_status': subscriptionStatus,
        if (subscriptionRegion != null) 'subscription_region': subscriptionRegion,
        if (subscriptionCurrency != null) 'subscription_currency': subscriptionCurrency,
        if (subscriptionExpiresAt != null) 'subscription_expires_at': subscriptionExpiresAt!.toUtc().toIso8601String(),
        if (verificationStatus != null) 'verification_status': verificationStatus,
      };

  static String? _stringOrNull(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
