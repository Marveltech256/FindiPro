import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/config/supabase_config.dart';
import '../../models/user_model.dart';
import '../../repositories/booking_repository.dart';
import '../../repositories/message_repository.dart';

class RequestHireScreen extends StatefulWidget {
  final UserModel provider;

  const RequestHireScreen({super.key, required this.provider});

  @override
  State<RequestHireScreen> createState() => _RequestHireScreenState();
}

class _RequestHireScreenState extends State<RequestHireScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _service = TextEditingController();
  final _budget = TextEditingController();
  final _notes = TextEditingController();
  final _bookingRepo = BookingRepository();
  final _messageRepo = MessageRepository();

  DateTime? _date;
  TimeOfDay? _time;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    _name.text = u?.displayName ?? '';
    _phone.text = u?.phoneNumber ?? '';
    _service.text = widget.provider.category ?? 'Service';
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _location, _service, _budget, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a request.')),
      );
      return;
    }

    if (!_form.currentState!.validate()) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your preferred date.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      DateTime scheduledDateTime = _date!;
      if (_time != null) {
        scheduledDateTime = DateTime(
          _date!.year,
          _date!.month,
          _date!.day,
          _time!.hour,
          _time!.minute,
        );
      }

      final notesCombined = StringBuffer(_notes.text.trim());
      if (_time != null) {
        notesCombined.write(' [Preferred Time: ${_time!.format(context)}]');
      }
      if (_budget.text.trim().isNotEmpty) {
        notesCombined.write(' [Estimated Budget: ${_budget.text.trim()}]');
      }

      await _bookingRepo.createHireRequest({
        'clientId': user.uid,
        'clientName': _name.text.trim(),
        'clientPhone': _phone.text.trim(),
        'providerId': widget.provider.uid,
        'providerName': widget.provider.name,
        'serviceNeeded': _service.text.trim(),
        'location': _location.text.trim(),
        'requestedDate': scheduledDateTime.toUtc().toIso8601String(),
        'notes': notesCombined.toString().trim(),
        'status': 'requested',
      });

      // Send in-app message connecting the hire request
      try {
        final initialMessage = 'Hi ${widget.provider.name}, I requested a ${_service.text.trim()} service for ${_date!.day}/${_date!.month}/${_date!.year}. Location: ${_location.text.trim()}.';
        await _messageRepo.sendMessage(
          senderId: user.uid,
          receiverId: widget.provider.uid,
          text: initialMessage,
        );
      } catch (_) {}

      // Send notification via Supabase notifications table
      try {
        await SupabaseConfig.client.from('notifications').insert({
          'user_id': widget.provider.uid,
          'title': 'New Service Request',
          'body': 'You received a new hire request from ${_name.text.trim().isEmpty ? 'a client' : _name.text.trim()} for ${_service.text.trim()}.',
          'is_read': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted successfully!'),
            backgroundColor: Color(0xFF06B6D4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('>>> [RequestHireScreen._submit] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to submit request. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Service / Hire')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Provider header card
              Card(
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: widget.provider.photoUrl != null && widget.provider.photoUrl!.isNotEmpty
                              ? Image.network(
                                  widget.provider.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.person, color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.person, color: Colors.grey),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.provider.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Text(
                              widget.provider.category ?? 'Service Provider',
                              style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              TextFormField(
                controller: _service,
                decoration: const InputDecoration(
                  labelText: 'Service needed *',
                  hintText: 'e.g. Plumbing Repair, House Cleaning',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter the service needed' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Your full name *',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number *',
                ),
                validator: (v) => v == null || v.trim().length < 7 ? 'Enter a valid phone number' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Service location / address *',
                  hintText: 'e.g. Kololo, Kampala',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter your location' : null,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(_date == null ? 'Select Date *' : '${_date!.day}/${_date!.month}/${_date!.year}'),
                      onPressed: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(_time == null ? 'Select Time' : _time!.format(context)),
                      onPressed: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _budget,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Estimated budget (optional)',
                  hintText: 'e.g. 50,000 UGX',
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional details / description',
                  hintText: 'Describe the issue or any specific requirements...',
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Submit Request',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
