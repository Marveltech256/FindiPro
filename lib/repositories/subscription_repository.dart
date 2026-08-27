import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../models/subscription_model.dart';

class SubscriptionRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Fetches the latest subscription record for a provider from Supabase.
  Future<SubscriptionModel?> getProviderSubscription(String providerId) async {
    if (providerId.isEmpty) return null;
    final providerUuid = UuidUtils.firebaseUidToUuid(providerId);

    try {
      final res = await _supabase
          .from('provider_subscriptions')
          .select()
          .eq('provider_id', providerUuid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        return SubscriptionModel.fromMap(res);
      }
    } catch (e) {
      debugPrint('>>> [SubscriptionRepository.getProviderSubscription] Note: $e');
    }
    return null;
  }

  /// Streams the provider's active subscription from Supabase in real-time.
  Stream<SubscriptionModel?> watchProviderSubscription(String providerId) {
    if (providerId.isEmpty) return Stream.value(null);
    final providerUuid = UuidUtils.firebaseUidToUuid(providerId);

    return _supabase
        .from('provider_subscriptions')
        .stream(primaryKey: ['id'])
        .eq('provider_id', providerUuid)
        .order('created_at', ascending: false)
        .map((rows) {
          if (rows.isEmpty) return null;
          return SubscriptionModel.fromMap(rows.first);
        })
        .handleError((e) {
          debugPrint('>>> [SubscriptionRepository.watchProviderSubscription] Stream note: $e');
          return null;
        });
  }

  /// Creates a subscription record in Supabase.
  Future<SubscriptionModel?> createSubscription({
    required String providerId,
    required String plan,
    required String billingPeriod,
    required String region,
    required String currency,
    required num amount,
    String status = 'active',
    DateTime? expiresAt,
    String? paymentProvider,
    String? externalTransactionId,
  }) async {
    final providerUuid = UuidUtils.firebaseUidToUuid(providerId);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final expiresIso = expiresAt?.toUtc().toIso8601String() ??
        (billingPeriod.toLowerCase() == 'yearly'
            ? DateTime.now().add(const Duration(days: 365)).toUtc().toIso8601String()
            : DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String());

    final payload = {
      'provider_id': providerUuid,
      'plan': plan.toLowerCase(),
      'billing_period': billingPeriod.toLowerCase(),
      'region': region,
      'currency': currency,
      'amount': amount,
      'status': status.toLowerCase(),
      'started_at': nowIso,
      'expires_at': expiresIso,
      'auto_renew': true,
      if (paymentProvider != null) 'payment_provider': paymentProvider,
      if (externalTransactionId != null) 'external_transaction_id': externalTransactionId,
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    try {
      final res = await _supabase
          .from('provider_subscriptions')
          .insert(payload)
          .select()
          .maybeSingle();

      // Sync provider profile fields in Supabase
      try {
        final profileSync = {
          'plan': plan.toLowerCase(),
          'subscription_status': status.toLowerCase(),
          'subscription_region': region,
          'subscription_currency': currency,
          'subscription_expires_at': expiresIso,
          'is_premium': plan.toLowerCase() == 'premium',
          'premium': plan.toLowerCase() == 'premium',
          if (plan.toLowerCase() == 'verified') 'is_verified': true,
        };

        await _supabase.from('providers').update(profileSync).or('id.eq.$providerUuid,user_id.eq.$providerUuid,firebase_uid.eq.$providerId,uid.eq.$providerId');
        await _supabase.from('profiles').update(profileSync).or('id.eq.$providerUuid,firebase_uid.eq.$providerId');
      } catch (syncErr) {
        debugPrint('>>> [SubscriptionRepository] Profile fields sync note: $syncErr');
      }

      if (res != null) {
        return SubscriptionModel.fromMap(res);
      }
    } catch (e) {
      debugPrint('>>> [SubscriptionRepository.createSubscription] Error: $e');
    }
    return null;
  }

  /// Cancels an active subscription without deleting any provider data, history, or services.
  Future<bool> cancelSubscription(String providerId) async {
    if (providerId.isEmpty) return false;
    final providerUuid = UuidUtils.firebaseUidToUuid(providerId);

    try {
      await _supabase
          .from('provider_subscriptions')
          .update({
            'status': 'cancelled',
            'auto_renew': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('provider_id', providerUuid)
          .eq('status', 'active');

      final syncPayload = {
        'subscription_status': 'cancelled',
      };
      await _supabase.from('providers').update(syncPayload).or('id.eq.$providerUuid,user_id.eq.$providerUuid,firebase_uid.eq.$providerId,uid.eq.$providerId');
      await _supabase.from('profiles').update(syncPayload).or('id.eq.$providerUuid,firebase_uid.eq.$providerId');
      return true;
    } catch (e) {
      debugPrint('>>> [SubscriptionRepository.cancelSubscription] Error: $e');
      return false;
    }
  }

  /// Expires a subscription and safely removes paid entitlements while preserving account data.
  Future<bool> expireSubscription(String providerId) async {
    if (providerId.isEmpty) return false;
    final providerUuid = UuidUtils.firebaseUidToUuid(providerId);

    try {
      await _supabase
          .from('provider_subscriptions')
          .update({
            'status': 'expired',
            'auto_renew': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('provider_id', providerUuid);

      final downgradeSync = {
        'plan': 'basic',
        'subscription_status': 'expired',
        'is_premium': false,
        'premium': false,
      };
      await _supabase.from('providers').update(downgradeSync).or('id.eq.$providerUuid,user_id.eq.$providerUuid,firebase_uid.eq.$providerId,uid.eq.$providerId');
      await _supabase.from('profiles').update(downgradeSync).or('id.eq.$providerUuid,firebase_uid.eq.$providerId');
      return true;
    } catch (e) {
      debugPrint('>>> [SubscriptionRepository.expireSubscription] Error: $e');
      return false;
    }
  }

  /// Checks if the provider's active subscription is past its expiry date, and synchronizes state.
  Future<void> syncSubscriptionExpiration(String providerId) async {
    if (providerId.isEmpty) return;
    try {
      final sub = await getProviderSubscription(providerId);
      if (sub != null && sub.status == 'active' && sub.expiresAt != null && sub.expiresAt!.isBefore(DateTime.now())) {
        await expireSubscription(providerId);
      }
    } catch (e) {
      debugPrint('>>> [SubscriptionRepository.syncSubscriptionExpiration] Error: $e');
    }
  }
}

