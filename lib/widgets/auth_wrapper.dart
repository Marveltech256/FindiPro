import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main_screen.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../services/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator.adaptive()),
          );
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return const ProfileScreen();
        }

        // Fire-and-forget profile synchronization check
        AuthService().ensureProfileSynced(firebaseUser);

        return StreamBuilder<UserModel?>(
          stream: UserRepository().watchUser(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting && !profileSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator.adaptive()),
              );
            }

            final userModel = profileSnapshot.data;

            if (userModel == null) {
              return Scaffold(
                body: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sync_problem, size: 64, color: Colors.orange),
                          const SizedBox(height: 16),
                          const Text(
                            'Profile Load Notice',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your account was authenticated, but we couldn\'t load your FindiPro profile. Please try again.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await AuthService().ensureProfileSynced(firebaseUser);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Profile Load'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => AuthService().logout(),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            // Route dynamically based on Supabase profile role
            if (userModel.isAdmin || userModel.role == 'admin') {
              return const AdminDashboardScreen();
            }

            // Customer, Provider, Technician experience
            return const MainScreen();
          },
        );
      },
    );
  }
}