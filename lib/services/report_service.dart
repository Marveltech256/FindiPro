import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';

/// Trust & Safety reporting and user blocking service for FindiPro (Phase 34).
class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Submits an abuse/trust report against a user or provider
  Future<bool> submitReport({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? details,
    String? bookingId,
  }) async {
    try {
      final reporterUuid = UuidUtils.firebaseUidToUuid(reporterId);
      final reportedUuid = UuidUtils.firebaseUidToUuid(reportedUserId);
      final nowIso = DateTime.now().toUtc().toIso8601String();

      await _supabase.from('reports').insert({
        'reporter_id': reporterUuid,
        'reported_user_id': reportedUuid,
        'reporter_uid': reporterId,
        'reported_uid': reportedUserId,
        'reason': reason.trim(),
        'details': details?.trim() ?? '',
        if (bookingId != null && bookingId.isNotEmpty) 'booking_id': bookingId,
        'status': 'pending',
        'created_at': nowIso,
      });

      debugPrint('>>> [ReportService] Report submitted against user $reportedUserId ($reportedUuid).');
      return true;
    } catch (e) {
      debugPrint('>>> [ReportService.submitReport] Error: $e');
      return false;
    }
  }

  /// Blocks a user to prevent unwanted contact or messaging
  Future<bool> blockUser({
    required String userId,
    required String blockedUserId,
  }) async {
    try {
      final userUuid = UuidUtils.firebaseUidToUuid(userId);
      final blockedUuid = UuidUtils.firebaseUidToUuid(blockedUserId);
      final nowIso = DateTime.now().toUtc().toIso8601String();

      await _supabase.from('blocked_users').upsert({
        'user_id': userUuid,
        'blocked_user_id': blockedUuid,
        'user_uid': userId,
        'blocked_uid': blockedUserId,
        'created_at': nowIso,
      });

      debugPrint('>>> [ReportService] User $blockedUserId blocked by $userId.');
      return true;
    } catch (e) {
      debugPrint('>>> [ReportService.blockUser] Error: $e');
      return false;
    }
  }

  /// Unblocks a previously blocked user
  Future<bool> unblockUser({
    required String userId,
    required String blockedUserId,
  }) async {
    try {
      final userUuid = UuidUtils.firebaseUidToUuid(userId);
      final blockedUuid = UuidUtils.firebaseUidToUuid(blockedUserId);

      await _supabase
          .from('blocked_users')
          .delete()
          .eq('user_id', userUuid)
          .eq('blocked_user_id', blockedUuid);

      debugPrint('>>> [ReportService] User $blockedUserId unblocked by $userId.');
      return true;
    } catch (e) {
      debugPrint('>>> [ReportService.unblockUser] Error: $e');
      return false;
    }
  }

  /// Checks if two users have a block relationship
  Future<bool> isUserBlocked({
    required String userId,
    required String otherUserId,
  }) async {
    try {
      final userUuid = UuidUtils.firebaseUidToUuid(userId);
      final otherUuid = UuidUtils.firebaseUidToUuid(otherUserId);

      final rows = await _supabase
          .from('blocked_users')
          .select('id')
          .or('and(user_id.eq.$userUuid,blocked_user_id.eq.$otherUuid),and(user_id.eq.$otherUuid,blocked_user_id.eq.$userUuid)')
          .limit(1);

      return (rows as List).isNotEmpty;
    } catch (e) {
      debugPrint('>>> [ReportService.isUserBlocked] Error: $e');
      return false;
    }
  }
}
