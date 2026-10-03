import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/findipro_logo.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';
import 'register_client_screen.dart';
import 'register_provider_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  final _google = GoogleAuthService();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Login failed';
        if (e.code == 'user-not-found') msg = 'No user found for that email.';
        if (e.code == 'wrong-password') msg = 'Incorrect password.';
        if (e.code == 'invalid-email') msg = 'Invalid email address.';
        if (e.code == 'user-disabled') msg = 'This account has been disabled.';
        _show(msg);
      }
    } catch (e) {
      if (mounted) _show('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _promptRoleSelection() async {
    return showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Account Type',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'How would you like to use FindiPro?',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEAF3E4),
                    child: Icon(Icons.person_search_outlined, color: Color(0xFF548C2F)),
                  ),
                  title: const Text(
                    'Client / Customer',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('I want to find, hire, and book trusted professionals'),
                  onTap: () => Navigator.pop(ctx, 'customer'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.handyman_outlined, color: Color(0xFFF9A620)),
                  ),
                  title: const Text(
                    'Service Provider',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('I offer services and want to get hired by clients'),
                  onTap: () => Navigator.pop(ctx, 'provider'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      final googleData = await _google.authenticateWithGoogle();
      if (googleData == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final hasProfile = await _google.hasExistingProfile(googleData.uid);
      if (hasProfile) {
        if (mounted) Navigator.pop(context);
        return;
      }

      // New user - prompt for role selection
      if (!mounted) return;
      final selectedRole = await _promptRoleSelection();
      if (selectedRole == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (selectedRole == 'provider') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RegisterProviderScreen(initialGoogleData: googleData),
            ),
          );
        }
        return;
      }

      if (selectedRole == 'customer') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RegisterClientScreen(initialGoogleData: googleData),
            ),
          );
        }
        return;
      }

      await _google.signUpWithGoogle(selectedRole: selectedRole);
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('>>> [LoginScreen._googleLogin] FirebaseAuthException (${e.code}): ${e.message}');
      if (mounted) _show('Auth error [${e.code}]: ${e.message ?? 'Google sign-in failed.'}');
    } catch (e) {
      debugPrint('>>> [LoginScreen._googleLogin] Error: $e');
      final msg = e.toString().replaceAll('Exception: ', '').trim();
      if (mounted) _show(msg.isNotEmpty ? msg : 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) {
      _show('Enter your email first.');
      return;
    }
    try {
      await _auth.resetPassword(_email.text);
      if (mounted) _show('Password reset email sent.');
    } catch (e) {
      if (mounted) _show('Could not send password reset email.');
    }
  }

  void _show(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AbsorbPointer(
                    absorbing: _loading,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: FindiProLogo(
                              height: 64,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to continue using FindiPro.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _email,
                            enabled: !_loading,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            enabled: !_loading,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                              ),
                            ),
                            validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                          ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _forgot,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading ? const CircularProgressIndicator.adaptive() : const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _loading ? null : _googleLogin,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.red),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? "),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterClientScreen()),
                          ),
                          child: const Text(
                            'Sign up as Client',
                            style: TextStyle(
                              color: Color(0xFF06B6D4),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterProviderScreen()),
                        ),
                        icon: const Icon(Icons.work_outline, size: 18, color: Color(0xFFD97706)),
                        label: const Text(
                          'Register as Service Provider',
                          style: TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      if (_loading)
        Positioned.fill(
          child: Container(
            color: Colors.black.withAlpha(40),
            child: const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
          ),
        ),
    ],
  ),
),
);
}
}
