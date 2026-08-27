import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../models/verification_request.dart';
import 'notification_repository.dart';

class VerificationRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Submits an identity / business verification request for a provider.
  Future<void> submitRequest(VerificationRequest request) async {
    final providerUuid = UuidUtils.isValidUuid(request.providerId)
        ? request.providerId
        : UuidUtils.firebaseUidToUuid(request.providerId);

    final payload = {
      'provider_id': providerUuid,
      'provider_name': request.providerName.trim(),
      if (request.nationalIdNumber != null) 'national_id_number': request.nationalIdNumber,
      if (request.idFrontUrl != null) 'id_front_url': request.idFrontUrl,
      if (request.idBackUrl != null) 'id_back_url': request.idBackUrl,
      if (request.businessDocUrl != null) 'business_doc_url': request.businessDocUrl,
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _supabase.from('verification_requests').insert(payload);
      debugPrint('>>> [VerificationRepository.submitRequest] Inserted request for ${request.providerId}');

      // Update provider profile verification status to pending
      try {
        await _supabase.from('profiles').update({
          'verification_status': 'pending',
        }).or('id.eq.$providerUuid,firebase_uid.eq.${request.providerId},uid.eq.${request.providerId}');
      } catch (_) {}

      try {
        await _supabase.from('providers').update({
          'verification_status': 'pending',
        }).or('id.eq.$providerUuid,user_id.eq.$providerUuid,firebase_uid.eq.${request.providerId},uid.eq.${request.providerId}');
      } catch (_) {}
    } catch (e) {
      debugPrint('>>> [VerificationRepository.submitRequest] Error: $e');
      throw Exception('Unable to submit verification request. Please try again.');
    }
  }

  /// Gets the most recent verification request for a provider.
  Future<VerificationRequest?> getLatestRequestForProvider(String providerId) async {
    if (providerId.isEmpty) return null;
    final providerUuid = UuidUtils.isValidUuid(providerId)
        ? providerId
        : UuidUtils.firebaseUidToUuid(providerId);

    try {
      final res = await _supabase
          .from('verification_requests')
          .select()
          .or('provider_id.eq.$providerUuid,provider_id.eq.$providerId')
          .order('created_at', ascending: false)
          .limit(1);

      if (res.isNotEmpty) {
        return VerificationRequest.fromMap(res.first);
      }
    } catch (e) {
      debugPrint('>>> [VerificationRepository.getLatestRequestForProvider] Error: $e');
    }
    return null;
  }

  /// Streams the latest verification request for a provider.
  Stream<VerificationRequest?> watchLatestRequestForProvider(String providerId) {
    if (providerId.isEmpty) return Stream.value(null);
    final providerUuid = UuidUtils.isValidUuid(providerId)
        ? providerId
        : UuidUtils.firebaseUidToUuid(providerId);

    return _supabase
        .from('verification_requests')
        .stream(primaryKey: ['id'])
        .eq('provider_id', providerUuid)
        .order('created_at', ascending: false)
        .map((rows) {
          if (rows.isEmpty) return null;
          return VerificationRequest.fromMap(rows.first);
        })
        .handleError((error) {
          debugPrint('>>> [VerificationRepository.watchLatestRequestForProvider] Stream error: $error');
          return null;
        });
  }

  /// Streams verification requests by status for admin review.
  Stream<List<VerificationRequest>> getPendingRequests({String status = 'pending'}) {
    var query = _supabase
        .from('verification_requests')
        .stream(primaryKey: ['id']);

    if (status.isNotEmpty && status != 'all') {
      query = query.eq('status', status);
    }

    return query
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => VerificationRequest.fromMap(r)).toList())
        .handleError((error) {
          debugPrint('>>> [VerificationRepository.getPendingRequests] Stream error: $error');
          return <VerificationRequest>[];
        });
  }

  /// Approves a provider verification request and updates verified status in providers and profiles.
  Future<void> approveRequest(String requestId, String providerId) async {
    final providerUuid = UuidUtils.isValidUuid(providerId)
        ? providerId
        : UuidUtils.firebaseUidToUuid(providerId);

    bool updated = false;
    try {
      await _supabase
          .from('verification_requests')
          .update({
            'status': 'approved',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId);
      updated = true;
    } catch (e) {
      debugPrint('>>> [VerificationRepository.approveRequest] verification_requests note: $e');
    }

    try {
      await _supabase.from('providers').update({
        'verified': true,
        'is_verified': true,
        'verification_status': 'approved',
      }).or('id.eq.$providerUuid,user_id.eq.$providerUuid,firebase_uid.eq.$providerId,uid.eq.$providerId');
      updated = true;
    } catch (e) {
      debugPrint('>>> [VerificationRepository.approveRequest] providers note: $e');
    }

    try {
      await _supabase.from('profiles').update({
        'verified': true,
        'is_verified': true,
        'verification_status': 'approved',
      }).or('id.eq.$providerUuid,firebase_uid.eq.$providerId,uid.eq.$providerId');
      updated = true;
    } catch (e) {
      debugPrint('>>> [VerificationRepository.approveRequest] profiles note: $e');
    }

    if (!updated) {
      throw Exception('Failed to approve verification request.');
    }

    // Notify provider
    try {
      await NotificationRepository().createNotification(
        userId: providerId,
        title: 'Verification Approved 🎉',
        body: 'Your identity and business verification has been approved! Your Blue Verification badge is now active on your public profile.',
        type: 'verification',
        data: {'status': 'approved', 'request_id': requestId},
      );
    } catch (_) {}
  }

  /// Rejects a provider verification request.
  Future<void> rejectRequest(String requestId, String providerId, {String? reason}) async {
    final providerUuid = UuidUtils.isValidUuid(providerId)
        ? providerId
        : UuidUtils.firebaseUidToUuid(providerId);

    try {
      await _supabase
          .from('verification_requests')
          .update({
            'status': 'rejected',
            if (reason != null && reason.isNotEmpty) 'notes': reason,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      debugPrint('>>> [VerificationRepository.rejectRequest] Error: $e');
      throw Exception('Failed to reject verification request.');
    }

    try {
      await _supabase.from('providers').update({
        'verified': false,
        'is_verified': false,
        'verification_status': 'rejected',
      }).or('id.eq.$providerUuid,user_id.eq.$providerUuid,firebase_uid.eq.$providerId,uid.eq.$providerId');
    } catch (_) {}

    try {
      await _supabase.from('profiles').update({
        'verified': false,
        'is_verified': false,
        'verification_status': 'rejected',
      }).or('id.eq.$providerUuid,firebase_uid.eq.$providerId,uid.eq.$providerId');
    } catch (_) {}

    // Notify provider with feedback
    try {
      final bodyText = (reason != null && reason.trim().isNotEmpty)
          ? 'Your verification request was not approved: ${reason.trim()}. You may update your documents and re-submit.'
          : 'Your verification request was not approved. Please review your documents and re-submit.';

      await NotificationRepository().createNotification(
        userId: providerId,
        title: 'Verification Request Update',
        body: bodyText,
        type: 'verification',
        data: {'status': 'rejected', 'request_id': requestId, 'reason': reason},
      );
    } catch (_) {}
  }
}