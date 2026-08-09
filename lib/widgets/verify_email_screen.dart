import 'dart:async';
import 'package:findipro/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// This screen is shown to users who have registered with an email and password
/// but have not yet verified their email address.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;
  bool _canResendEmail = false;

  @override
  void initState() {
    super.initState();
    // Start a timer to periodically check the verification status.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkEmailVerified());

    // Allow the user to resend the email after a short delay to prevent spamming.
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _canResendEmail = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Reloads the user from Firebase to get the latest `emailVerified` status.
  /// The AuthWrapper will automatically navigate away if verification is successful.
  Future<void> _checkEmailVerified() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.reloadUser();
    } catch (e) {
      // Errors (like network issues) can be ignored here as the timer will try again.
    }
  }

  /// Sends another verification email to the user.
  Future<void> _sendVerificationEmail() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!mounted) return;

    try {
      await authService.sendVerificationEmail();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new verification email has been sent.')),
      );
      // Disable the button temporarily.
      setState(() => _canResendEmail = false);
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() => _canResendEmail = true);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send email: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final userEmail = authService.currentUser?.email ?? 'your email address';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Verification Email Sent', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text('We\'ve sent a verification link to:', style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(userEmail, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Text('Please check your inbox (and spam folder) and click the link to activate your account.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.refresh),
                label: const Text('I have verified, check again'),
                onPressed: _checkEmailVerified,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.send),
                label: const Text('Resend Verification Email'),
                onPressed: _canResendEmail ? _sendVerificationEmail : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}