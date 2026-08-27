/// Represents a customer review in FindiPro.
class ReviewModel {
  final String id;
  final String customerId;
  final String? customerName;
  final String? customerPhotoUrl;
  final String? jobId;
  final String? bookingId;
  final String? businessId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.customerId,
    this.customerName,
    this.customerPhotoUrl,
    this.jobId,
    this.bookingId,
    this.businessId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> data, [String? fallbackId]) {
    DateTime parseDate(dynamic d) {
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    final rawRating = data['rating'];
    int parsedRating = 5;
    if (rawRating is num) {
      parsedRating = rawRating.toInt().clamp(1, 5);
    } else if (rawRating is String) {
      parsedRating = (int.tryParse(rawRating) ?? 5).clamp(1, 5);
    }

    return ReviewModel(
      id: (data['id'] ?? fallbackId ?? '').toString(),
      customerId: (data['customer_id'] ?? data['customerId'] ?? data['client_id'] ?? '').toString(),
      customerName: (data['customer_name'] ?? data['customerName'] ?? data['client_name'] ?? data['full_name'])?.toString(),
      customerPhotoUrl: (data['customer_photo_url'] ?? data['customerPhotoUrl'] ?? data['avatar_url'])?.toString(),
      jobId: (data['job_id'] ?? data['jobId'])?.toString(),
      bookingId: (data['booking_id'] ?? data['bookingId'])?.toString(),
      businessId: (data['business_id'] ?? data['businessId'])?.toString(),
      rating: parsedRating,
      comment: data['comment']?.toString(),
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      if (jobId != null && jobId!.isNotEmpty) 'job_id': jobId,
      if (bookingId != null && bookingId!.isNotEmpty) 'booking_id': bookingId,
      if (businessId != null && businessId!.isNotEmpty) 'business_id': businessId,
      'rating': rating,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }
}