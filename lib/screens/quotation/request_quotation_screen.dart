import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../repositories/quotation_repository.dart';
import '../../repositories/user_repository.dart';

class RequestQuotationScreen extends StatefulWidget {
  final UserModel provider;
  final String? conversationId;
  final String? bookingId;

  const RequestQuotationScreen({
    super.key,
    required this.provider,
    this.conversationId,
    this.bookingId,
  });

  @override
  State<RequestQuotationScreen> createState() => _RequestQuotationScreenState();
}

class _RequestQuotationScreenState extends State<RequestQuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _repo = QuotationRepository();
  final _userRepo = UserRepository();

  DateTime? _preferredDate;
  bool _submitting = false;
  String _clientName = 'Client';

  @override
  void initState() {
    super.initState();
    _loadClientProfile();
  }

  Future<void> _loadClientProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await _userRepo.getUser(user.uid);
      if (profile != null && mounted) {
        setState(() {
          _clientName = profile.name.isNotEmpty ? profile.name : (user.displayName ?? 'Client');
          if (profile.phone.isNotEmpty) {
            _phoneController.text = profile.phone;
          }
          if (profile.location != null && profile.location!.isNotEmpty) {
            _addressController.text = profile.location!;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF06B6D4),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _preferredDate = picked);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to request a quotation.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final quotation = await _repo.requestQuotation(
        clientId: user.uid,
        clientName: _clientName,
        clientPhone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        clientAddress: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        providerId: widget.provider.uid,
        providerName: widget.provider.name,
        providerPhone: widget.provider.phone.isNotEmpty ? widget.provider.phone : null,
        providerEmail: widget.provider.email,
        providerAddress: widget.provider.location,
        providerLogoUrl: widget.provider.photoUrl,
        conversationId: widget.conversationId,
        bookingId: widget.bookingId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        preferredDate: _preferredDate,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 10),
              Text('Quotation Requested'),
            ],
          ),
          content: Text(
            'Your quotation request (${quotation.quotationNumber}) has been submitted to ${widget.provider.name}. '
            'You will receive an instant notification when the provider sends your invoice/quotation.',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit quotation: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request a Quotation', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider summary header card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF06B6D4).withAlpha(50)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: widget.provider.photoUrl != null && widget.provider.photoUrl!.isNotEmpty
                          ? NetworkImage(widget.provider.photoUrl!)
                          : null,
                      child: widget.provider.photoUrl == null || widget.provider.photoUrl!.isEmpty
                          ? const Icon(Icons.person, color: Color(0xFF06B6D4))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.provider.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.provider.category ?? 'Professional Service Provider',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(160)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 14, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Job / Service Title',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g. Living Room Painting, Electrical Wiring...',
                  prefixIcon: const Icon(Icons.title, size: 20),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 18),

              const Text(
                'Describe the Work or Requirements',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Provide details, dimensions, materials needed, or specific requirements so the provider can give an accurate estimate...',
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide details' : null,
              ),
              const SizedBox(height: 18),

              const Text(
                'Job Location / Address',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: 'e.g. Plot 14, Kira Road, Kamwokya, Kampala',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the job location' : null,
              ),
              const SizedBox(height: 18),

              const Text(
                'Your Contact Phone',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'e.g. +256 700 000000',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Preferred Start Date (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surface,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF06B6D4)),
                      const SizedBox(width: 12),
                      Text(
                        _preferredDate != null
                            ? DateFormat('EEEE, MMM dd, yyyy').format(_preferredDate!)
                            : 'Select preferred date',
                        style: TextStyle(
                          fontSize: 14,
                          color: _preferredDate != null ? theme.colorScheme.onSurface : theme.hintColor,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _submitting ? 'Submitting Request...' : 'Send Quotation Request',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: _submitting ? null : _submitRequest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
