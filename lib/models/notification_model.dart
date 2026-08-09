import 'package:cloud_firestore/cloud_firestore.dart';

/// An enum to represent the different types of notifications in the app.
enum NotificationType {
  message,
  serviceRequest,
  requestAccepted,
  requestDeclined,
  bookingChanged,
  serviceCompleted,
}

/// Represents a single notification document stored in Firestore.
class NotificationModel {
  final String id;
  final String recipientId;
  final String? senderId;
  final NotificationType type;
  final String title;
  final String body;
  final String? referenceId; // e.g., bookingId or chatId
  final bool isRead;
  final Timestamp createdAt;

  NotificationModel({
    required this.id,
    required this.recipientId,
    this.senderId,
    required this.type,
    required this.title,
    required this.body,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return NotificationModel(
      id: snapshot.id,
      recipientId: data['recipientId'] ?? '',
      senderId: data['senderId'],
      type: _parseNotificationType(data['type']),
      title: data['title'] ?? 'No Title',
      body: data['body'] ?? 'No Content',
      referenceId: data['referenceId'],
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  static NotificationType _parseNotificationType(String? typeString) {
    return NotificationType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => NotificationType.serviceRequest, // A safe default
    );
  }
}