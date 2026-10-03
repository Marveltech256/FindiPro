import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/findipro_logo.dart';
import '../../services/otp_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String? userName;
  final Future<void> Function() onVerified;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.userName,
    required this.onVerified,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _codeLength = 6;
  final _otpService = OtpService();
  final List<TextEditingController> _controllers = List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_codeLength, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  int _resendCooldown = 60;
  int _expirySeconds = 600; // 10 minutes
  Timer? _timer;
  Timer? _expiryTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _startExpiryTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startExpiryTimer() {
    setState(() => _expirySeconds = 600);
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_expirySeconds > 0) {
        setState(() => _expirySeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _expiryLabel {
    final m = _expirySeconds ~/ 60;
    final s = _expirySeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startResendTimer() {
    setState(() => _resendCooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _currentCode => _controllers.map((c) => c.text.trim()).join();

  Future<void> _handleVerify() async {
    final code = _currentCode;
    if (code.length < 4) {
      setState(() => _errorMessage = 'Please enter the complete verification code.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await _otpService.verifyOtp(
        email: widget.email,
        enteredCode: code,
      );

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _loading = false;
          _errorMessage = result.message;
        });
        return;
      }

      // Successful OTP verification -> trigger registration finalization callback
      await widget.onVerified();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Verification error: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  Future<void> _handleResend() async {
    if (_resendCooldown > 0 || _resending) return;

    setState(() {
      _resending = true;
      _errorMessage = null;
    });

    try {
      final res = await _otpService.resendOtp(
        email: widget.email,
        name: widget.userName,
      );

      if (!mounted) return;

      if (res.success) {
        _startResendTimer();
        _startExpiryTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A new verification code has been sent to ${widget.email}.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        setState(() => _errorMessage = res.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not resend code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handles pasting full code
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < _codeLength && i < digits.length; i++) {
          _controllers[i].text = digits[i];
        }
        final targetIndex = (digits.length < _codeLength) ? digits.length : _codeLength - 1;
        _focusNodes[targetIndex].requestFocus();
        if (digits.length >= 4) {
          _handleVerify();
        }
      }
      return;
    }

    if (value.isNotEmpty) {
      // Move forward to next box
      if (index < _codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_currentCode.length >= 4) {
          _handleVerify();
        }
      }
    } else {
      // Backspace pressed / character deleted -> move back to previous box
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: FindiProLogo(height: 60)),
                  const SizedBox(height: 28),
                  
                  // Icon Header
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 38,
                        color: Color(0xFF0891B2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Enter Verification Code',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To protect our community from spam, we have sent a verification code to:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0891B2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Live expiry countdown badge
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _expirySeconds > 0
                        ? Container(
                            key: const ValueKey('expiring'),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _expirySeconds < 60
                                  ? Colors.red.shade50
                                  : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _expirySeconds < 60
                                    ? Colors.red.shade300
                                    : Colors.amber.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: _expirySeconds < 60
                                      ? Colors.red.shade700
                                      : Colors.amber.shade800,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Code expires in $_expiryLabel',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _expirySeconds < 60
                                        ? Colors.red.shade700
                                        : Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            key: const ValueKey('expired'),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_off_outlined, size: 16, color: Colors.red.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Code expired — please resend',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),

                  // Responsive Verification Code Input Boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_codeLength, (index) {
                      return Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 48, minWidth: 32),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 60,
                          child: TextFormField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            autofocus: index == 0,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            onTap: () {
                              _controllers[index].selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _controllers[index].text.length,
                              );
                            },
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0891B2),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: theme.cardColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline.withAlpha(80),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF06B6D4),
                                  width: 2.5,
                                ),
                              ),
                            ),
                            onChanged: (val) => _onDigitChanged(index, val),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Verify Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Verify & Complete Registration',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Resend Code Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                      if (_resendCooldown > 0)
                        Text(
                          'Resend in ${_resendCooldown}s',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _resending ? null : _handleResend,
                          child: _resending
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                                )
                              : const Text(
                                  'Resend Code',
                                  style: TextStyle(
                                    color: Color(0xFF0891B2),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Change email / Cancel
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Change email address'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

