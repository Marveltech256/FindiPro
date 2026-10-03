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

  // Presence & Online Status fields
  final bool isOnline;
  final DateTime? lastSeen;

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
    this.isOnline = false,
    this.lastSeen,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? photoUrl,
    double? latitude,
    double? longitude,
    bool? emailVerified,
    String? category,
    String? location,
    bool? isApproved,
    String? about,
    String? bio,
    List<String>? skills,
    int? yearsExperience,
    bool? available,
    double? rating,
    int? reviewCount,
    String? priceRange,
    String? businessName,
    List<String>? images,
    bool? verified,
    bool? premium,
    bool? isBlocked,
    bool? isAdmin,
    String? plan,
    String? subscriptionStatus,
    String? subscriptionRegion,
    String? subscriptionCurrency,
    DateTime? subscriptionExpiresAt,
    String? verificationStatus,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      emailVerified: emailVerified ?? this.emailVerified,
      category: category ?? this.category,
      location: location ?? this.location,
      isApproved: isApproved ?? this.isApproved,
      about: about ?? this.about,
      bio: bio ?? this.bio,
      skills: skills ?? this.skills,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      available: available ?? this.available,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      priceRange: priceRange ?? this.priceRange,
      businessName: businessName ?? this.businessName,
      images: images ?? this.images,
      verified: verified ?? this.verified,
      premium: premium ?? this.premium,
      isBlocked: isBlocked ?? this.isBlocked,
      isAdmin: isAdmin ?? this.isAdmin,
      plan: plan ?? this.plan,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionRegion: subscriptionRegion ?? this.subscriptionRegion,
      subscriptionCurrency: subscriptionCurrency ?? this.subscriptionCurrency,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  bool get isProvider => role == 'provider' || role == 'technician';
  bool get isCustomer => role == 'customer' || role == 'client';

  /// Human-friendly last seen display matching WhatsApp style.
  String get lastSeenFormatted => formatPresence(isOnline: isOnline, lastSeen: lastSeen);

  /// Static formatter for presence info (WhatsApp style).
  static String formatPresence({required bool isOnline, DateTime? lastSeen}) {
    if (isOnline) return 'Online';
    if (lastSeen == null) return 'Offline';

    final now = DateTime.now();
    final local = lastSeen.toLocal();

    final hour12 = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minuteStr = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour12:$minuteStr $period';

    final today = DateTime(now.year, now.month, now.day);
    final seenDay = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(seenDay).inDays;

    if (diffDays == 0) {
      return 'last seen today at $timeStr';
    } else if (diffDays == 1) {
      return 'last seen yesterday at $timeStr';
    } else if (local.year == now.year) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthName = months[local.month - 1];
      return 'last seen ${local.day} $monthName at $timeStr';
    } else {
      return 'last seen ${local.day}/${local.month}/${local.year} at $timeStr';
    }
  }

  /// Global launch promotion flag: Unlocks Premium on us for all service providers.
  static bool isLaunchPromotionActive = true;

  /// Whether provider's paid plan is currently active and not expired.
  bool get isSubscriptionActive {
    if (isLaunchPromotionActive && isProvider) return true;
    if (subscriptionExpiresAt != null && subscriptionExpiresAt!.isBefore(DateTime.now())) {
      return false;
    }
    return subscriptionStatus.toLowerCase() == 'active';
  }

  /// Active plan after checking expiration and promotional status.
  String get effectivePlan {
    if (!isProvider) return 'basic';
    if (isLaunchPromotionActive) return 'premium';
    final p = plan.toLowerCase();
    if (p == 'basic') return 'basic';
    if (!isSubscriptionActive) return 'basic';
    return p;
  }

  /// Whether the provider qualifies for the blue Verified badge.
  bool get isVerifiedBadge {
    if (!isProvider) return false;
    final isApprovedVerif = (verificationStatus ?? '').toLowerCase() == 'approved' || verified;
    return isApprovedVerif;
  }

  /// Whether the provider qualifies for the golden Premium badge.
  bool get isPremiumBadge {
    // Launch promotion grants premium capabilities across the platform,
    // but the visible golden badge chip is removed until target user count is reached.
    return false;
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

    final rawEmail = (map['email'] ?? '').toString();
    final bool isAdminFlag = map['isAdmin'] == true || map['is_admin'] == true || parsedRole == 'admin';

    String formatNameFromEmail(String emailStr) {
      if (emailStr.isEmpty || !emailStr.contains('@')) return '';
      final prefix = emailStr.split('@').first.trim();
      if (prefix.isEmpty || prefix.toLowerCase() == 'findipro user') return '';
      return prefix
          .split(RegExp(r'[._-]'))
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + (part.length > 1 ? part.substring(1) : ''))
          .join(' ');
    }

    String resolveName() {
      final candidates = [
        map['full_name'],
        map['display_name'],
        map['name'],
        map['username'],
        map['user_name'],
      ];
      if (map['first_name'] != null || map['last_name'] != null) {
        final fn = (map['first_name'] ?? '').toString().trim();
        final ln = (map['last_name'] ?? '').toString().trim();
        final combined = '$fn $ln'.trim();
        if (combined.isNotEmpty) candidates.add(combined);
      }
      for (final c in candidates) {
        if (c != null) {
          final s = c.toString().trim();
          if (s.isNotEmpty && s.toLowerCase() != 'findipro user' && s.toLowerCase() != 'user') {
            return s;
          }
        }
      }
      final fromEmail = formatNameFromEmail(rawEmail);
      if (fromEmail.isNotEmpty) return fromEmail;
      if (isAdminFlag) return 'Admin';
      return '';
    }

    final resolvedName = resolveName();

    return UserModel(
      uid: uid,
      name: resolvedName,
      email: rawEmail,
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
      images: () {
        dynamic raw = map['images'];
        if (raw == null || (raw is List && raw.isEmpty)) {
          raw = map['portfolio_images'];
        }
        if (raw is List) {
          return raw
              .map((e) => e?.toString().trim() ?? '')
              .where((s) => s.isNotEmpty && s.startsWith('http'))
              .toList();
        }
        return <String>[];
      }(),      verified: map['verified'] == true || map['is_verified'] == true,
      premium: map['premium'] == true || map['is_premium'] == true,
      isBlocked: map['isBlocked'] == true || map['is_blocked'] == true,
      isAdmin: map['isAdmin'] == true || map['is_admin'] == true || parsedRole == 'admin',
      plan: parsedPlan,
      subscriptionStatus: (map['subscription_status'] ?? map['subscriptionStatus'] ?? 'active').toString().toLowerCase(),
      subscriptionRegion: _stringOrNull(map['subscription_region'] ?? map['subscriptionRegion']),
      subscriptionCurrency: _stringOrNull(map['subscription_currency'] ?? map['subscriptionCurrency']),
      subscriptionExpiresAt: parseNullableDate(map['subscription_expires_at'] ?? map['subscriptionExpiresAt']),
      verificationStatus: _stringOrNull(map['verification_status'] ?? map['verificationStatus']),
      isOnline: map['isOnline'] == true || map['is_online'] == true,
      lastSeen: parseNullableDate(map['lastSeen'] ?? map['last_seen']),
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
        'portfolio_images': images,
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
        'is_online': isOnline,
        'isOnline': isOnline,
        if (lastSeen != null) 'last_seen': lastSeen!.toUtc().toIso8601String(),
        if (lastSeen != null) 'lastSeen': lastSeen!.toUtc().toIso8601String(),
      };

  static String? _stringOrNull(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
