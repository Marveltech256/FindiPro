import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/feedback_model.dart';

class FeedbackRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Submits an app feedback review with star rating
  Future<void> submitFeedback({
    required String userId,
    required String userName,
    required String userEmail,
    required String userRole,
    required String category,
    required double rating,
    String? title,
    required String description,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    debugPrint('>>> [FeedbackRepository] Submitting feedback from $userName ($userId)');

    try {
      await _supabase.from('feedback_requests').insert({
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'user_role': userRole,
        'type': 'feedback',
        'category': category,
        'title': title ?? '',
        'description': description,
        'rating': rating,
        'status': 'pending',
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      debugPrint('>>> [FeedbackRepository] Feedback submitted successfully');
    } catch (e) {
      debugPrint('>>> [FeedbackRepository] Error submitting feedback: $e');
      rethrow;
    }
  }

  /// Proposes a new feature request
  Future<void> submitFeatureRequest({
    required String userId,
    required String userName,
    required String userEmail,
    required String userRole,
    required String title,
    required String category,
    required String description,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    debugPrint('>>> [FeedbackRepository] Submitting feature request: $title');

    try {
      await _supabase.from('feedback_requests').insert({
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'user_role': userRole,
        'type': 'feature_request',
        'category': category,
        'title': title,
        'description': description,
        'rating': 5.0,
        'status': 'under_review',
        'votes': 1,
        'upvoter_uids': [userId],
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      debugPrint('>>> [FeedbackRepository] Feature request created successfully');
    } catch (e) {
      debugPrint('>>> [FeedbackRepository] Error proposing feature: $e');
      rethrow;
    }
  }

  /// Toggles an upvote on a feature request
  Future<void> toggleUpvoteFeatureRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      final res = await _supabase
          .from('feedback_requests')
          .select()
          .eq('id', requestId)
          .single();

      final currentItem = FeedbackItem.fromJson(res);
      final hasUpvoted = currentItem.upvoterUids.contains(userId);

      List<String> newUpvoters = List.from(currentItem.upvoterUids);
      int newVotes = currentItem.votes;

      if (hasUpvoted) {
        newUpvoters.remove(userId);
        newVotes = (newVotes - 1).clamp(0, 999999);
      } else {
        newUpvoters.add(userId);
        newVotes = newVotes + 1;
      }

      await _supabase.from('feedback_requests').update({
        'votes': newVotes,
        'upvoter_uids': newUpvoters,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);
    } catch (e) {
      debugPrint('>>> [FeedbackRepository] Error toggling upvote: $e');
      rethrow;
    }
  }

  /// Streams all community feature requests ordered by highest votes
  Stream<List<FeedbackItem>> watchFeatureRequests() {
    return _supabase
        .from('feedback_requests')
        .stream(primaryKey: ['id'])
        .eq('type', 'feature_request')
        .order('votes', ascending: false)
        .map((data) => data.map((json) => FeedbackItem.fromJson(json)).toList());
  }

  /// Fetches all feature requests once
  Future<List<FeedbackItem>> getFeatureRequests() async {
    try {
      final res = await _supabase
          .from('feedback_requests')
          .select()
          .eq('type', 'feature_request')
          .order('votes', ascending: false);

      return res.map((json) => FeedbackItem.fromJson(json)).toList();
    } catch (e) {
      debugPrint('>>> [FeedbackRepository] Error fetching feature requests: $e');
      return [];
    }
  }

  /// Admin view: fetches all feedback and feature requests
  Future<List<FeedbackItem>> getAllFeedbackForAdmin({String? typeFilter}) async {
    try {
      var query = _supabase.from('feedback_requests').select();
      if (typeFilter != null && typeFilter != 'all') {
        query = query.eq('type', typeFilter);
      }
      final res = await query.order('created_at', ascending: false);
      return res.map((json) => FeedbackItem.fromJson(json)).toList();
    } catch (e) {
      debugPrint('>>> [FeedbackRepository] Error fetching feedback for admin: $e');
      return [];
    }
  }

  /// Admin: Updates the status of a feedback or feature item
  Future<void> updateStatus(String id, String newStatus) async {
    try {
      await _supabase.from('feedback_requests').update({
        'status': newStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      debugPrint('>>> [FeedbackRepository] Error updating status: $e');
      rethrow;
    }
  }

  /// Admin: Deletes a feedback item
  Future<void> deleteFeedbackItem(String id) async {
    try {
      await _supabase.from('feedback_requests').delete().eq('id', id);
    } catch (e) {
      debugPrint('>>> [FeedbackRepository] Error deleting feedback item: $e');
      rethrow;
    }
  }
}
