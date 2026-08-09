import 'package:cloud_firestore/cloud_firestore.dart';

/// A service to handle all administrative moderation actions.
class ModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Blocks a user by setting their `isBlocked` flag to true.
  Future<void> blockUser(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isBlocked': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // TODO: Log this action to 'admin_logs'
  }

  /// Unblocks a user by setting their `isBlocked` flag to false.
  Future<void> unblockUser(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isBlocked': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // TODO: Log this action to 'admin_logs'
  }

  /// Approves a provider, making them visible in public listings.
  Future<void> approveProvider(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isApproved': true,
      'isPendingApproval': false,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // TODO: Log this action and send a notification
  }

  /// Rejects a provider's application.
  Future<void> rejectProvider(String uid, {String? reason}) async {
    await _firestore.collection('users').doc(uid).update({
      'isApproved': false,
      'isPendingApproval': false, // No longer pending
      'rejectionReason': reason ?? 'Your application did not meet our requirements.',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // TODO: Log this action and send a notification
  }

  /// Marks a report as resolved.
  Future<void> resolveReport(String reportId) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    // TODO: Log this action
  }

  /// Marks a report as dismissed.
  Future<void> dismissReport(String reportId) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': 'dismissed',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    // TODO: Log this action
  }

  /// Soft deletes a user account.
  Future<void> softDeleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
    // TODO: Log this action
  }
}