import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:findipro/theme/app_theme.dart';
import 'package:findipro/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:findipro/models/user_model.dart';
import 'package:findipro/repositories/user_repository.dart';
import 'package:findipro/services/storage_service.dart';
import 'package:findipro/screens/login_screen.dart';
import 'package:findipro/screens/register_client_screen.dart';
import 'package:findipro/screens/register_provider_screen.dart';
import 'package:findipro/screens/edit_profile_screen.dart';
import 'package:findipro/screens/my_requests_screen.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickAndUploadImage(UserModel user) async {
    if (_isUploading) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        final file = File(image.path);
        final String oldPhotoUrl = user.photoUrl ?? '';

        // Upload new image
        final String downloadUrl = await _storageService.uploadImage(
          file: file,
          path: 'users/${user.uid}/profile.jpg',
        );

        // Update Firestore
        await _userRepository.updatePhoto(user.uid, downloadUrl);

        // Delete old image if it exists
        if (oldPhotoUrl.isNotEmpty && oldPhotoUrl != downloadUrl) {
          await _storageService.deleteImage(oldPhotoUrl);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      } finally {
        if (mounted) setState(() { _isUploading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          StreamBuilder<User?>(
            stream: _authService.authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await _authService.signOut();
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            // Now we have a user, fetch their profile from Firestore
            return StreamBuilder<UserModel?>(
              stream: _userRepository.getUser(snapshot.data!.uid),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (userSnapshot.hasError) return Center(child: Text('Could not load profile. Error: ${userSnapshot.error}'));
                if (!userSnapshot.hasData || userSnapshot.data == null) return const Center(child: Text('Profile not found.'));
                
                return _buildLoggedInProfile(userSnapshot.data!);
              });
          }
          return _buildGuestProfile();
        },
      ),
    );
  }

  Widget _buildGuestProfile() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.person_pin_circle_outlined, size: 80, color: AppTheme.iconColor),
          const SizedBox(height: 16),
          Text(
            'Join FindiPro to save providers, request services, and manage your profile.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LoginScreen())),
            child: const Text('Login'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegisterClientScreen())),
            child: const Text('Sign up as Client'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegisterProviderScreen())),
            child: const Text('Become a Service Provider'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedInProfile(UserModel user) {
    final profileImageUrl = user.photoUrl;

    return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Column(
              children: [
                GestureDetector(
                  onTap: () => _pickAndUploadImage(user),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.iconColor.withOpacity(0.2),
                        backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                            ? CachedNetworkImageProvider(profileImageUrl)
                            : null,
                        child: (profileImageUrl == null || profileImageUrl.isEmpty)
                            ? const Icon(Icons.person, size: 50, color: AppTheme.iconColor)
                            : null,
                      ),
                      if (_isUploading)
                        const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      else
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(user.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                if (user.phone.isNotEmpty)
                  Text(user.phone, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    user.role.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppTheme.primaryColor,
                ),
              ],
            ),
            const Divider(height: 48),
            _buildProfileMenuItem(
              context,
              icon: Icons.edit_outlined,
              text: 'Edit Profile',
              onTap: () {
                // TODO: EditProfileScreen needs to be updated to accept a UserModel or work with UserRepository
                // For now, we pass a dummy map to avoid breaking the app.
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => EditProfileScreen(userData: const {})));
              },
            ),
            _buildProfileMenuItem(
              context,
              icon: Icons.list_alt_outlined,
              text: 'My Requests',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MyRequestsScreen())),
            ),
            _buildProfileMenuItem(
              context,
              icon: Icons.favorite_border,
              text: 'Saved Providers',
              onTap: () { /* TODO: Navigate to Saved Providers Screen */ },
            ),
            _buildProfileMenuItem(
              context,
              icon: Icons.notifications_none,
              text: 'Notifications',
              onTap: () { /* TODO: Navigate to Notifications Screen */ },
            ),
            _buildProfileMenuItem(
              context,
              icon: Icons.settings_outlined,
              text: 'Settings',
              onTap: () { /* TODO: Navigate to Settings Screen */ },
            ),
          ],
        );
  }

  Widget _buildProfileMenuItem(BuildContext context, {required IconData icon, required String text, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.iconColor),
      title: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.iconColor),
      onTap: onTap,
    );
  }
}