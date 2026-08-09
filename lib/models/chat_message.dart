import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single message within a conversation.
class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String type; // 'text', 'image', etc.
  final bool isRead;
  final Timestamp createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.type = 'text',
    required this.isRead,
    required this.createdAt,
  });

  /// Creates a ChatMessage from a Firestore document.
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? '',
      type: data['type'] ?? 'text',
      isRead: data['isRead'] ?? false,
      // Ensure createdAt is always a Timestamp.
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // Note: toFirestore is not needed for this model as messages are created
  // directly in the repository method for better control.
}