import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../../services/location_service.dart';
import '../../services/provider_entitlement_service.dart';
import '../../services/storage_service.dart';
import '../provider/provider_plan_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String location;
  final String? photoUrl;

  const EditProfileScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.location,
    this.photoUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _location;
  late final TextEditingController _businessName;
  late final TextEditingController _about;
  late final TextEditingController _yearsExp;
  late final TextEditingController _priceRange;
  late final TextEditingController _skillInput;

  final _userRepo = UserRepository();
  final _storage = StorageService();
  final _picker = ImagePicker();
  final _locationService = LocationService();

  File? _newImage;
  bool _loading = false;
  bool _uploadingPortfolio = false;
  bool _detectingLocation = false;
  UserModel? _user;

  String? _category;
  bool _available = true;
  List<String> _skills = [];
  double? _latitude;
  double? _longitude;

  static const _categories = [
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
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _phone = TextEditingController(text: widget.phone);
    _location = TextEditingController(text: widget.location);
    _businessName = TextEditingController();
    _about = TextEditingController();
    _yearsExp = TextEditingController();
    _priceRange = TextEditingController();
    _skillInput = TextEditingController();

    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final u = await _userRepo.getUser(uid);
      if (mounted && u != null) {
        setState(() {
          _user = u;
          _businessName.text = u.businessName ?? '';
          _about.text = u.about?.isNotEmpty == true ? u.about! : (u.bio ?? '');
          _yearsExp.text = u.yearsExperience > 0 ? u.yearsExperience.toString() : '';
          _priceRange.text = u.priceRange;
          _category = u.category;
          _available = u.available;
          _skills = List<String>.from(u.skills);
          _latitude = u.latitude;
          _longitude = u.longitude;
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    _businessName.dispose();
    _about.dispose();
    _yearsExp.dispose();
    _priceRange.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        setState(() => _newImage = File(picked.path));
      }
    } catch (e) {
      debugPrint('>>> [EditProfileScreen._pickImage] Error: $e');
    }
  }

  Future<void> _detectGpsLocation() async {
    setState(() => _detectingLocation = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          if (_location.text.trim().isEmpty) {
            _location.text = 'Kampala (GPS Detected)';
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS coordinates captured successfully.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not retrieve GPS coordinates. Please enter location manually.')),
        );
      }
    } catch (e) {
      debugPrint('>>> [EditProfileScreen._detectGpsLocation] Error: $e');
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  Future<void> _addPortfolioImage() async {
    final user = _user;
    if (user == null) return;

    final currentImages = user.images;
    final limit = ProviderEntitlementService.getPortfolioImageLimit(user);

    if (!ProviderEntitlementService.canUploadPortfolioImage(user, currentImages.length)) {
      final planName = user.effectivePlan == 'premium'
          ? 'Premium'
          : (user.effectivePlan == 'verified' ? 'Verified' : 'Basic');

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF06B6D4), size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'Portfolio Limit Reached',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Your current $planName plan allows up to $limit portfolio photos. Upgrade your provider plan to upload up to 10 showcase images and unlock priority ranking.',
                style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurface.withAlpha(200), height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProviderPlanScreen()),
                    ).then((_) => _loadUser());
                  },
                  child: const Text('Upgrade Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _uploadingPortfolio = true);

      final file = File(picked.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uploadPath = '${user.uid}/portfolio_$timestamp.jpg';

      final publicUrl = await _storage.uploadImage(
        file: file,
        path: uploadPath,
        bucket: 'avatars',
        uid: user.uid,
      );

      await _userRepo.addPortfolioImage(user.uid, publicUrl);
      await _loadUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portfolio image added successfully.')),
        );
      }
    } catch (e) {
      debugPrint('>>> [EditProfileScreen._addPortfolioImage] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload portfolio photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPortfolio = false);
    }
  }

  Future<void> _deletePortfolioImage(String url) async {
    final user = _user;
    if (user == null) return;

    try {
      await _userRepo.removePortfolioImage(user.uid, url);
      await _loadUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo removed from portfolio.')),
        );
      }
    } catch (e) {
      debugPrint('>>> [EditProfileScreen._deletePortfolioImage] Error: $e');
    }
  }

  void _addSkill() {
    final text = _skillInput.text.trim();
    if (text.isNotEmpty && !_skills.contains(text)) {
      setState(() {
        _skills.add(text);
        _skillInput.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() => _skills.remove(skill));
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      String? photoUrl = widget.photoUrl;
      bool photoFailed = false;

      if (_newImage != null) {
        try {
          photoUrl = await _storage.uploadAvatar(
            uid: user.uid,
            file: _newImage!,
          );
        } catch (e) {
          debugPrint('>>> [EditProfileScreen] Photo upload failed non-fatally: $e');
          photoFailed = true;
        }
      }

      final isProvider = _user?.isProvider ?? false;
      final yearsInt = int.tryParse(_yearsExp.text.trim()) ?? 0;

      if (isProvider) {
        await _userRepo.updateProviderBusinessProfile(
          uid: user.uid,
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          email: user.email,
          businessName: _businessName.text.trim(),
          category: _category,
          location: _location.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          about: _about.text.trim(),
          bio: _about.text.trim(),
          skills: _skills,
          yearsExperience: yearsInt,
          priceRange: _priceRange.text.trim(),
          available: _available,
          avatarUrl: photoUrl,
        );
      } else {
        await _userRepo.updateProfile(
          uid: user.uid,
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          location: _location.text.trim(),
          avatarUrl: photoUrl,
        );
      }

      if (!mounted) return;
      if (photoFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully, but the photo could not be uploaded.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully.'),
          ),
        );
      }
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('>>> [EditProfileScreen] Edit profile error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtleBorder = theme.colorScheme.outline.withAlpha(50);
    final hasExistingPhoto = widget.photoUrl != null && widget.photoUrl!.isNotEmpty;
    final isProvider = _user?.isProvider ?? false;
    final portfolioImages = _user?.images ?? [];
    final imageLimit = _user != null ? ProviderEntitlementService.getPortfolioImageLimit(_user!) : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(isProvider ? 'Edit Business Profile' : 'Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            // Avatar Picker
            Center(
              child: GestureDetector(
                onTap: _loading ? null : _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: _newImage != null
                            ? Image.file(_newImage!, width: 100, height: 100, fit: BoxFit.cover)
                            : (hasExistingPhoto
                                ? Image.network(
                                    widget.photoUrl!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.person, size: 40, color: Colors.grey),
                                    ),
                                  )
                                : Container(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.person, size: 40, color: Colors.grey),
                                  )),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF06B6D4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Basic Info Fields
            if (isProvider) ...[
              TextFormField(
                controller: _businessName,
                decoration: const InputDecoration(
                  labelText: 'Business Name / Trading Title',
                  hintText: 'e.g. QuickFix Plumbing Uganda',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: isProvider ? 'Contact Person / Provider Name *' : 'Full Name *',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. +256 700 000000',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Location with GPS auto-detect button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(
                      labelText: 'Location / City / District',
                      hintText: 'e.g. Kampala, Nakawa, Entebbe',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4).withAlpha(25),
                      foregroundColor: const Color(0xFF0891B2),
                    ),
                    icon: _detectingLocation
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                    tooltip: 'Detect GPS Coordinates',
                    onPressed: _detectingLocation ? null : _detectGpsLocation,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Provider-Specific Extended Fields
            if (isProvider) ...[
              // Category Dropdown
              DropdownButtonFormField<String>(
                initialValue: _category != null && _categories.contains(_category) ? _category : null,
                decoration: const InputDecoration(
                  labelText: 'Primary Service Category *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 16),

              // Availability Switch
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: subtleBorder),
                ),
                child: SwitchListTile.adaptive(
                  title: const Text('Available for Hire', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _available ? 'You appear as available in search & discovery' : 'Marked as currently unavailable',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _available,
                  activeTrackColor: Colors.green,
                  onChanged: (v) => setState(() => _available = v),
                ),
              ),
              const SizedBox(height: 16),

              // About / Bio
              TextFormField(
                controller: _about,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'About Your Business & Services',
                  hintText: 'Introduce your expertise, tools, quality guarantee, and work background...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Experience & Price Range
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearsExp,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Experience (Years)',
                        hintText: 'e.g. 5',
                        prefixIcon: Icon(Icons.timeline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceRange,
                      decoration: const InputDecoration(
                        labelText: 'Price Range',
                        hintText: 'e.g. UGX 20k - 50k',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Skills & Specialties Tags
              Text(
                'Skills & Specialties',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skillInput,
                      decoration: InputDecoration(
                        hintText: 'Add a specialty (e.g. Pipe Leak Repair)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _addSkill(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _addSkill,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_skills.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _skills.map((s) {
                    return Chip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeSkill(s),
                      backgroundColor: const Color(0xFF06B6D4).withAlpha(25),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),

              // Portfolio Showcase Section
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Work Portfolio Photos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${portfolioImages.length}/$imageLimit photos used (${_user?.effectivePlan.toUpperCase()} plan)',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(153)),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _uploadingPortfolio ? null : _addPortfolioImage,
                    icon: _uploadingPortfolio
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_photo_alternate, size: 18),
                    label: const Text('Add Photo'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (portfolioImages.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: subtleBorder),
                  ),
                  child: Center(
                    child: Text(
                      'No portfolio photos uploaded yet. Showcase your work to attract more clients.',
                      style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(153), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: portfolioImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, i) {
                      final url = portfolioImages[i];
                      return Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 100,
                                height: 100,
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _deletePortfolioImage(url),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CircularProgressIndicator.adaptive(backgroundColor: Colors.white)
                    : const Text('Save Business Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}