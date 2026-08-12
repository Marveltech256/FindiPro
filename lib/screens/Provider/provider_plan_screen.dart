import 'package:flutter/material.dart';

class ProviderPlanScreen extends StatelessWidget {
  const ProviderPlanScreen({super.key});

  Widget _planCard(
    BuildContext context, {
    required String title,
    required String price,
    required List<String> features,
    required bool current,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (current)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Current',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: current ? null : () {},
                child: Text(current ? 'Active' : 'Coming Soon'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provider Plans')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _planCard(
            context,
            title: 'Basic',
            price: 'Free',
            current: true,
            features: const [
              'Create provider profile',
              'Receive customer enquiries',
              'List services',
            ],
          ),
          _planCard(
            context,
            title: 'FindiPro Verified',
            price: 'UGX 10,000/month',
            current: false,
            features: const [
              'Verified badge',
              'Identity verification',
              'Higher customer trust',
            ],
          ),
          _planCard(
            context,
            title: 'FindiPro Premium',
            price: 'UGX 25,000/month',
            current: false,
            features: const [
              'Priority ranking',
              'Featured placement',
              'Analytics dashboard',
              'More photos',
              'Unlimited services',
            ],
          ),
        ],
      ),
    );
  }
}