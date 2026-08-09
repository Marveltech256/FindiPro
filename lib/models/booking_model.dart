import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for the status of a booking or service request.
enum BookingStatus {
  pending,
  accepted,
  declined,
  inProgress,
  providerCompleted, // Provider marks as done
  clientConfirmed,   // Client confirms completion, booking is now reviewable
  cancelled,
}

/// Represents a single booking or service request document stored in Firestore.
class BookingModel {
  final String id;
  final String clientId;
  final String providerId;
  final String serviceNeeded;
  final String notes;
  final DateTime requestedDate;
  final BookingStatus status;
  final Timestamp createdAt;

  BookingModel({
    required this.id,
    required this.clientId,
    required this.providerId,
    required this.serviceNeeded,
    required this.notes,
    required this.requestedDate,
    required this.status,
    required this.createdAt,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return BookingModel(
      id: snapshot.id,
      clientId: data['clientId'] ?? '',
      providerId: data['providerId'] ?? '',
      serviceNeeded: data['serviceNeeded'] ?? '',
      notes: data['notes'] ?? '',
      requestedDate: (data['requestedDate'] as Timestamp).toDate(),
      status: _parseBookingStatus(data['status']),
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'providerId': providerId,
      'serviceNeeded': serviceNeeded,
      'notes': notes,
      'requestedDate': Timestamp.fromDate(requestedDate),
      'status': status.name,
      'createdAt': createdAt,
    };
  }

  static BookingStatus _parseBookingStatus(String? statusString) {
    return BookingStatus.values.firstWhere(
      (e) => e.name == statusString,
      orElse: () => BookingStatus.pending, // Default to pending
    );
  }
}