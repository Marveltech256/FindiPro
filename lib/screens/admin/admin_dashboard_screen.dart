import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Widget _card(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card('Users', Icons.people, const Color(0xFF2563EB)),
          const SizedBox(height: 14),
          _card('Providers', Icons.work, const Color(0xFF22C55E)),
          const SizedBox(height: 14),
          _card('Reports', Icons.report, const Color(0xFFDC2626)),
          const SizedBox(height: 14),
          _card('Moderation', Icons.gavel, const Color(0xFFEA580C)),
        ],
      ),
    );
  }
}