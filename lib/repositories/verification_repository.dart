import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/verification_request.dart';

class VerificationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> submitRequest(VerificationRequest request) async {
    await _db.collection('verification_requests').add(request.toMap());
  }

  Stream<QuerySnapshot> getPendingRequests() {
    return _db
        .collection('verification_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> approveRequest(
      String requestId, String providerId) async {
    await _db
        .collection('verification_requests')
        .doc(requestId)
        .update({'status': 'approved'});

    await _db.collection('users').doc(providerId).update({
      'verified': true,
      'verificationStatus': 'approved',
    });
  }

  Future<void> rejectRequest(String requestId) async {
    await _db
        .collection('verification_requests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }
}