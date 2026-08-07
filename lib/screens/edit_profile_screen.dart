import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:findipro/services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _aboutController;

  bool _isLoading = false;
  bool get _isProvider => widget.userData['role'] == 'provider';

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.userData['fullName']);
    _phoneController = TextEditingController(text: widget.userData['phone']);
    if (_isProvider) {
      _locationController = TextEditingController(text: widget.userData['location']);
      _aboutController = TextEditingController(text: widget.userData['about']);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    if (_isProvider) {
      _locationController.dispose();
      _aboutController.dispose();
    }
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() { _isLoading = true; });
      
      final uid = _authService.currentUser!.uid;
      final collection = _isProvider ? 'providers' : 'clients';

      Map<String, dynamic> dataToUpdate = {
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      if (_isProvider) {
        dataToUpdate.addAll({
          'location': _locationController.text.trim(),
          'about': _aboutController.text.trim(),
        });
      }

      try {
        await _firestore.collection(collection).doc(uid).update(dataToUpdate);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
        }
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _fullNameController, decoration: const InputDecoration(labelText: 'Full Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number'), keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Required' : null),
              if (_isProvider) ...[
                const SizedBox(height: 16),
                TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location'), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _aboutController, decoration: const InputDecoration(labelText: 'About / Bio'), maxLines: 3, validator: (v) => v!.isEmpty ? 'Required' : null),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}