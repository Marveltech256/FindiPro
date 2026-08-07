import 'package:flutter/material.dart';

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Dashboard'),
      ),
      body: const Center(
        child: Text('Welcome, Provider! Your incoming requests will appear here.'),
      ),
    );
  }
}