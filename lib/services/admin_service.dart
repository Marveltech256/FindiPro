import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';

class AdminMetrics {
  final int totalUsers;
  final int customers;
  final int providers;
  final int verifiedProviders;
  final int premiumProviders;
  final int pendingVerifications;
  final int activeJobs;
  final int completedJobs;
  final int totalReviews;
  final int activeSubscriptions;
  final int totalAdmins;

  const AdminMetrics({
    required this.totalUsers,
    required this.customers,
    required this.providers,
    required this.verifiedProviders,
    required this.premiumProviders,
    required this.pendingVerifications,
    required this.activeJobs,
    required this.completedJobs,
    required this.totalReviews,
    required this.activeSubscriptions,
    this.totalAdmins = 0,
  });
}

class AdminService {
  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Fetches real-time dashboard metrics from Supabase database tables.
  Future<AdminMetrics> getDashboardMetrics() async {
    int totalUsers = 0;
    int customers = 0;
    int providers = 0;
    int verifiedProviders = 0;
    int premiumProviders = 0;
    int pendingVerifications = 0;
    int activeJobs = 0;
    int completedJobs = 0;
    int totalReviews = 0;
    int activeSubscriptions = 0;
    int totalAdmins = 0;

    try {
      final profilesRes = await _supabase.from('profiles').select();
      if (profilesRes.isNotEmpty) {
        totalUsers = profilesRes.length;
        for (final row in profilesRes) {
          final role = (row['role'] ?? 'customer').toString().toLowerCase();
          final verified = row['verified'] == true ||
              row['is_verified'] == true ||
              (row['verification_status'] ?? '').toString().toLowerCase() == 'approved';
          final plan = (row['plan'] ?? '').toString().toLowerCase();
          final premium = plan == 'premium' || row['is_premium'] == true || row['premium'] == true;

          if (role == 'admin') {
            totalAdmins++;
          } else if (role == 'provider' || role == 'technician') {
            providers++;
            if (verified) verifiedProviders++;
            if (premium) premiumProviders++;
          } else {
            customers++;
          }
        }
      }
    } catch (e) {
      debugPrint('>>> [AdminService.getDashboardMetrics] profiles query note: $e');
    }

    try {
      final verifRes = await _supabase
          .from('verification_requests')
          .select('id')
          .eq('status', 'pending');
      pendingVerifications = verifRes.length;
    } catch (e) {
      debugPrint('>>> [AdminService.getDashboardMetrics] verification_requests note: $e');
    }

    try {
      final jobsRes = await _supabase.from('jobs').select('status');
      for (final row in jobsRes) {
        final status = (row['status'] ?? '').toString().toLowerCase();
        if (status == 'completed') {
          completedJobs++;
        } else if (status == 'requested' ||
            status == 'accepted' ||
            status == 'in_progress' ||
            status == 'assigned' ||
            status == 'pending') {
          activeJobs++;
        }
      }
    } catch (e) {
      debugPrint('>>> [AdminService.getDashboardMetrics] jobs query note: $e');
    }

    try {
      final reviewsRes = await _supabase.from('reviews').select('id');
      totalReviews = reviewsRes.length;
    } catch (e) {
      debugPrint('>>> [AdminService.getDashboardMetrics] reviews query note: $e');
    }

    try {
      final subRes = await _supabase
          .from('provider_subscriptions')
          .select('id')
          .eq('status', 'active');
      activeSubscriptions = subRes.length;
    } catch (e) {
      debugPrint('>>> [AdminService.getDashboardMetrics] provider_subscriptions note: $e');
    }

    return AdminMetrics(
      totalUsers: totalUsers,
      customers: customers,
      providers: providers,
      verifiedProviders: verifiedProviders,
      premiumProviders: premiumProviders,
      pendingVerifications: pendingVerifications,
      activeJobs: activeJobs,
      completedJobs: completedJobs,
      totalReviews: totalReviews,
      activeSubscriptions: activeSubscriptions,
      totalAdmins: totalAdmins,
    );
  }

  /// Approves a provider.
  Future<void> approveProvider(String uid) async {
    final uuid = UuidUtils.isValidUuid(uid) ? uid : UuidUtils.firebaseUidToUuid(uid);

    try {
      await _supabase
          .from('providers')
          .update({'is_approved': true})
          .or('id.eq.$uuid,user_id.eq.$uuid,firebase_uid.eq.$uid,uid.eq.$uid');
    } catch (e) {
      debugPrint('>>> [AdminService.approveProvider] providers note: $e');
    }

    try {
      await _supabase
          .from('profiles')
          .update({'is_approved': true})
          .or('id.eq.$uuid,firebase_uid.eq.$uid,uid.eq.$uid');
    } catch (e) {
      debugPrint('>>> [AdminService.approveProvider] profiles note: $e');
      throw Exception('Failed to approve provider.');
    }
  }

  /// Blocks or unblocks a user in profiles and providers tables.
  Future<void> blockUser(String uid, bool blocked) async {
    final uuid = UuidUtils.isValidUuid(uid) ? uid : UuidUtils.firebaseUidToUuid(uid);
    bool updated = false;

    try {
      await _supabase
          .from('profiles')
          .update({'is_blocked': blocked})
          .or('id.eq.$uuid,firebase_uid.eq.$uid,uid.eq.$uid');
      updated = true;
    } catch (e) {
      debugPrint('>>> [AdminService.blockUser] profiles note: $e');
    }

    try {
      final providerPayload = {
        'is_blocked': blocked,
        if (blocked) 'available': false,
      };
      await _supabase
          .from('providers')
          .update(providerPayload)
          .or('id.eq.$uuid,user_id.eq.$uuid,firebase_uid.eq.$uid,uid.eq.$uid');
      updated = true;
    } catch (e) {
      debugPrint('>>> [AdminService.blockUser] providers note: $e');
    }

    if (!updated) {
      throw Exception('Failed to update user block status.');
    }
  }

  /// Resolves a user report.
  Future<void> resolveReport(String id, String status) async {
    try {
      await _supabase
          .from('reports')
          .update({
            'status': status,
            'resolved_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      debugPrint('>>> [AdminService.resolveReport] error: $e');
      throw Exception('Failed to resolve report.');
    }
  }
}
