import 'package:findipro/services/phone_verification_screen.dart';
import 'package:findipro/services/auth_service.dart';
import 'package:findipro/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A screen for managing user settings, including theme, notifications,
/// and account verification statuses.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isEmailReloading = false;
  bool _isResendingEmail = false;

  /// Checks the latest email verification status from Firebase.
  Future<void> _checkEmailVerificationStatus() async {
    setState(() => _isEmailReloading = true);
    try {
      await context.read<AuthService>().reloadUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verification status refreshed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh status: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isEmailReloading = false);
    }
  }

  /// Sends a new email verification link.
  Future<void> _resendVerificationEmail() async {
    setState(() => _isResendingEmail = true);
    try {
      await context.read<AuthService>().sendVerificationEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Check your inbox.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send email: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();
    final currentUser = authService.currentUser;

    // Assuming email verification is only relevant for email/password users
    final requiresEmailVerification = currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;
    final isEmailVerified = currentUser?.emailVerified ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Dark / Light Mode Toggle
          SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.brightness_6_outlined),
            value: themeService.isDarkMode,
            onChanged: (value) => themeService.toggleTheme(),
          ),
          const Divider(),

          // Email Verification Status
          if (requiresEmailVerification) ...[
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email Verification'),
              subtitle: Text(isEmailVerified ? 'Verified' : 'Not Verified'),
              trailing: isEmailVerified
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: _isEmailReloading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                          onPressed: _isEmailReloading ? null : _checkEmailVerificationStatus,
                          tooltip: 'Check status',
                        ),
                        IconButton(
                          icon: _isResendingEmail ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                          onPressed: _isResendingEmail ? null : _resendVerificationEmail,
                          tooltip: 'Resend email',
                        ),
                      ],
                    ),
            ),
            const Divider(),
          ],

          // Phone Verification Status (Placeholder for now, will fetch from Firestore)
          FutureBuilder<bool>(
            future: authService.getPhoneVerificationStatus(),
            builder: (context, snapshot) {
              final isPhoneVerified = snapshot.data ?? false;
              return ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Phone Verification'),
                subtitle: Text(isPhoneVerified ? 'Verified' : 'Not Verified'),
                trailing: isPhoneVerified
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhoneVerificationScreen())),
                        child: const Text('Verify Now'),
                      ),
              );
            },
          ),
          const Divider(),

          // Notification Preferences (Placeholder)
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Notification Preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification preferences not implemented yet.')),
              );
            },
          ),
          const Divider(),

          // Other account-related settings can go here
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Change password not implemented yet.')),
              );
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}