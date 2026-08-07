import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String clientId;
  final String providerId;
  final String service;
  final String status;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.clientId,
    required this.providerId,
    required this.service,
    required this.status,
    required this.createdAt,
  });

  factory Booking.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return Booking(
      id: id,
      clientId: data['clientId'] ?? '',
      providerId: data['providerId'] ?? '',
      service: data['service'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}