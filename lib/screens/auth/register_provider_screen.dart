import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/widgets/findipro_logo.dart';
import '../../models/verification_request.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/verification_repository.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/location_service.dart';
import '../../services/otp_service.dart';
import '../../services/storage_service.dart';
import '../provider/provider_dashboard_screen.dart';
import 'otp_verification_screen.dart';

class RegisterProviderScreen extends StatefulWidget {
  final GoogleAuthData? initialGoogleData;

  const RegisterProviderScreen({super.key, this.initialGoogleData});

  @override
  State<RegisterProviderScreen> createState() => _RegisterProviderScreenState();
}

class _RegisterProviderScreenState extends State<RegisterProviderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _about = TextEditingController();
  final _price = TextEditingController();
  final _skills = TextEditingController();
  final _business = TextEditingController();
  final _years = TextEditingController();
  final _nationalIdNumber = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _categories = const [
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Mechanic',
    'Painting',
    'Gardening',
    'Carpentry',
    'Moving',
    'Beauty',
    'Construction',
    'IT & Technology',
    'Household Items',
    'Other',
  ];

  String? _category;
  final String _plan = 'basic'; // 'basic' | 'pro' | 'premium'
  File? _image;
  File? _idFrontImage;
  File? _idBackImage;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  GoogleAuthData? _googleAuthData;
  String? _googlePhotoUrl;

  final _picker = ImagePicker();
  final _auth = AuthService();
  final _storage = StorageService();
  final _users = UserRepository();
  final _verifRepo = VerificationRepository();
  final _locationService = LocationService();
  final _googleAuth = GoogleAuthService();
  final _otpService = OtpService();
  final _currencyService = CurrencyService();

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
    for (final c in [
      _name,
      _email,
      _phone,
      _location,
      _about,
      _price,
      _skills,
      _business,
      _years,
      _nationalIdNumber,
      _password,
      _confirm
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(void Function(File) onSelected) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF06B6D4)),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                    if (x != null && mounted) {
                      onSelected(File(x.path));
                    }
                  } catch (e) {
                    debugPrint('Camera error: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF06B6D4)),
                title: const Text('Choose from Photo Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (x != null && mounted) {
                      onSelected(File(x.path));
                    }
                  } catch (e) {
                    debugPrint('Gallery error: $e');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
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
            content: Text('✓ Connected as ${authData.email}. Please complete your phone, category, and location below.'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('>>> [RegisterProviderScreen._handleContinueWithGoogle] FirebaseAuthException: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Google sign-in failed. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint('>>> [RegisterProviderScreen._handleContinueWithGoogle] Error: $e');
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
      await _performCreateProviderAccount();
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
                await _performCreateProviderAccount();
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

  Future<void> _performCreateProviderAccount() async {
    setState(() => _loading = true);

    try {
      String uid;
      String? photoUrl;
      bool photoUploadFailed = false;

      if (_googleAuthData != null) {
        // Registered via Google Authentication
        uid = _googleAuthData!.uid;
        photoUrl = _googlePhotoUrl;
      } else {
        // Standard email/password registration
        final credential = await _auth.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
          role: 'provider',
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
          debugPrint('Provider photo upload error: $e');
          photoUploadFailed = true;
        }
      }

      // Upload National ID Documents if provided
      String? idFrontUrl;
      String? idBackUrl;

      if (_idFrontImage != null) {
        try {
          idFrontUrl = await _storage.uploadDocument(
            uid: uid,
            file: _idFrontImage!,
            docType: 'id_front',
          );
        } catch (e) {
          debugPrint('ID Front upload error: $e');
        }
      }

      if (_idBackImage != null) {
        try {
          idBackUrl = await _storage.uploadDocument(
            uid: uid,
            file: _idBackImage!,
            docType: 'id_back',
          );
        } catch (e) {
          debugPrint('ID Back upload error: $e');
        }
      }

      Position? pos;
      try {
        pos = await _locationService.getCurrentLocation();
      } catch (_) {}

      final skills = _skills.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // 1. Create provider profile (Instantly Free Premium & Verified)
      await _users.createProvider(
        uid: uid,
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        category: _category!,
        location: _location.text.trim(),
        yearsExperience: int.tryParse(_years.text.trim()) ?? 0,
        about: _about.text.trim(),
        bio: _about.text.trim(),
        skills: skills,
        priceRange: _price.text.trim(),
        available: true,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        photoUrl: photoUrl,
        businessName: _business.text.trim().isEmpty ? null : _business.text.trim(),
      );

      // 2. If Google authentication was used, update Supabase provider details without re-authenticating
      if (_googleAuthData != null) {
        await _googleAuth.syncGoogleUserData(
          authData: _googleAuthData!,
          selectedRole: 'provider',
          category: _category,
          phone: _phone.text.trim(),
          location: _location.text.trim(),
          about: _about.text.trim(),
          businessName: _business.text.trim().isEmpty ? null : _business.text.trim(),
        );
      }

      // 3. Record verification request if National ID was uploaded
      if (idFrontUrl != null) {
        try {
          final req = VerificationRequest(
            id: '',
            providerId: uid,
            providerName: _name.text.trim().isNotEmpty ? _name.text.trim() : (_business.text.trim().isNotEmpty ? _business.text.trim() : 'Provider'),
            nationalIdNumber: _nationalIdNumber.text.trim().isNotEmpty ? _nationalIdNumber.text.trim() : 'Submitted via App',
            idFrontUrl: idFrontUrl,
            idBackUrl: idBackUrl,
            businessDocUrl: null,
            status: 'pending',
            createdAt: DateTime.now(),
          );
          await _verifRepo.submitRequest(req);
        } catch (e) {
          debugPrint('Verification request auto-submit note: $e');
        }
      }

      if (mounted) {
        if (photoUploadFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Provider account created. Your photo could not be uploaded, but you can add it from Edit Profile.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Provider account verified and created successfully! (Limited Promotional Trial active)'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }

        // Immediately navigate directly to ProviderDashboardScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProviderDashboardScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException in provider reg: ${e.code} - ${e.message}');
      if (mounted) {
        _show(e.message ?? 'Unable to create your account. Please check your details and try again.');
      }
    } catch (e) {
      debugPrint('Provider registration error: $e');
      if (mounted) {
        _show("We couldn't finish setting up your profile. Please try again.");
      }
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
        title: const Text('Become a Service Provider'),
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
                    color: const Color(0xFF10B981).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Authenticated with Google',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _googleAuthData!.email,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.outline.withAlpha(80)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _loading ? null : _handleContinueWithGoogle,
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      height: 20,
                      width: 20,
                      errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.colorScheme.outline.withAlpha(50))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or complete registration manually',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(child: Divider(color: theme.colorScheme.outline.withAlpha(50))),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Profile Avatar
              Center(
                child: GestureDetector(
                  onTap: () => _pickImage((f) => setState(() => _image = f)),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(0xFF06B6D4).withAlpha(30),
                        backgroundImage: _image != null
                            ? FileImage(_image!)
                            : (_googlePhotoUrl != null ? NetworkImage(_googlePhotoUrl!) : null) as ImageProvider?,
                        child: (_image == null && _googlePhotoUrl == null)
                            ? const Icon(Icons.person, size: 46, color: Color(0xFF06B6D4))
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFF06B6D4),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Upload Profile Photo (Optional)',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => v == null || v.trim().length < 2 ? 'Enter your name' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _business,
                decoration: const InputDecoration(
                  labelText: 'Business / Company Name (Optional)',
                  hintText: 'e.g. QuickFix Electricals',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                readOnly: isGoogleMode,
                decoration: InputDecoration(
                  labelText: 'Email Address *',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: isGoogleMode ? const Icon(Icons.lock, size: 18, color: Colors.grey) : null,
                ),
                validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone / WhatsApp *', prefixIcon: Icon(Icons.phone_outlined)),
                validator: (v) => v == null || v.trim().length < 7 ? 'Enter a valid phone number' : null,
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Profession / Service Category *', prefixIcon: Icon(Icons.category_outlined)),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: _loading ? null : (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Select your profession' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Service Location / Area *', prefixIcon: Icon(Icons.location_on_outlined)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter your service area' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _years,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Years of Experience *', prefixIcon: Icon(Icons.timeline_outlined)),
                validator: (v) => v == null || int.tryParse(v) == null ? 'Enter years of experience' : null,
              ),
              const SizedBox(height: 14),

              // Auto-converted pricing range with dynamic IP currency detection
              ListenableBuilder(
                listenable: _currencyService,
                builder: (context, _) {
                  final cur = _currencyService.currentCurrency;
                  return TextFormField(
                    controller: _price,
                    decoration: InputDecoration(
                      labelText: 'Price / Rate Range (${cur.symbol} / ${cur.code})',
                      hintText: cur.code == 'UGX'
                          ? 'e.g. UGX 30,000 - 100,000'
                          : 'e.g. ${cur.symbol}20 - ${cur.symbol}60 / hour',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      helperText: 'Auto-converted based on local IP currency: ${cur.country} (${cur.code})',
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _skills,
                decoration: const InputDecoration(labelText: 'Skills / Services (comma separated)', prefixIcon: Icon(Icons.build_outlined)),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _about,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'About Your Professional Service *',
                  alignLabelWithHint: true,
                ),
                validator: (v) => v == null || v.trim().length < 15
                    ? 'Tell clients a little more about your service (minimum 15 characters)'
                    : null,
              ),
              const SizedBox(height: 20),


              // ==============================================================
              // NATIONAL ID VERIFICATION SECTION
              // Only shown for Pro & Premium plan users (not Basic)
              // ==============================================================
              if (_plan == 'pro' || _plan == 'premium') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge_outlined, color: Color(0xFF06B6D4), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'National ID / Identity Verification',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload your National ID to verify your identity (optional). You can take a photo with your Camera or pick from Gallery.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nationalIdNumber,
                        decoration: const InputDecoration(
                          labelText: 'National ID / Passport Number (Optional)',
                          hintText: 'e.g. CM1234567890AB',
                          prefixIcon: Icon(Icons.credit_card_outlined),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // ID Front
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _pickImage((f) => setState(() => _idFrontImage = f)),
                              child: Container(
                                height: 90,
                                decoration: BoxDecoration(
                                  color: theme.cardTheme.color ?? theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _idFrontImage != null ? const Color(0xFF10B981) : theme.colorScheme.outline.withAlpha(50),
                                  ),
                                ),
                                child: _idFrontImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(_idFrontImage!, fit: BoxFit.cover),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_a_photo_outlined, color: const Color(0xFF06B6D4), size: 26),
                                          const SizedBox(height: 4),
                                          const Text('ID Front', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          const Text('Camera / Gallery', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // ID Back
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _pickImage((f) => setState(() => _idBackImage = f)),
                              child: Container(
                                height: 90,
                                decoration: BoxDecoration(
                                  color: theme.cardTheme.color ?? theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _idBackImage != null ? const Color(0xFF10B981) : theme.colorScheme.outline.withAlpha(50),
                                  ),
                                ),
                                child: _idBackImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(_idBackImage!, fit: BoxFit.cover),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.flip_to_back_outlined, color: const Color(0xFF06B6D4), size: 26),
                                          const SizedBox(height: 4),
                                          const Text('ID Back (Optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          const Text('Camera / Gallery', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],


              if (!isGoogleMode) ...[
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
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
                    labelText: 'Confirm Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 24),
              ],

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const CircularProgressIndicator.adaptive(backgroundColor: Colors.white)
                      : const Text(
                          'Create Provider Account',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
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
