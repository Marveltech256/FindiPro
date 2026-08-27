/// Represents a provider subscription record matching public.provider_subscriptions schema in Supabase.
class SubscriptionModel {
  final String id;
  final String providerId;
  final String plan; // 'basic', 'verified', 'premium'
  final String billingPeriod; // 'monthly', 'yearly'
  final String region; // 'Africa', 'Europe', 'USA'
  final String currency; // 'UGX', 'EUR', 'USD'
  final num amount;
  final String status; // 'active', 'pending', 'expired', 'cancelled', 'failed'
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final bool autoRenew;
  final String? paymentProvider;
  final String? externalTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubscriptionModel({
    required this.id,
    required this.providerId,
    required this.plan,
    this.billingPeriod = 'monthly',
    this.region = 'Africa',
    this.currency = 'UGX',
    this.amount = 0,
    this.status = 'active',
    this.startedAt,
    this.expiresAt,
    this.autoRenew = true,
    this.paymentProvider,
    this.externalTransactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive {
    if (status.toLowerCase() != 'active') return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isExpired => status.toLowerCase() == 'expired' || (expiresAt != null && expiresAt!.isBefore(DateTime.now()));
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isFailed => status.toLowerCase() == 'failed';

  factory SubscriptionModel.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
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

    return SubscriptionModel(
      id: (map['id'] ?? fallbackId ?? '').toString(),
      providerId: (map['provider_id'] ?? map['providerId'] ?? '').toString(),
      plan: (map['plan'] ?? 'basic').toString().toLowerCase(),
      billingPeriod: (map['billing_period'] ?? map['billingPeriod'] ?? 'monthly').toString().toLowerCase(),
      region: (map['region'] ?? 'Africa').toString(),
      currency: (map['currency'] ?? 'UGX').toString(),
      amount: (map['amount'] as num?) ?? 0,
      status: (map['status'] ?? 'active').toString().toLowerCase(),
      startedAt: parseNullableDate(map['started_at'] ?? map['startedAt']),
      expiresAt: parseNullableDate(map['expires_at'] ?? map['expiresAt']),
      autoRenew: map['auto_renew'] != false && map['autoRenew'] != false,
      paymentProvider: map['payment_provider']?.toString(),
      externalTransactionId: map['external_transaction_id']?.toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider_id': providerId,
      'plan': plan,
      'billing_period': billingPeriod,
      'region': region,
      'currency': currency,
      'amount': amount,
      'status': status,
      if (startedAt != null) 'started_at': startedAt!.toUtc().toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
      'auto_renew': autoRenew,
      if (paymentProvider != null) 'payment_provider': paymentProvider,
      if (externalTransactionId != null) 'external_transaction_id': externalTransactionId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

