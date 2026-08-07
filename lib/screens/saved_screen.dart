import 'package:flutter/material.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement with SavedProviderService and FutureBuilder
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Providers'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Your saved providers will appear here.', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}