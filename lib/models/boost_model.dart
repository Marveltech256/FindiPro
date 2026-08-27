/// Data model representing a promotional Boost for provider discovery and placement in FindiPro.
/// Prepared for future boost promotions architecture in Phase 38+.
class BoostModel {
  final String id;
  final String providerId;
  final String boostType; // 'category_top', 'city_featured', 'search_highlight'
  final num amount;
  final String currency;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String status; // 'active', 'pending', 'expired', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  const BoostModel({
    required this.id,
    required this.providerId,
    required this.boostType,
    required this.amount,
    this.currency = 'UGX',
    this.startedAt,
    this.expiresAt,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive {
    if (status.toLowerCase() != 'active') return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  factory BoostModel.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
    DateTime parseDate(dynamic d) {
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return BoostModel(
      id: (map['id'] ?? fallbackId ?? '').toString(),
      providerId: (map['provider_id'] ?? map['providerId'] ?? '').toString(),
      boostType: (map['boost_type'] ?? map['boostType'] ?? 'category_top').toString(),
      amount: (map['amount'] as num?) ?? 0,
      currency: (map['currency'] ?? 'UGX').toString(),
      startedAt: parseNullableDate(map['started_at'] ?? map['startedAt'] ?? map['start_at']),
      expiresAt: parseNullableDate(map['expires_at'] ?? map['expiresAt'] ?? map['end_at']),
      status: (map['status'] ?? 'active').toString().toLowerCase(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider_id': providerId,
      'boost_type': boostType,
      'amount': amount,
      'currency': currency,
      if (startedAt != null) 'started_at': startedAt!.toUtc().toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

