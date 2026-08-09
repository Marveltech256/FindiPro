import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a conversation between two users (a client and a provider).
class Conversation {
  final String id;
  final String bookingId;
  final String clientId;
  final String providerId;
  final List<String> participants;
  final String lastMessage;
  final String lastMessageSenderId;
  final Timestamp lastMessageAt;
  final int clientUnreadCount;
  final int providerUnreadCount;
  final bool isBlocked;
  final String? blockedBy;
  final Timestamp createdAt;

  // These fields are not in Firestore but are populated from the 'users' collection.
  String otherParticipantName = '';
  String otherParticipantPhotoUrl = '';

  Conversation({
    required this.id,
    required this.bookingId,
    required this.clientId,
    required this.providerId,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.lastMessageAt,
    required this.clientUnreadCount,
    required this.providerUnreadCount,
    required this.isBlocked,
    this.blockedBy,
    required this.createdAt,
  });

  /// Creates a Conversation from a Firestore document.
  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      bookingId: data['bookingId'] ?? '',
      clientId: data['clientId'] ?? '',
      providerId: data['providerId'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      lastMessageAt: data['lastMessageAt'] ?? Timestamp.now(),
      clientUnreadCount: data['clientUnreadCount'] ?? 0,
      providerUnreadCount: data['providerUnreadCount'] ?? 0,
      isBlocked: data['isBlocked'] ?? false,
      blockedBy: data['blockedBy'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  /// Converts a Conversation object into a map for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'bookingId': bookingId,
      'clientId': clientId,
      'providerId': providerId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageAt': lastMessageAt,
      'clientUnreadCount': clientUnreadCount,
      'providerUnreadCount': providerUnreadCount,
      'isBlocked': isBlocked,
      'blockedBy': blockedBy,
      'createdAt': createdAt,
    };
  }
}