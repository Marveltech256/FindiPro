import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:findipro/models/report_model.dart';
import 'package:findipro/repositories/report_repository.dart';
import 'package:findipro/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ReportUserScreen extends StatefulWidget {
  final String reportedUserId;
  final String reportedUserName;

  const ReportUserScreen({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
  });

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _selectedReason;
  bool _isSubmitting = false;

  final List<String> _reportReasons = [
    'Inappropriate Behavior',
    'Scam or Fraud',
    'Poor Service Quality',
    'No Show',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final authService = context.read<AuthService>();
    final reportRepo = context.read<ReportRepository>();
    final reporterId = authService.currentUser?.uid;

    if (reporterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to submit a report.')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final report = ReportModel(
      reporterId: reporterId,
      reportedUserId: widget.reportedUserId,
      reason: _selectedReason!,
      description: _descriptionController.text.trim(),
      status: 'pending',
      createdAt: Timestamp.now(),
    );

    try {
      await reportRepo.createReport(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully. Thank you.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report ${widget.reportedUserName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Please provide details about your report. This will be reviewed by our team.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                decoration: const InputDecoration(
                  labelText: 'Reason for reporting',
                  border: OutlineInputBorder(),
                ),
                items: _reportReasons.map((String reason) {
                  return DropdownMenuItem<String>(
                    value: reason,
                    child: Text(reason),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedReason = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a reason' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Provide more details about the incident.',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                maxLength: 500,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}