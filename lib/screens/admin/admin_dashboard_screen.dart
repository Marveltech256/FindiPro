import 'package:flutter/material.dart';
import 'admin_users_screen.dart';
import 'verification_requests_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Widget _tile(BuildContext context,
      String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(context, 'Users', Icons.people, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
          }),
          _tile(context, 'Providers', Icons.store, () {}),
          _tile(context, 'Verification Requests',
              Icons.verified_user, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationRequestsScreen()));
          }),
          _tile(context, 'Reports', Icons.flag_outlined, () {}),
          _tile(context, 'Notifications',
              Icons.notifications_outlined, () {}),
          _tile(context, 'Analytics', Icons.bar_chart, () {}),
        ],
      ),
    );
  }
}
