import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationRequest {
  final String id;
  final String providerId;
  final String providerName;
  final String? idFrontUrl;
  final String? businessDocUrl;
  final String status;
  final DateTime createdAt;

  VerificationRequest({
    required this.id,
    required this.providerId,
    required this.providerName,
    this.idFrontUrl,
    this.businessDocUrl,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'idFrontUrl': idFrontUrl,
      'businessDocUrl': businessDocUrl,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}