import 'package:flutter/material.dart';
import 'package:findipro/services/auth_service.dart';
import 'package:findipro/services/google_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);

    try {
      await _googleAuthService.signInWithGoogle();

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),

          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _loading ? null : _login,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Login'),
          ),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: _loading ? null : _googleLogin,
            icon: const Icon(Icons.login),
            label: const Text('Continue with Google'),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () {},
            child: const Text('Forgot password?'),
          ),
        ],
      ),
    );
  }
}