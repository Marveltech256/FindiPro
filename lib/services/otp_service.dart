import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

class OtpResult {
  final bool success;
  final String message;
  final String? code;

  const OtpResult({
    required this.success,
    required this.message,
    this.code,
  });
}

class OtpService {
  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Generates a secure random 4-digit code (1000 - 9999)
  String generate4DigitOtp() {
    final rng = Random.secure();
    final code = 1000 + rng.nextInt(9000);
    return code.toString();
  }

  /// Sends (stores & dispatches) an OTP for email verification.
  Future<String> sendEmailOtp(String email) async {
    final res = await sendOtp(email: email);
    return res.code ?? generate4DigitOtp();
  }

  /// Sends an OTP for email verification and returns OtpResult.
  Future<OtpResult> sendOtp({
    required String email,
    String? name,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final otpCode = generate4DigitOtp();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(minutes: 10)).toIso8601String();

    debugPrint('>>> [OtpService] Generating OTP for $cleanEmail: $otpCode (valid 10 mins)');

    // Invalidate existing unverified OTPs for this email
    try {
      await _supabase
          .from('email_otps')
          .delete()
          .eq('email', cleanEmail)
          .eq('verified', false);
    } catch (_) {}

    // Store OTP in Supabase email_otps table
    try {
      await _supabase.from('email_otps').insert({
        'email': cleanEmail,
        'otp_code': otpCode,
        'expires_at': expiresAt,
        'verified': false,
        'attempts': 0,
        'created_at': now.toIso8601String(),
      });
      debugPrint('>>> [OtpService] OTP stored in database for $cleanEmail');
    } catch (e) {
      debugPrint('>>> [OtpService] Note storing OTP in DB: $e');
    }

    // 1. Dispatch Supabase Auth OTP email (sends {{ .Token }} to user's inbox)
    try {
      await _supabase.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: true,
      );
      debugPrint('>>> [OtpService] Supabase Auth OTP email dispatched to $cleanEmail');
    } catch (authErr) {
      debugPrint('>>> [OtpService] Note dispatching Supabase Auth email: $authErr');
    }

    // 2. Also try custom Edge Function if deployed
    try {
      await _supabase.functions.invoke(
        'send-otp-email',
        body: {
          'email': cleanEmail,
          'otp_code': otpCode,
          'name': name ?? cleanEmail.split('@').first,
        },
      );
    } catch (_) {}

    return OtpResult(
      success: true,
      message: 'Verification code sent to $cleanEmail. Check your inbox — expires in 10 minutes.',
      code: otpCode,
    );
  }

  /// Resends an OTP to the given email
  Future<OtpResult> resendOtp({
    required String email,
    String? name,
  }) async {
    return sendOtp(email: email, name: name);
  }

  /// Verifies a code provided by the user (boolean return).
  Future<bool> verifyEmailOtp(String email, String enteredOtp) async {
    final res = await verifyOtp(email: email, enteredCode: enteredOtp);
    return res.success;
  }

  /// Verifies a code provided by the user (OtpResult return).
  Future<OtpResult> verifyOtp({
    required String email,
    required String enteredCode,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = enteredCode.trim();
    final now = DateTime.now().toUtc();

    debugPrint('>>> [OtpService] Verifying OTP $cleanOtp for $cleanEmail');

    // 1. First attempt verification via Supabase Auth OTP (for 6-digit email token)
    try {
      final authRes = await _supabase.auth.verifyOTP(
        email: cleanEmail,
        token: cleanOtp,
        type: OtpType.email,
      );
      if (authRes.user != null || authRes.session != null) {
        debugPrint('>>> [OtpService] Successfully verified via Supabase Auth OTP');
        try {
          await _supabase.from('email_otps').update({
            'verified': true,
            'verified_at': now.toIso8601String(),
          }).eq('email', cleanEmail);
        } catch (_) {}
        return const OtpResult(
          success: true,
          message: 'Email verified successfully!',
        );
      }
    } catch (authVerifyErr) {
      debugPrint('>>> [OtpService] Supabase Auth OTP check note: $authVerifyErr');
    }

    // 2. Fallback check against email_otps table
    try {
      final res = await _supabase
          .from('email_otps')
          .select()
          .eq('email', cleanEmail)
          .eq('verified', false)
          .order('created_at', ascending: false)
          .limit(1);

      if (res.isNotEmpty) {
        final record = res.first;
        final storedCode = record['otp_code'].toString();
        final expiresAtStr = record['expires_at'].toString();
        final expiresAt = DateTime.tryParse(expiresAtStr) ?? now;
        final attempts = (record['attempts'] as int? ?? 0) + 1;
        final recordId = record['id'];

        // Check max attempts
        if (attempts > 5) {
          debugPrint('>>> [OtpService] Too many invalid attempts ($attempts)');
          return const OtpResult(
            success: false,
            message: 'Too many incorrect attempts. Please request a new code.',
          );
        }

        // Check expiry
        if (now.isAfter(expiresAt)) {
          debugPrint('>>> [OtpService] OTP expired at $expiresAt (now: $now)');
          return const OtpResult(
            success: false,
            message: 'This code has expired. Please request a new one.',
          );
        }

        // Check code match
        if (storedCode == cleanOtp) {
          await _supabase.from('email_otps').update({
            'verified': true,
            'verified_at': now.toIso8601String(),
            'attempts': attempts,
          }).eq('id', recordId);

          debugPrint('>>> [OtpService] OTP verified successfully for $cleanEmail');
          return const OtpResult(
            success: true,
            message: 'Email verified successfully!',
          );
        } else {
          await _supabase.from('email_otps').update({
            'attempts': attempts,
          }).eq('id', recordId);

          final remaining = 5 - attempts;
          debugPrint('>>> [OtpService] OTP mismatch. Attempt $attempts of 5');
          return OtpResult(
            success: false,
            message: 'Invalid code. $remaining attempt${remaining == 1 ? '' : 's'} remaining.',
          );
        }
      }
    } catch (e) {
      debugPrint('>>> [OtpService] Error during DB verification: $e');
    }

    return const OtpResult(
      success: false,
      message: 'Invalid verification code. Please check your email and try again.',
    );
  }
}
