import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:findipro/models/report_model.dart';

/// A repository for managing user reports in Firestore.
class ReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new report document in the 'reports' collection.
  Future<void> createReport(ReportModel report) async {
    try {
      await _firestore.collection('reports').add(report.toFirestore());
    } on FirebaseException {
      // Let the UI handle the exception
      rethrow;
    }
  }
}