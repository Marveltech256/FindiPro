import 'package:cloud_firestore/cloud_firestore.dart'; 
class ProviderRepository { final _db = FirebaseFirestore.instance; 

Stream<QuerySnapshot<Map<String, dynamic>>> streamProviders() {
return _db
 .collection('providers')
  .where('isApproved', isEqualTo: true)
   .snapshots(); } }