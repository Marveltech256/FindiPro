import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final _db=FirebaseFirestore.instance;
  Future<void> approveProvider(String uid) async {
    final batch=_db.batch();
    batch.update(_db.collection('providers').doc(uid),{'isApproved':true,'updatedAt':FieldValue.serverTimestamp()});
    batch.update(_db.collection('users').doc(uid),{'isApproved':true,'updatedAt':FieldValue.serverTimestamp()});
    await batch.commit();
  }
  Future<void> blockUser(String uid,bool blocked) async {
    await _db.collection('users').doc(uid).update({'isBlocked':blocked,'updatedAt':FieldValue.serverTimestamp()});
    if((await _db.collection('providers').doc(uid).get()).exists){await _db.collection('providers').doc(uid).update({'isBlocked':blocked,'updatedAt':FieldValue.serverTimestamp()});}
  }
  Future<void> resolveReport(String id,String status) async=>_db.collection('reports').doc(id).update({'status':status,'resolvedAt':FieldValue.serverTimestamp()});
}
