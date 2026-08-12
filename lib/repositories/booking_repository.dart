import 'package:cloud_firestore/cloud_firestore.dart';

class BookingRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> updateStatus(String bookingId, String status) async {
    // Note: Using 'hire_requests' collection to match your existing screens.
    await _db.collection('hire_requests').doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}