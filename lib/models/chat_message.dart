/// Represents a single message within a conversation.
class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String? bookingId;
  final String? jobId;
  final String text;
  final String type; // 'text', 'image', etc.
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.bookingId,
    this.jobId,
    required this.text,
    this.type = 'text',
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data, [String? fallbackId]) {
    DateTime parseDate(dynamic d) {
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    final rawReadAt = data['read_at'] ?? data['readAt'];
    final readAtDate = rawReadAt != null ? parseDate(rawReadAt) : null;
    final messageText = (data['message'] ?? data['text'] ?? '').toString();

    return ChatMessage(
      id: (data['id'] ?? fallbackId ?? '').toString(),
      senderId: (data['sender_id'] ?? data['senderId'] ?? '').toString(),
      receiverId: (data['receiver_id'] ?? data['receiverId'] ?? '').toString(),
      bookingId: data['booking_id']?.toString() ?? data['bookingId']?.toString(),
      jobId: data['job_id']?.toString() ?? data['jobId']?.toString(),
      text: messageText,
      type: (data['type'] ?? 'text').toString(),
      isRead: data['is_read'] == true || data['isRead'] == true || readAtDate != null,
      readAt: readAtDate,
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      if (bookingId != null) 'booking_id': bookingId,
      if (jobId != null) 'job_id': jobId,
      'message': text,
      'text': text,
      'type': type,
      'is_read': isRead,
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}