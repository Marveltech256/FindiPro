import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../models/verification_request.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/verification_repository.dart';
import '../../services/location_service.dart';
import '../../services/provider_entitlement_service.dart';
import '../../services/storage_service.dart';

class ProviderPlanScreen extends StatefulWidget {
  const ProviderPlanScreen({super.key});

  @override
  State<ProviderPlanScreen> createState() => _ProviderPlanScreenState();
}

class _ProviderPlanScreenState extends State<ProviderPlanScreen> {
  final _userRepo = UserRepository();
  final _verifRepo = VerificationRepository();
  final _locationService = LocationService();

  bool _isYearly = false;
  String _selectedRegion = 'Africa';
  UserModel? _currentUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    UserModel? user;
    if (uid != null) {
      user = await _userRepo.getUser(uid);
    }

    Position? pos;
    try {
      pos = await _locationService.getCurrentLocation();
    } catch (_) {}

    final detected = ProviderEntitlementService.detectRegion(
      latitude: pos?.latitude ?? user?.latitude,
      longitude: pos?.longitude ?? user?.longitude,
      location: user?.location,
      storedRegion: user?.subscriptionRegion,
    );

    if (mounted) {
      setState(() {
        _currentUser = user;
        _selectedRegion = detected;
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _handleSubscribe(String plan) async {
    final price = ProviderEntitlementService.getPlanPrice(
      plan: plan,
      region: _selectedRegion,
    );

    final billingPeriod = _isYearly ? 'yearly' : 'monthly';
    final planTitle = plan == 'premium' ? 'FindiPro Premium' : 'FindiPro Verified';
    final priceText = _isYearly ? price.formattedYearly : price.formattedMonthly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outline.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  plan == 'premium' ? Icons.stars : Icons.verified,
                  size: 44,
                  color: plan == 'premium' ? const Color(0xFFD97706) : Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$planTitle Subscription',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Price: $priceText ($billingPeriod billing, $_selectedRegion region)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF06B6D4)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade600, width: 0.8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hourglass_top, color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'In-App Payments Coming Soon!',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Automated digital subscription payments (MTN Mobile Money, Airtel Money, Cards) are currently being finalized for launch. You will be able to upgrade directly within the app very soon!',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVerificationModal(BuildContext context, {VerificationRequest? previousRequest}) {
    final user = _currentUser;
    if (user == null) return;

    final idNumberController = TextEditingController(text: previousRequest?.nationalIdNumber ?? '');
    final formKey = GlobalKey<FormState>();
    final picker = ImagePicker();
    final storage = StorageService();

    File? idFrontFile;
    File? idBackFile;
    File? businessDocFile;
    String? existingFrontUrl = previousRequest?.idFrontUrl;
    String? existingBackUrl = previousRequest?.idBackUrl;
    String? existingDocUrl = previousRequest?.businessDocUrl;
    bool isSubmitting = false;

    Future<void> pickDoc(void Function(File) onSelected) async {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF06B6D4)),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    try {
                      final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                      if (x != null) onSelected(File(x.path));
                    } catch (e) {
                      debugPrint('Camera error: $e');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF06B6D4)),
                  title: const Text('Choose from Photo Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    try {
                      final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (x != null) onSelected(File(x.path));
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final theme = Theme.of(modalCtx);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline.withAlpha(80),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.verified_user_outlined, color: Color(0xFF06B6D4), size: 26),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              previousRequest?.status == 'rejected' ? 'Resubmit Verification' : 'Provider Identity Verification',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Upload your National ID or government-issued identification to earn the Blue Verified badge. All documents are stored in private encrypted storage.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: idNumberController,
                        decoration: const InputDecoration(
                          labelText: 'National ID / Passport Number',
                          hintText: 'e.g. CM1234567890AB',
                          prefixIcon: Icon(Icons.credit_card_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your ID number' : null,
                      ),
                      const SizedBox(height: 16),

                      // Document Upload Cards
                      const Text(
                        'National ID Photos (Required Front, Optional Back):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // ID Front
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => pickDoc((f) => setModalState(() => idFrontFile = f)),
                              child: Container(
                                height: 95,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (idFrontFile != null || existingFrontUrl != null)
                                        ? const Color(0xFF10B981)
                                        : theme.colorScheme.outline.withAlpha(50),
                                  ),
                                ),
                                child: idFrontFile != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(idFrontFile!, fit: BoxFit.cover),
                                      )
                                    : (existingFrontUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(existingFrontUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.check_circle, color: Colors.green)),
                                          )
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.add_a_photo_outlined, color: Color(0xFF06B6D4), size: 26),
                                              const SizedBox(height: 4),
                                              const Text('ID Front *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              const Text('Camera / Gallery', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                            ],
                                          )),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // ID Back
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => pickDoc((f) => setModalState(() => idBackFile = f)),
                              child: Container(
                                height: 95,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (idBackFile != null || existingBackUrl != null)
                                        ? const Color(0xFF10B981)
                                        : theme.colorScheme.outline.withAlpha(50),
                                  ),
                                ),
                                child: idBackFile != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(idBackFile!, fit: BoxFit.cover),
                                      )
                                    : (existingBackUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(existingBackUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.check_circle, color: Colors.green)),
                                          )
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.flip_to_back_outlined, color: Color(0xFF06B6D4), size: 26),
                                              const SizedBox(height: 4),
                                              const Text('ID Back (Optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              const Text('Camera / Gallery', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                            ],
                                          )),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Business Document (Optional)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => pickDoc((f) => setModalState(() => businessDocFile = f)),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (businessDocFile != null || existingDocUrl != null)
                                  ? const Color(0xFF10B981)
                                  : theme.colorScheme.outline.withAlpha(40),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (businessDocFile != null || existingDocUrl != null)
                                    ? Icons.check_circle
                                    : Icons.business_center_outlined,
                                color: (businessDocFile != null || existingDocUrl != null)
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF06B6D4),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Business Registration / License (Optional)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    Text(
                                      businessDocFile != null
                                          ? 'Document selected: ${businessDocFile!.path.split(Platform.pathSeparator).last}'
                                          : (existingDocUrl != null ? 'Previous document attached' : 'Tap to take photo or upload from Gallery'),
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  if (idFrontFile == null && existingFrontUrl == null) {
                                    ScaffoldMessenger.of(modalCtx).showSnackBar(
                                      const SnackBar(content: Text('Please take a photo or select your ID document (Front).')),
                                    );
                                    return;
                                  }

                                  setModalState(() => isSubmitting = true);

                                  try {
                                    String? frontUrl = existingFrontUrl;
                                    String? backUrl = existingBackUrl;
                                    String? docUrl = existingDocUrl;

                                    if (idFrontFile != null) {
                                      frontUrl = await storage.uploadDocument(
                                        uid: user.uid,
                                        file: idFrontFile!,
                                        docType: 'id_front',
                                      );
                                    }

                                    if (idBackFile != null) {
                                      backUrl = await storage.uploadDocument(
                                        uid: user.uid,
                                        file: idBackFile!,
                                        docType: 'id_back',
                                      );
                                    }

                                    if (businessDocFile != null) {
                                      docUrl = await storage.uploadDocument(
                                        uid: user.uid,
                                        file: businessDocFile!,
                                        docType: 'business_doc',
                                      );
                                    }

                                    final req = VerificationRequest(
                                      id: previousRequest?.id ?? '',
                                      providerId: user.uid,
                                      providerName: user.name.isNotEmpty ? user.name : (user.businessName ?? 'Provider'),
                                      nationalIdNumber: idNumberController.text.trim(),
                                      idFrontUrl: frontUrl,
                                      idBackUrl: backUrl,
                                      businessDocUrl: docUrl,
                                      status: 'pending',
                                      createdAt: DateTime.now(),
                                    );

                                    await _verifRepo.submitRequest(req);
                                    if (modalCtx.mounted) {
                                      Navigator.pop(modalCtx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('National ID & verification documents submitted! Under review by admin.'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                    _loadUser();
                                  } catch (e) {
                                    if (modalCtx.mounted) {
                                      setModalState(() => isSubmitting = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Submission failed: $e')),
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Submit for Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIdentityVerificationSection(BuildContext context, ThemeData theme) {
    final user = _currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<VerificationRequest?>(
      stream: _verifRepo.watchLatestRequestForProvider(user.uid),
      builder: (context, snapshot) {
        final req = snapshot.data;
        final status = (req?.status ?? user.verificationStatus ?? 'unverified').toLowerCase();
        final isApproved = status == 'approved' || user.isVerifiedBadge;
        final isPending = status == 'pending';
        final isRejected = status == 'rejected';

        Color cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
        Color accentColor = const Color(0xFF06B6D4);
        IconData statusIcon = Icons.shield_outlined;
        String statusTitle = 'Identity Verification';
        String statusDesc = 'Submit your National ID and business qualifications to obtain the Blue Verification badge.';

        if (isApproved) {
          cardBg = Colors.blue.withAlpha(20);
          accentColor = Colors.blue;
          statusIcon = Icons.verified;
          statusTitle = 'Identity Verified';
          statusDesc = 'Your identity and business documents have been approved by admin. Your Blue Verified Trust badge is active.';
        } else if (isPending) {
          cardBg = Colors.orange.withAlpha(20);
          accentColor = Colors.orange;
          statusIcon = Icons.schedule;
          statusTitle = 'Verification Under Review';
          statusDesc = 'Your verification application is currently under review by our admin team. You will be notified once approved.';
        } else if (isRejected) {
          cardBg = Colors.red.withAlpha(20);
          accentColor = Colors.red;
          statusIcon = Icons.error_outline;
          statusTitle = 'Verification Rejected';
          final reason = (req?.notes != null && req!.notes!.isNotEmpty) ? req.notes! : 'Documents were unclear or did not meet requirements.';
          statusDesc = 'Reason: $reason\nPlease review your documents and resubmit.';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: accentColor, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                statusDesc,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              if (!isApproved) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(isRejected ? Icons.refresh : (isPending ? Icons.edit_document : Icons.upload_file), size: 18),
                    label: Text(
                      isRejected ? 'Resubmit Verification Documents' : (isPending ? 'Update Submitted Documents' : 'Apply for Identity Verification'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showVerificationModal(context, previousRequest: req),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtleBorder = theme.colorScheme.outline.withAlpha(50);
    final currentPlan = _currentUser?.effectivePlan ?? 'basic';

    final verifiedPrice = ProviderEntitlementService.getPlanPrice(
      plan: 'verified',
      region: _selectedRegion,
    );

    final premiumPrice = ProviderEntitlementService.getPlanPrice(
      plan: 'premium',
      region: _selectedRegion,
    );

    final regionCurrencyLabel = _selectedRegion == 'Europe'
        ? 'Europe (EUR)'
        : (_selectedRegion == 'USA' ? 'USA (USD)' : 'Africa (UGX)');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Plans & Badges'),
      ),
      body: _isLoadingUser
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Current Plan Status Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: currentPlan == 'premium'
                            ? const Color(0xFFD97706)
                            : (currentPlan == 'verified' ? Colors.blue : Colors.grey.shade700),
                        child: Icon(
                          currentPlan == 'premium'
                              ? Icons.stars
                              : (currentPlan == 'verified' ? Icons.verified : Icons.person),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your FindiPro Plan',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentPlan == 'premium'
                                  ? 'FindiPro Premium'
                                  : (currentPlan == 'verified' ? 'FindiPro Verified' : 'Basic (Free)'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          regionCurrencyLabel,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Identity Verification Status & Actions
                _buildIdentityVerificationSection(context, theme),
                const SizedBox(height: 20),

                // 2. Billing Period Toggle: Monthly / Yearly (Save 20%)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isYearly = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isYearly ? (theme.cardTheme.color ?? theme.colorScheme.surface) : Colors.transparent,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: !_isYearly
                                  ? [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Monthly',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: !_isYearly ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isYearly = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isYearly ? (theme.cardTheme.color ?? theme.colorScheme.surface) : Colors.transparent,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: _isYearly
                                  ? [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Yearly',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _isYearly ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withAlpha(150),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Save 20%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. BASIC PLAN CARD
                _buildPlanCard(
                  title: 'Basic',
                  price: 'Free',
                  badgeWidget: null,
                  isCurrent: currentPlan == 'basic',
                  buttonText: currentPlan == 'basic' ? 'Current Plan' : 'Standard Tier',
                  buttonAction: null,
                  cardColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                  borderColor: currentPlan == 'basic'
                      ? const Color(0xFF06B6D4)
                      : subtleBorder,
                  features: const [
                    'Create provider profile',
                    'List services',
                    'Receive enquiries & hire requests',
                    'In-app messaging & reviews',
                    'Standard search & location discovery',
                    'Up to 2 portfolio images',
                    'No verification badge',
                  ],
                ),
                const SizedBox(height: 16),

                // 4. FINDIPRO VERIFIED PLAN CARD
                _buildPlanCard(
                  title: 'FindiPro Verified',
                  price: _isYearly ? verifiedPrice.formattedYearly : verifiedPrice.formattedMonthly,
                  savingText: _isYearly ? verifiedPrice.formattedSaving : null,
                  badgeWidget: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.blue, size: 18),
                      SizedBox(width: 4),
                      Text('Blue Badge', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  isCurrent: currentPlan == 'verified',
                  buttonText: currentPlan == 'verified' ? 'Renew / Extend' : 'Get Verified',
                  buttonAction: () => _handleSubscribe('verified'),
                  cardColor: Colors.blue.withAlpha(15),
                  borderColor: currentPlan == 'verified' ? Colors.green : Colors.blue.withAlpha(80),
                  features: const [
                    'Blue Verified Trust Badge',
                    'Identity & business verification status',
                    'Higher customer trust presentation',
                    'Up to 5 portfolio/work images',
                    'Priority FindiPro support',
                    'All core messaging & request features',
                  ],
                ),
                const SizedBox(height: 16),

                // 5. FINDIPRO PREMIUM PLAN CARD
                _buildPlanCard(
                  title: 'FindiPro Premium',
                  price: _isYearly ? premiumPrice.formattedYearly : premiumPrice.formattedMonthly,
                  savingText: _isYearly ? premiumPrice.formattedSaving : null,
                  badgeWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars, color: Colors.amber.shade700, size: 18),
                      const SizedBox(width: 4),
                      Text('Golden Badge', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  isCurrent: currentPlan == 'premium',
                  buttonText: currentPlan == 'premium'
                      ? 'Renew / Extend'
                      : 'Upgrade to Premium',
                  buttonAction: () => _handleSubscribe('premium'),
                  cardColor: Colors.amber.withAlpha(18),
                  borderColor: currentPlan == 'premium' ? Colors.amber.shade700 : Colors.amber.shade300,
                  features: const [
                    'Golden Premium VIP Badge',
                    'All Verified benefits included',
                    'Priority ranking in marketplace search',
                    'Featured placement & promotion',
                    'Up to 10 portfolio/work images',
                    'Detailed analytics dashboard',
                    'Unlimited service listings & promotional tools',
                    'Priority instant support',
                  ],
                ),
                const SizedBox(height: 28),

                // 6. FEATURE COMPARISON TABLE
                const Text(
                  'Plan Comparison',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _buildComparisonTable(),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    String? savingText,
    required Widget? badgeWidget,
    required bool isCurrent,
    required String buttonText,
    required VoidCallback? buttonAction,
    required Color cardColor,
    required Color borderColor,
    required List<String> features,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (badgeWidget != null) ...[
                badgeWidget,
                const SizedBox(width: 8),
              ],
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
              ),
              if (savingText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    savingText,
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: theme.colorScheme.outline.withAlpha(40)),
          const SizedBox(height: 14),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withAlpha(220)),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? Colors.grey.shade400 : const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: buttonAction,
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    final theme = Theme.of(context);
    final subtleBorder = theme.colorScheme.outline.withAlpha(50);

    final rows = [
      {'feature': 'Provider profile', 'basic': '✓', 'verified': '✓', 'premium': '✓'},
      {'feature': 'List services', 'basic': '✓', 'verified': '✓', 'premium': '✓'},
      {'feature': 'Receive enquiries', 'basic': '✓', 'verified': '✓', 'premium': '✓'},
      {'feature': 'Hire requests', 'basic': '✓', 'verified': '✓', 'premium': '✓'},
      {'feature': 'Messaging', 'basic': '✓', 'verified': '✓', 'premium': '✓'},
      {'feature': 'Customer reviews', 'basic': '✓', 'verified': '✓', 'premium': '✓'},
      {'feature': 'Blue Verified Badge', 'basic': '✗', 'verified': '✓', 'premium': '✗'},
      {'feature': 'Golden VIP Badge', 'basic': '✗', 'verified': '✗', 'premium': '✓'},
      {'feature': 'Identity Verification', 'basic': '✗', 'verified': '✓', 'premium': '✓'},
      {'feature': 'Portfolio Images', 'basic': '2', 'verified': '5', 'premium': '10'},
      {'feature': 'Priority Ranking', 'basic': '✗', 'verified': '✗', 'premium': '✓'},
      {'feature': 'Featured Placement', 'basic': '✗', 'verified': '✗', 'premium': '✓'},
      {'feature': 'Analytics Dashboard', 'basic': '✗', 'verified': '✗', 'premium': '✓'},
      {'feature': 'Unlimited Services', 'basic': '✗', 'verified': '✗', 'premium': '✓'},
      {'feature': 'Promotional Tools', 'basic': '✗', 'verified': '✗', 'premium': '✓'},
      {'feature': 'Priority Support', 'basic': '✗', 'verified': '✓', 'premium': '✓'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: subtleBorder),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(1.0),
          2: FlexColumnWidth(1.0),
          3: FlexColumnWidth(1.0),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text('Feature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Text('Basic', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Text('Verified', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Text('Premium', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD97706))),
              ),
            ],
          ),
          ...rows.map(
            (r) => TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: subtleBorder)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(r['feature']!, style: const TextStyle(fontSize: 12)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    r['basic']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: r['basic'] == '✗' ? Colors.grey.shade400 : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    r['verified']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: r['verified'] == '✗' ? Colors.grey.shade400 : Colors.blue,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    r['premium']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: r['premium'] == '✗' ? Colors.grey.shade400 : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}