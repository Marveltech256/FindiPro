import 'package:findipro/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A widget that guards a screen, allowing access only to users with an 'admin' role.
class AdminGuard extends StatelessWidget {
  final Widget child;

  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Consumes the UserModel provided by AuthWrapper.
    final userModel = context.watch<UserModel?>();

    if (userModel != null && userModel.role == 'admin') {
      // If the user is an admin, show the protected screen.
      return child;
    } else {
      // Otherwise, show an "Access Denied" screen.
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_outlined, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                Text('You do not have permission to access this page.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
        ),
      );
    }
  }
}