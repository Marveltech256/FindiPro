import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:findipro/models/booking_model.dart';

/// A repository for managing booking/service request data in Firestore.
class BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Provides a stream of bookings for a specific client, ordered by creation time.
  Stream<List<BookingModel>> getClientBookingsStream(String clientId) {
    return _firestore
        .collection('bookings')
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
    });
  }

  /// Provides a stream of bookings for a specific provider, ordered by creation time.
  Stream<List<BookingModel>> getProviderBookingsStream(String providerId) {
    return _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
    });
  }

  /// Updates the status of a specific booking.
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Creates a new booking in Firestore.
  Future<DocumentReference> createBooking(Map<String, dynamic> bookingData) async {
    // Ensure status is set to pending on creation
    bookingData['status'] = BookingStatus.pending.name;
    bookingData['createdAt'] = FieldValue.serverTimestamp();
    bookingData['updatedAt'] = FieldValue.serverTimestamp();

    return await _firestore.collection('bookings').add(bookingData);
  }
}