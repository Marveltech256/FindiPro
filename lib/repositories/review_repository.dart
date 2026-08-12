import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addReview(ReviewModel review) async {
    await _db.collection('reviews').add(review.toMap());

    final snapshot = await _db
        .collection('reviews')
        .where('providerId', isEqualTo: review.providerId)
        .get();

    double total = 0;

    for (final doc in snapshot.docs) {
      total += (doc['rating'] as num).toDouble();
    }

    final average = total / snapshot.docs.length;

    await _db.collection('users').doc(review.providerId).update({
      'rating': average,
      'reviewCount': snapshot.docs.length,
    });
  }

  Stream<List<ReviewModel>> getProviderReviews(
      String providerId) {
    return _db
        .collection('reviews')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ReviewModel.fromFirestore(d)).toList());
  }
}