import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String bookingId;
  final String clientId;
  final String providerId;
  final double rating;
  final String comment;
  final Timestamp createdAt;

  ReviewModel({
    required this.id,
    required this.bookingId,
    required this.clientId,
    required this.providerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return ReviewModel(
      id: snapshot.id,
      bookingId: data['bookingId'] ?? '',
      clientId: data['clientId'] ?? '',
      providerId: data['providerId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}