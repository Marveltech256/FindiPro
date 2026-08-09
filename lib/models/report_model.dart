import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a report submitted by a user against another user.
class ReportModel {
  final String? id;
  final String reporterId;
  final String reportedUserId;
  final String reason;
  final String description;
  final String status;
  final Timestamp createdAt;

  ReportModel({
    this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  /// Converts the model to a Map for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'description': description,
      'status': status,
      'createdAt': createdAt,
    };
  }
}