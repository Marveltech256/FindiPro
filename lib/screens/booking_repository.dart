import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking.dart';

class BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Booking>> getClientBookings(String uid) {
    return _firestore
        .collection('bookings')
        .where(
          'clientId',
          isEqualTo: uid,
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Booking.fromFirestore(
          doc.data(),
          doc.id,
        );
      }).toList();
    });
  }
}