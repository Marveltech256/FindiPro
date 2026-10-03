class FeedbackItem {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  final String type; // 'feedback' or 'feature_request'
  final String category;
  final String title;
  final String description;
  final double rating;
  final String status; // 'pending', 'under_review', 'planned', 'in_progress', 'completed', 'declined'
  final int votes;
  final List<String> upvoterUids;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeedbackItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    this.rating = 5.0,
    this.status = 'pending',
    this.votes = 0,
    this.upvoterUids = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFeatureRequest => type == 'feature_request';
  bool get isFeedback => type == 'feedback';

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    List<String> upvoters = [];
    if (json['upvoter_uids'] != null) {
      if (json['upvoter_uids'] is List) {
        upvoters = (json['upvoter_uids'] as List).map((e) => e.toString()).toList();
      }
    }

    return FeedbackItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Anonymous',
      userEmail: json['user_email']?.toString() ?? '',
      userRole: json['user_role']?.toString() ?? 'customer',
      type: json['type']?.toString() ?? 'feedback',
      category: json['category']?.toString() ?? 'General',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      status: json['status']?.toString() ?? 'pending',
      votes: (json['votes'] as num?)?.toInt() ?? 0,
      upvoterUids: upvoters,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'user_role': userRole,
      'type': type,
      'category': category,
      'title': title,
      'description': description,
      'rating': rating,
      'status': status,
      'votes': votes,
      'upvoter_uids': upvoterUids,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
