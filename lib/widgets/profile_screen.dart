import 'package:findipro/models/user_model.dart';
import 'package:findipro/repositories/user_repository.dart';
import 'package:findipro/services/auth_service.dart';
import 'package:findipro/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A screen to display user profile information and allow image uploads.
/// This widget consumes the `UserModel` stream provided higher up in the tree.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  /// Triggers the profile image update process.
  Future<void> _updateProfileImage() async {
    if (!mounted) return;
    setState(() => _isUploading = true);

    final userRepo = context.read<UserRepository>();
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not authenticated.')),
      );
      setState(() => _isUploading = false);
      return;
    }

    try {
      await userRepo.updateProfilePhoto(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update image: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consumes the UserModel provided by the StreamProvider in AuthWrapper
    final user = Provider.of<UserModel?>(context);
    final themeService = Provider.of<ThemeService>(context);

    // Handle the case where user data is still loading or unavailable
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null || user.photoUrl!.isEmpty
                      ? Icon(Icons.person, size: 60, color: Colors.grey.shade700)
                      : null,
                ),
                GestureDetector(
                  onTap: _isUploading ? null : _updateProfileImage,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Name'),
            subtitle: Text(user.name),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(user.email),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.brightness_6_outlined),
            value: themeService.isDarkMode,
            onChanged: (value) => themeService.toggleTheme(),
          ),
          // ... other profile details can be added here
        ],
      ),
    );
  }
}