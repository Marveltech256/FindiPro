/// Represents an in-app notification in FindiPro matching public.notifications schema.
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory NotificationModel.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
    DateTime parseDate(dynamic d) {
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    Map<String, dynamic>? parsedData;
    if (map['data'] is Map<String, dynamic>) {
      parsedData = map['data'] as Map<String, dynamic>;
    } else if (map['data'] is Map) {
      parsedData = Map<String, dynamic>.from(map['data'] as Map);
    }

    return NotificationModel(
      id: (map['id'] ?? fallbackId ?? '').toString(),
      userId: (map['user_id'] ?? map['userId'] ?? '').toString(),
      title: (map['title'] ?? 'Notification').toString(),
      body: (map['body'] ?? '').toString(),
      type: (map['type'] ?? 'general').toString(),
      data: parsedData,
      readAt: parseNullableDate(map['read_at'] ?? map['readAt']),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      if (data != null) 'data': data,
      if (readAt != null) 'read_at': readAt!.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

