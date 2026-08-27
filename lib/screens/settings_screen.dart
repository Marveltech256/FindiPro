import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/provider_entitlement_service.dart';
import '../services/theme_service.dart';
import 'profile/edit_profile_screen.dart';
import 'provider/provider_plan_screen.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onRefresh;

  const SettingsScreen({
    super.key,
    required this.user,
    required this.onRefresh,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();

  // Notification Preferences State
  bool _notifHireRequests = true;
  bool _notifMessages = true;
  bool _notifReviews = true;
  bool _notifAccount = true;
  bool _isLoadingPrefs = true;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notifHireRequests = prefs.getBool('pref_notif_hire_requests') ?? true;
        _notifMessages = prefs.getBool('pref_notif_messages') ?? true;
        _notifReviews = prefs.getBool('pref_notif_reviews') ?? true;
        _notifAccount = prefs.getBool('pref_notif_account') ?? true;
        _isLoadingPrefs = false;
      });
    } catch (_) {
      setState(() => _isLoadingPrefs = false);
    }
  }

  Future<void> _updateNotifPref(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  Future<void> _launchWhatsAppSupport() async {
    final user = widget.user;
    final message = user.isProvider
        ? 'Hello FindiPro Support, I need assistance with my provider account (${user.name.isNotEmpty ? user.name : user.email}).'
        : 'Hello FindiPro Support, I need assistance with my account.';
    final whatsappUrl = Uri.parse('https://wa.me/256763294426?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        final webFallback = Uri.parse('https://api.whatsapp.com/send?phone=256763294426&text=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(webFallback)) {
          await launchUrl(webFallback, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp is not available on this device. Contact support at +256763294426'),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp is not available on this device. Contact support at +256763294426'),
          ),
        );
      }
    }
  }

  void _showAboutDialog() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.handyman_rounded, color: Color(0xFF06B6D4), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FindiPro',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Version 1.0.0 (Build 35)',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'FindiPro is a premier on-demand service marketplace connecting clients with verified, skilled professionals across Uganda, Africa, and internationally.\n\nBrowse top-rated service providers, request hires, negotiate quotes, chat in real-time, and manage service bookings securely.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withAlpha(220),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '© ${DateTime.now().year} FindiPro Technologies. All rights reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withAlpha(140),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTermsDialog() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                const Text(
                  'Terms of Service',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Last updated: August 2026',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(140)),
                ),
                const SizedBox(height: 16),
                _legalSection(
                  '1. Platform Agreement',
                  'By accessing or using FindiPro, you agree to comply with and be bound by these Terms of Service. FindiPro operates as an intermediary marketplace facilitating connections between service clients and independent service professionals.',
                ),
                _legalSection(
                  '2. Account & Registration',
                  'Users must provide accurate, current, and complete registration information. You are responsible for safeguarding your credentials and for all activities that occur under your account.',
                ),
                _legalSection(
                  '3. Service Requests & Engagement',
                  'Clients may browse providers and submit hire requests. Service agreements, scopes, timelines, and deliverables are agreed directly between the client and provider.',
                ),
                _legalSection(
                  '4. Provider Standards & Badges',
                  'Service providers agree to deliver quality services with professional integrity. Verification badges (Verified & Premium) indicate platform verification tier and identity status.',
                ),
                _legalSection(
                  '5. Reviews & Community Guidelines',
                  'Users may leave honest, respectful reviews following completed services. Fake, harassing, fraudulent, or abusive content will result in immediate suspension.',
                ),
                _legalSection(
                  '6. Termination',
                  'FindiPro reserves the right to suspend or terminate accounts that violate our terms, engage in fraudulent transactions, or compromise community safety.',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPrivacyDialog() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                const Text(
                  'Privacy Policy',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Last updated: August 2026',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(140)),
                ),
                const SizedBox(height: 16),
                _legalSection(
                  '1. Information We Collect',
                  'We collect profile information you provide during registration (name, email, phone number, role, location), portfolio images, service listings, messages, and transaction history.',
                ),
                _legalSection(
                  '2. How We Use Information',
                  'Your information is used to facilitate marketplace discovery, enable secure client-provider messaging, process service requests, display verified reviews, and improve app functionality.',
                ),
                _legalSection(
                  '3. Location Data',
                  'Location information is utilized to help clients discover nearby professionals and calculate approximate distances. Precise GPS coordinates are not shared publicly.',
                ),
                _legalSection(
                  '4. Data Security & Storage',
                  'We implement industry-standard encryption, Firebase Authentication, and secure Supabase database infrastructure to safeguard your personal data.',
                ),
                _legalSection(
                  '5. Your Rights & Deletion',
                  'You have the right to access, edit, or permanently delete your account and personal profile data at any time through the Account Actions menu in Settings.',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _legalSection(String title, String body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: theme.colorScheme.onSurface.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out of your FindiPro account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Close settings screen
                await _authService.logout();
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Expanded(child: Text('Delete Account?')),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action is permanent and cannot be undone.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              SizedBox(height: 8),
              Text(
                'Deleting your account will:\n'
                '• Permanently deactivate your profile\n'
                '• Remove your public service listings\n'
                '• Clear your contact details and portfolio\n'
                '• Immediately sign you out of FindiPro',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Account'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx); // Close dialog
                await _executeDeleteAccount();
              },
              child: const Text('Permanently Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeDeleteAccount() async {
    setState(() => _isDeletingAccount = true);
    try {
      await _authService.deleteAccount();
      if (mounted) {
        Navigator.pop(context); // Close Settings screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been deleted.'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final hasPrioritySupport = ProviderEntitlementService.hasPrioritySupport(user);
    final subtleBorder = theme.colorScheme.outline.withAlpha(50);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isDeletingAccount
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator.adaptive(),
                  SizedBox(height: 16),
                  Text('Deleting account and signing out...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // ==========================================
                // 1. ACCOUNT SECTION
                // ==========================================
                _buildSectionHeader('Account', Icons.person_outline),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: subtleBorder),
                  ),
                  child: Column(
                    children: [
                      // User Info Overview Tile
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFF06B6D4).withAlpha(30),
                              backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                                  ? NetworkImage(user.photoUrl!)
                                  : null,
                              child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                                  ? Text(
                                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF06B6D4),
                                      ),
                                    )
                                  : null,
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
                                          user.name.isNotEmpty ? user.name : 'FindiPro User',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      if (user.isPremiumBadge)
                                        const Icon(Icons.stars, color: Color(0xFFD97706), size: 18)
                                      else if (user.isVerifiedBadge)
                                        const Icon(Icons.verified, color: Colors.blue, size: 18),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface.withAlpha(153),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: user.isProvider
                                              ? const Color(0xFF06B6D4).withAlpha(30)
                                              : (user.isAdmin ? Colors.red.withAlpha(30) : Colors.grey.withAlpha(30)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          user.isAdmin
                                              ? 'Admin'
                                              : (user.isProvider
                                                  ? (user.category?.isNotEmpty == true
                                                      ? 'Provider (${user.category})'
                                                      : 'Service Provider')
                                                  : 'Client Account'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: user.isProvider
                                                ? const Color(0xFF0891B2)
                                                : (user.isAdmin ? Colors.red : theme.colorScheme.onSurface.withAlpha(180)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          user.phone.isNotEmpty ? 'Phone: ${user.phone}' : 'Update name, phone, location & photo',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
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
                            widget.onRefresh();
                          }
                        },
                      ),
                      if (user.isProvider) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.storefront_outlined),
                          title: const Text('Provider Plans & Badges', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'Current tier: ${user.effectivePlan.toUpperCase()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProviderPlanScreen()),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ==========================================
                // 2. PREFERENCES SECTION
                // ==========================================
                _buildSectionHeader('Preferences', Icons.tune_outlined),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: subtleBorder),
                  ),
                  child: Column(
                    children: [
                      // Theme Toggle
                      ListenableBuilder(
                        listenable: themeService,
                        builder: (context, _) {
                          final isDark = themeService.isDarkMode;
                          return SwitchListTile.adaptive(
                            secondary: Icon(
                              isDark ? Icons.dark_mode : Icons.light_mode,
                              color: isDark ? Colors.amber : const Color(0xFF06B6D4),
                            ),
                            title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              isDark ? 'Dark theme enabled' : 'Light theme enabled',
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: isDark,
                            onChanged: (val) => themeService.toggleTheme(val),
                          );
                        },
                      ),
                      const Divider(height: 1),

                      // Notification Preferences Group
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFF06B6D4)),
                            const SizedBox(width: 8),
                            Text(
                              'Notification Alerts',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withAlpha(180),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isLoadingPrefs)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator.adaptive(),
                        )
                      else ...[
                        SwitchListTile.adaptive(
                          dense: true,
                          title: const Text('Hire & Service Requests'),
                          subtitle: const Text('New requests, acceptances & updates', style: TextStyle(fontSize: 11)),
                          value: _notifHireRequests,
                          onChanged: (val) {
                            setState(() => _notifHireRequests = val);
                            _updateNotifPref('pref_notif_hire_requests', val);
                          },
                        ),
                        SwitchListTile.adaptive(
                          dense: true,
                          title: const Text('Chat Messages'),
                          subtitle: const Text('Direct incoming messages', style: TextStyle(fontSize: 11)),
                          value: _notifMessages,
                          onChanged: (val) {
                            setState(() => _notifMessages = val);
                            _updateNotifPref('pref_notif_messages', val);
                          },
                        ),
                        SwitchListTile.adaptive(
                          dense: true,
                          title: const Text('Reviews & Ratings'),
                          subtitle: const Text('Feedback submitted on completed services', style: TextStyle(fontSize: 11)),
                          value: _notifReviews,
                          onChanged: (val) {
                            setState(() => _notifReviews = val);
                            _updateNotifPref('pref_notif_reviews', val);
                          },
                        ),
                        SwitchListTile.adaptive(
                          dense: true,
                          title: const Text('Account & System Notices'),
                          subtitle: const Text('Plan status, badges & platform updates', style: TextStyle(fontSize: 11)),
                          value: _notifAccount,
                          onChanged: (val) {
                            setState(() => _notifAccount = val);
                            _updateNotifPref('pref_notif_account', val);
                          },
                        ),
                      ],
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ==========================================
                // 3. SUPPORT & LEGAL SECTION
                // ==========================================
                _buildSectionHeader('Support & Legal', Icons.support_agent),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: subtleBorder),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFF25D366),
                          child: Icon(Icons.chat, color: Colors.white, size: 20),
                        ),
                        title: const Text('Contact FindiPro Support', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          hasPrioritySupport
                              ? 'WhatsApp Instant Priority Support (+256763294426)'
                              : 'WhatsApp Support (+256763294426)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: hasPrioritySupport
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Priority',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _launchWhatsAppSupport,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About FindiPro', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('App version, mission & information', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showAboutDialog,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Platform guidelines & service terms', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showTermsDialog,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Data usage, protection & rights', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showPrivacyDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ==========================================
                // 4. ACCOUNT ACTIONS SECTION
                // ==========================================
                _buildSectionHeader('Account Actions', Icons.security_outlined),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: subtleBorder),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.orange),
                        title: const Text(
                          'Log Out',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                        ),
                        subtitle: const Text('Sign out of this device', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.orange),
                        onTap: _confirmLogout,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                        ),
                        subtitle: const Text('Permanently remove your account and data', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.red),
                        onTap: _confirmDeleteAccount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF06B6D4)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}


