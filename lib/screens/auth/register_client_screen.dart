import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/widgets/findipro_logo.dart';
import '../../main_screen.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/otp_service.dart';
import '../../services/storage_service.dart';
import 'otp_verification_screen.dart';

class RegisterClientScreen extends StatefulWidget {
  final GoogleAuthData? initialGoogleData;

  const RegisterClientScreen({super.key, this.initialGoogleData});

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
  final _googleAuth = GoogleAuthService();
  final _otpService = OtpService();

  File? _image;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  GoogleAuthData? _googleAuthData;
  String? _googlePhotoUrl;

  @override
  void initState() {
    super.initState();
    if (widget.initialGoogleData != null) {
      _applyGoogleAuthData(widget.initialGoogleData!);
    }
  }

  void _applyGoogleAuthData(GoogleAuthData data) {
    _googleAuthData = data;
    _name.text = data.name;
    _email.text = data.email;
    _googlePhotoUrl = data.photoUrl;
  }

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
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        setState(() => _image = File(picked.path));
      }
    } catch (e) {
      debugPrint('>>> [RegisterClientScreen._pickImage] Error: $e');
    }
  }

  Future<void> _handleContinueWithGoogle() async {
    setState(() => _loading = true);
    try {
      final authData = await _googleAuth.authenticateWithGoogle();
      if (authData == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (mounted) {
        setState(() {
          _applyGoogleAuthData(authData);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Connected as ${authData.email}. You can add an optional phone number below.'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('>>> [RegisterClientScreen._handleContinueWithGoogle] FirebaseAuthException: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Google sign-in failed. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint('>>> [RegisterClientScreen._handleContinueWithGoogle] Error: $e');
      if (mounted) {
        final errText = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errText.isNotEmpty ? errText : 'Google sign-in could not complete. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_googleAuthData != null) {
      // Google sign in already verified by Google
      await _performCreateAccount();
    } else {
      // Email signup: Enforce 4-digit Email OTP Verification
      setState(() => _loading = true);
      try {
        await _otpService.sendOtp(
          email: _email.text.trim(),
          name: _name.text.trim(),
        );

        if (!mounted) return;
        setState(() => _loading = false);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: _email.text.trim(),
              userName: _name.text.trim(),
              onVerified: () async {
                await _performCreateAccount();
              },
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          _show('Could not send verification code: $e');
        }
      }
    }
  }

  Future<void> _performCreateAccount() async {
    setState(() => _loading = true);

    try {
      String uid;
      String? photoUrl;
      bool photoUploadFailed = false;

      if (_googleAuthData != null) {
        // Authenticated via Google
        uid = _googleAuthData!.uid;
        photoUrl = _googlePhotoUrl;
      } else {
        // Email / Password flow
        final credential = await _auth.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
        );
        uid = credential.user!.uid;
      }

      if (_image != null) {
        try {
          photoUrl = await _storage.uploadAvatar(
            uid: uid,
            file: _image!,
          );
        } catch (e) {
          debugPrint('Profile photo upload error: $e');
          photoUploadFailed = true;
        }
      }

      // 1. Create client profile in Firestore & Supabase profiles
      await _users.createClient(
        uid: uid,
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        photoUrl: photoUrl,
      );

      // 2. Sync Supabase tables if authenticated via Google without re-authenticating
      if (_googleAuthData != null) {
        await _googleAuth.syncGoogleUserData(
          authData: _googleAuthData!,
          selectedRole: 'customer',
          phone: _phone.text.trim(),
        );
      }

      if (mounted) {
        if (photoUploadFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created successfully. Your profile photo could not be uploaded. You can add it later from Edit Profile.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account verified and created successfully! Welcome to FindiPro.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }

        // Immediately navigate to MainScreen / Dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      if (mounted) _show(e.message ?? 'Unable to create your account. Please check your details and try again.');
    } catch (e) {
      debugPrint('Registration error: $e');
      if (mounted) _show("We couldn't finish setting up your profile. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGoogleMode = _googleAuthData != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Client Account'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _loading,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 8),
                    const Center(child: FindiProLogo(height: 52)),
                    const SizedBox(height: 16),

              if (isGoogleMode) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Google Account Connected',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_googleAuthData!.email} • You can add an optional phone number below.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                OutlinedButton(
                  onPressed: _loading ? null : _handleContinueWithGoogle,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.red),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'OR FILL MANUALLY',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              Center(
                child: GestureDetector(
                  onTap: _loading ? null : _pickImage,
                  child: CircleAvatar(
                    radius: 46,
                    backgroundImage: _image != null
                        ? FileImage(_image!)
                        : (_googlePhotoUrl != null ? NetworkImage(_googlePhotoUrl!) as ImageProvider : null),
                    child: (_image == null && _googlePhotoUrl == null)
                        ? const Icon(Icons.add_a_photo, size: 28)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => v == null || v.trim().length < 2 ? 'Enter your full name' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                readOnly: isGoogleMode,
                decoration: InputDecoration(
                  labelText: 'Email',
                  suffixIcon: isGoogleMode ? const Icon(Icons.lock, size: 18, color: Colors.grey) : null,
                ),
                validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: isGoogleMode ? 'Phone number (optional)' : 'Phone number',
                ),
                validator: (v) {
                  if (isGoogleMode) {
                    if (v != null && v.trim().isNotEmpty && v.trim().length < 7) {
                      return 'Enter a valid phone number or leave empty';
                    }
                    return null;
                  }
                  return v == null || v.trim().length < 7 ? 'Enter your phone number' : null;
                },
              ),
              const SizedBox(height: 14),

              if (!isGoogleMode) ...[
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 14),
              ],

              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const CircularProgressIndicator.adaptive()
                      : Text(isGoogleMode ? 'Complete Client Registration' : 'Create account'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      if (_loading)
        Positioned.fill(
          child: Container(
            color: Colors.black.withAlpha(60),
            child: Center(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator.adaptive(),
                      const SizedBox(height: 16),
                      Text(
                        'Processing registration...',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fields are locked while securing your account',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  ),
),
);
  }
}
