import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../repositories/review_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/register_client_screen.dart';
import '../auth/register_provider_screen.dart';
import '../saved_screen.dart';
import '../my_requests_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../notifications/notifications_screen.dart';
import '../provider/provider_detail_screen.dart';
import '../provider/provider_plan_screen.dart';
import '../../repositories/notification_repository.dart';
import '../settings_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<UserModel?>? _profileFuture;
  String? _currentUid;
  final _userRepo = UserRepository();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile([String? uid]) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final targetUid = uid ?? firebaseUser?.uid;
    _currentUid = targetUid;

    if (targetUid == null) {
      _profileFuture = Future.value(null);
      return;
    }

    _profileFuture = _userRepo.getUser(targetUid);
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _loadProfile();
    });
    await _profileFuture;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator.adaptive()),
          );
        }

        final firebaseUser = authSnapshot.data ?? FirebaseAuth.instance.currentUser;
        if (firebaseUser == null) {
          return _GuestProfile();
        }

        if (_currentUid != firebaseUser.uid || _profileFuture == null) {
          _loadProfile(firebaseUser.uid);
        }

        return FutureBuilder<UserModel?>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            final dbUser = profileSnapshot.data;
            final user = dbUser ??
                UserModel(
                  uid: firebaseUser.uid,
                  name: (firebaseUser.displayName != null && firebaseUser.displayName!.trim().isNotEmpty)
                      ? firebaseUser.displayName!.trim()
                      : (firebaseUser.email?.split('@').first ?? 'FindiPro User'),
                  email: firebaseUser.email ?? '',
                  phone: firebaseUser.phoneNumber ?? '',
                  photoUrl: firebaseUser.photoURL,
                  role: 'customer',
                );

            return _LoggedInProfile(
              user: user,
              onRefresh: _refreshProfile,
            );
          },
        );
      },
    );
  }
}

class _GuestProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              const Center(child: CircleAvatar(radius: 56, child: Icon(Icons.person, size: 56))),
              const SizedBox(height: 24),
              const Text('Welcome to FindiPro', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Find trusted professionals, request services, save providers and chat securely.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(153), height: 1.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Login'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterClientScreen())),
                child: const Text('Sign up as Client'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterProviderScreen())),
                icon: const Icon(Icons.work_outline),
                label: const Text('Become a Service Provider'),
              ),
            ],
          ),
        ),
      );
}

class _LoggedInProfile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRefresh;

  const _LoggedInProfile({
    required this.user,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = user.photoUrl != null && user.photoUrl!.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: hasPhoto
                          ? Image.network(
                              user.photoUrl!,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.person, size: 34, color: Colors.grey),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.person, size: 34, color: Colors.grey),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name.isEmpty ? 'FindiPro User' : user.name,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (user.isPremiumBadge)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.stars, color: Color(0xFFD97706), size: 22),
                              )
                            else if (user.isVerifiedBadge)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.verified, color: Colors.blue, size: 22),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(user.email, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(153))),
                        const SizedBox(height: 4),
                        if (user.isAdmin)
                          const Text('Admin', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))
                        else if (user.isProvider)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF06B6D4).withAlpha(38),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      user.category?.isNotEmpty == true
                                          ? 'Provider (${user.category})'
                                          : 'Service Provider',
                                      style: const TextStyle(
                                        color: Color(0xFF0891B2),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              FutureBuilder<Map<String, dynamic>>(
                                future: ReviewRepository().getProviderRatingSummary(user.uid),
                                builder: (context, revSnap) {
                                  if (revSnap.connectionState == ConnectionState.waiting) {
                                    return const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                                    );
                                  }
                                  final summary = revSnap.data ?? {'average': 0.0, 'count': 0};
                                  final avg = (summary['average'] as num?)?.toDouble() ?? 0.0;
                                  final count = (summary['count'] as num?)?.toInt() ?? 0;
                                  if (count > 0) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$avg ($count ${count == 1 ? 'review' : 'reviews'})',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    );
                                  }
                                  return Text(
                                    'No reviews yet',
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(120)),
                                  );
                                },
                              ),
                            ],
                          )
                        else
                          const Text(
                            'Client Account',
                            style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (user.isAdmin) ...[
                _tile(
                  context,
                  Icons.admin_panel_settings,
                  'Admin dashboard',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                ),
              ],
              if (user.isProvider) ...[
                _tile(
                  context,
                  Icons.verified_user_outlined,
                  'Identity Verification (${user.verificationStatus?.toUpperCase() ?? (user.isVerifiedBadge ? 'APPROVED' : 'UNVERIFIED')})',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderPlanScreen())),
                ),
                _tile(
                  context,
                  Icons.storefront_outlined,
                  'Provider Plans & Badges',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderPlanScreen())),
                ),
                _tile(
                  context,
                  Icons.rate_review_outlined,
                  'My Reviews & Public Profile',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: user)),
                  ),
                ),
              ],
              _tile(
                context,
                Icons.receipt_long_outlined,
                user.isProvider ? 'Bookings & requests' : 'My requests',
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRequestsScreen())),
              ),
              StreamBuilder<int>(
                stream: NotificationRepository().getUnreadCountStream(user.uid),
                builder: (context, snapshot) {
                  final unread = snapshot.data ?? 0;
                  return ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                  );
                },
              ),
              if (!user.isProvider) ...[
                _tile(
                  context,
                  Icons.bookmark_outline,
                  'Saved providers',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedScreen())),
                ),
              ],
              _tile(
                context,
                Icons.edit_outlined,
                'Edit profile',
                () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        name: user.name,
                        phone: user.phone,
                        location: user.location ?? '',
                        photoUrl: user.photoUrl,
                      ),
                    ),
                  );
                  if (changed == true) {
                    onRefresh();
                  }
                },
              ),
              _tile(
                context,
                Icons.settings_outlined,
                'Settings',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      user: user,
                      onRefresh: onRefresh,
                    ),
                  ),
                ),
              ),
              const Divider(height: 32),
              _tile(
                context,
                Icons.logout,
                'Logout',
                () async {
                  await AuthService().logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext c, IconData icon, String title, VoidCallback tap) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: tap,
      );
}
