import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:findipro/models/notification_model.dart';

/// A repository for managing notification data in Firestore.
class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Provides a stream of notifications for a specific user, ordered by creation time.
  Stream<List<NotificationModel>> getNotificationsStream(String recipientId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList();
    });
  }

  /// Marks a specific notification as read in Firestore.
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
  }

  /// Creates a notification document in Firestore.
  /// This should be called from your business logic (e.g., when a message is sent
  /// or a booking status changes).
  Future<void> createNotification({
    required String recipientId,
    String? senderId,
    required NotificationType type,
    required String title,
    required String body,
    String? referenceId,
  }) async {
    await _firestore.collection('notifications').add({
      'recipientId': recipientId,
      'senderId': senderId,
      'type': type.name, // Using enum's name property for robust storage
      'title': title,
      'body': body,
      'referenceId': referenceId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}