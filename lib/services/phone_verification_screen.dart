import 'package:findipro/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A screen for users to verify their phone number using Firebase Phone Authentication.
/// This screen allows users to enter a phone number, receive an OTP, and then verify it.
/// Upon successful verification, the phone number is linked to the authenticated user's
/// Firebase account, and the `phoneVerified` status in Firestore is updated.
class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// Initiates the process of sending an OTP to the provided phone number.
  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      _showSnackBar('Please enter a phone number.');
      setState(() => _isLoading = false);
      return;
    }

    // Firebase Phone Auth requires a valid phone number format, e.g., +1234567890
    if (!phoneNumber.startsWith('+') || phoneNumber.length < 10) {
      _showSnackBar('Please enter a valid phone number including country code (e.g., +1234567890).');
      setState(() => _isLoading = false);
      return;
    }

    try {
      await authService.sendPhoneVerificationCode(
        phoneNumber: phoneNumber,
        codeSent: (verificationId, resendToken) {
          setState(() {
            _otpSent = true;
            _isLoading = false;
            _statusMessage = 'OTP sent to $phoneNumber. Please enter it below.';
          });
        },
        verificationFailed: (e) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Verification failed: ${e.message}';
          });
          _showSnackBar('Verification failed: ${e.message}');
        },
        verificationCompleted: (credential) async {
          // This callback is typically invoked on Android devices when the OTP is
          // automatically retrieved.
          try {
            await authService.linkPhoneCredential(credential);
            _showSnackBar('Phone number automatically verified!');
            if (mounted) Navigator.of(context).pop(true); // Pop with success
          } catch (e) {
            _showSnackBar('Auto-verification failed: ${e.toString()}');
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          setState(() {
            _statusMessage = 'OTP auto-retrieval timed out. Please enter manually.';
          });
        },
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error sending OTP: ${e.message}';
      });
      _showSnackBar('Error sending OTP: ${e.message}');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'An unexpected error occurred: $e';
      });
      _showSnackBar('An unexpected error occurred: $e');
    }
  }

  /// Verifies the entered OTP against the sent verification code.
  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      _showSnackBar('Please enter the OTP.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      await authService.verifyPhoneNumberWithOtp(otp);
      _showSnackBar('Phone number verified successfully!');
      Navigator.of(context).pop(true); // Pop with success
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'OTP verification failed: ${e.message}';
      });
      _showSnackBar('OTP verification failed: ${e.message}');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'An unexpected error occurred: $e';
      });
      _showSnackBar('An unexpected error occurred: $e');
    }
  }

  /// Displays a SnackBar with the given message.
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_otpSent) ...[
              Text(
                'Enter your phone number to receive a verification code.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (e.g., +1234567890)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: _isLoading ? const CircularProgressIndicator.adaptive() : const Text('Send OTP'),
              ),
            ],
            if (_otpSent) ...[
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Verification Code (OTP)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading ? const CircularProgressIndicator.adaptive() : const Text('Verify OTP'),
              ),
              TextButton(
                onPressed: _isLoading ? null : () {
                  setState(() {
                    _otpSent = false; // Go back to phone number input
                    _statusMessage = '';
                  });
                },
                child: const Text('Change Phone Number / Resend OTP'),
              ),
            ],
            if (_statusMessage.isNotEmpty && !_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _statusMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}