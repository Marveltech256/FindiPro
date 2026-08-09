import 'package:flutter/material.dart';

class RegisterClientScreen extends StatelessWidget {
  const RegisterClientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client Registration')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          TextField(decoration: InputDecoration(labelText: 'Full name')),
          SizedBox(height: 16),
          TextField(decoration: InputDecoration(labelText: 'Email')),
          SizedBox(height: 16),
          TextField(decoration: InputDecoration(labelText: 'Phone')),
          SizedBox(height: 16),
          TextField(decoration: InputDecoration(labelText: 'Password')),
        ],
      ),
    );
  }
}