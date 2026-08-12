import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../repositories/user_repository.dart';

class RegisterClientScreen extends StatefulWidget {
  const RegisterClientScreen({super.key});
  @override
  State<RegisterClientScreen> createState() => _RegisterClientScreenState();
}

class _RegisterClientScreenState extends State<RegisterClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _picker = ImagePicker();
  final _storage = StorageService();
  final _users = UserRepository();
  final _auth = AuthService();
  File? _image;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600, maxHeight: 1600);
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final credential = await _auth.register(name: _name.text, email: _email.text, phone: _phone.text, password: _password.text);
      final uid = credential.user!.uid;
      String? photoUrl;
      if (_image != null) {
        try {
          photoUrl = await _storage.uploadImage(file: _image!, path: 'users/$uid/profile/profile.jpg');
        } catch (_) {
          // Silently fail on image upload, but proceed with registration
        }
      }
      await _users.createClient(uid: uid, name: _name.text.trim(), email: _email.text.trim(), phone: _phone.text.trim(), photoUrl: photoUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created successfully.')));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _show(e.message ?? 'Registration failed.');
    } catch (e) {
      if (mounted) _show('Registration failed. Make sure Firebase Storage is enabled if you selected a photo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Create Client Account')),
        body: SafeArea(
            child: Form(
                key: _formKey,
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  Center(
                      child: GestureDetector(
                          onTap: _loading ? null : _pickImage,
                          child: CircleAvatar(
                              radius: 54,
                              backgroundImage: _image == null ? null : FileImage(_image!),
                              child: _image == null ? const Icon(Icons.add_a_photo, size: 32) : null))),
                  const SizedBox(height: 24),
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => v == null || v.trim().length < 2 ? 'Enter your full name' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number'), validator: (v) => v == null || v.trim().length < 7 ? 'Enter your phone number' : null),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off))),
                      validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _confirm,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(labelText: 'Confirm password', suffixIcon: IconButton(onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm), icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off))),
                      validator: (v) => v != _password.text ? 'Passwords do not match' : null),
                  const SizedBox(height: 24),
                  SizedBox(height: 52, child: ElevatedButton(onPressed: _loading ? null : _register, child: _loading ? const CircularProgressIndicator.adaptive() : const Text('Create account'))),
                ]))));
  }
}
