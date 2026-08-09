import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:findipro/models/review_model.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new review and updates the booking to prevent further reviews.
  Future<void> createReview({
    required String bookingId,
    required String clientId,
    required String providerId,
    required double rating,
    required String comment,
  }) async {
    // Use a transaction to ensure atomicity: check for existing review and write new one.
    await _firestore.runTransaction((transaction) async {
      final reviewQuery = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get();

      if (reviewQuery.docs.isNotEmpty) {
        throw Exception('A review for this booking already exists.');
      }

      final newReviewRef = _firestore.collection('reviews').doc();
      transaction.set(newReviewRef, {
        'bookingId': bookingId,
        'clientId': clientId,
        'providerId': providerId,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Provides a stream of all reviews for a specific provider.
  Stream<List<ReviewModel>> getProviderReviewsStream(String providerId) {
    return _firestore
        .collection('reviews')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
    });
  }
}