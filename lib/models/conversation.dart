/// Represents a conversation between two users (a client and a provider).
class Conversation {
  final String id;
  final String bookingId;
  final String clientId;
  final String providerId;
  final List<String> participants;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime lastMessageAt;
  final int clientUnreadCount;
  final int providerUnreadCount;
  final bool isBlocked;
  final String? blockedBy;
  final DateTime createdAt;

  // Populated dynamically from profiles
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

  factory Conversation.fromMap(Map<String, dynamic> data, [String? fallbackId]) {
    DateTime parseDate(dynamic d) {
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    final cId = (data['client_id'] ?? data['clientId'] ?? '').toString();
    final pId = (data['provider_id'] ?? data['providerId'] ?? '').toString();
    final participantsList = data['participants'] != null
        ? List<String>.from(data['participants'])
        : [cId, pId].where((s) => s.isNotEmpty).toList();

    return Conversation(
      id: (data['id'] ?? fallbackId ?? '').toString(),
      bookingId: (data['booking_id'] ?? data['bookingId'] ?? '').toString(),
      clientId: cId,
      providerId: pId,
      participants: participantsList,
      lastMessage: (data['last_message'] ?? data['lastMessage'] ?? '').toString(),
      lastMessageSenderId: (data['last_message_sender_id'] ?? data['lastMessageSenderId'] ?? '').toString(),
      lastMessageAt: parseDate(data['last_message_at'] ?? data['lastMessageAt']),
      clientUnreadCount: (data['client_unread_count'] ?? data['clientUnreadCount'] as num?)?.toInt() ?? 0,
      providerUnreadCount: (data['provider_unread_count'] ?? data['providerUnreadCount'] as num?)?.toInt() ?? 0,
      isBlocked: data['is_blocked'] == true || data['isBlocked'] == true,
      blockedBy: data['blocked_by']?.toString() ?? data['blockedBy']?.toString(),
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'booking_id': bookingId,
      'client_id': clientId,
      'provider_id': providerId,
      'participants': participants,
      'last_message': lastMessage,
      'last_message_sender_id': lastMessageSenderId,
      'last_message_at': lastMessageAt.toIso8601String(),
      'client_unread_count': clientUnreadCount,
      'provider_unread_count': providerUnreadCount,
      'is_blocked': isBlocked,
      'blocked_by': blockedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}