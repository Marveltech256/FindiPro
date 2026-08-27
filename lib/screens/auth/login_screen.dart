import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';

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
      final credential = await _auth.login(email: _email.text, password: _password.text);
      final firebaseUser = FirebaseAuth.instance.currentUser ?? credential.user;
      if (firebaseUser != null && mounted) {
        Navigator.pop(context);
        return;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('>>> [LoginScreen] FirebaseAuthException: ${e.code} - ${e.message}');
      if (mounted) _show(e.message ?? 'Login failed. Please check your credentials.');
    } catch (e) {
      debugPrint('>>> [LoginScreen] General login error: $e');
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && mounted) {
        // Firebase authentication was actually successful
        Navigator.pop(context);
        return;
      }
      if (mounted) _show('Unable to log in. Please check your network connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      final result = await _google.signInWithGoogle();
      if (result != null && mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (mounted) _show(e.message ?? 'Google sign-in failed.');
    } catch (e) {
      if (mounted) _show('Google sign-in failed. Check Firebase Google Sign-In configuration.');
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
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 20),
              Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Sign in to continue using FindiPro.'),
              const SizedBox(height: 28),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _forgot,
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading ? const CircularProgressIndicator.adaptive() : const Text('Login'),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loading ? null : _googleLogin,
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
