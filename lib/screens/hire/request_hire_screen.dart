import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';

class RequestHireScreen extends StatefulWidget {
  final UserModel provider; const RequestHireScreen({super.key,required this.provider});
  @override State<RequestHireScreen> createState()=>_RequestHireScreenState();
}
class _RequestHireScreenState extends State<RequestHireScreen>{
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _service = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _date;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    _name.text = u?.displayName ?? '';
    _phone.text = u?.phoneNumber ?? '';
    _service.text = widget.provider.category ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _location, _service, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login before requesting a hire.')));
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select your preferred date.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('hire_requests').add({
        'clientId': user.uid,
        'clientName': _name.text.trim(),
        'clientPhone': _phone.text.trim(),
        'providerId': widget.provider.uid,
        'providerName': widget.provider.name,
        'serviceNeeded': _service.text.trim(),
        'location': _location.text.trim(),
        'requestedDate': Timestamp.fromDate(_date!),
        'notes': _notes.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });

      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId': widget.provider.uid,
        'title': 'New Hire Request',
        'body': 'You received a new request from ${user.displayName}.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create a conversation for messaging
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc('${user.uid}_${widget.provider.uid}')
          .set({
        'clientId': user.uid,
        'providerId': widget.provider.uid,
        'participants': [user.uid, widget.provider.uid],
        'lastMessage': 'Hire request sent',
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hire request sent successfully.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send your request. Please try again.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Request to Hire')),
        body: SafeArea(
            child: Form(
                key: _form,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Text('Hiring ${widget.provider.name}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null),
                  const SizedBox(height: 14),
                  TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number'), validator: (v) => v == null || v.trim().length < 7 ? 'Enter your phone number' : null),
                  const SizedBox(height: 14),
                  TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Your location'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter your location' : null),
                  const SizedBox(height: 14),
                  TextFormField(controller: _service, decoration: const InputDecoration(labelText: 'Service needed'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter the service needed' : null),
                  const SizedBox(height: 14),
                  ListTile(contentPadding: EdgeInsets.zero, title: Text(_date == null ? 'Preferred date' : '${_date!.day}/${_date!.month}/${_date!.year}'), leading: const Icon(Icons.calendar_today), trailing: TextButton(onPressed: _pickDate, child: const Text('Choose'))),
                  TextFormField(controller: _notes, maxLines: 4, decoration: const InputDecoration(labelText: 'Additional notes')),
                  const SizedBox(height: 24),
                  SizedBox(height: 54, child: ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const CircularProgressIndicator.adaptive() : const Text('Send Request')))
                ]))));
  }
}
