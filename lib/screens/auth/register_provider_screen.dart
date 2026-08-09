import 'package:flutter/material.dart';

class RegisterProviderScreen extends StatelessWidget {
  const RegisterProviderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provider Registration')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          TextField(decoration: InputDecoration(labelText: 'Full name')),
          SizedBox(height: 16),
          TextField(decoration: InputDecoration(labelText: 'Service category')),
          SizedBox(height: 16),
          TextField(decoration: InputDecoration(labelText: 'Location')),
          SizedBox(height: 16),
          TextField(decoration: InputDecoration(labelText: 'Phone')),
        ],
      ),
    );
  }
}