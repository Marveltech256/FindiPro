import 'package:flutter/material.dart';
import '../../models/user_model.dart';

class ProviderDetailScreen extends StatelessWidget {
  final UserModel provider;

  const ProviderDetailScreen({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: provider.photoUrl != null && provider.photoUrl!.isNotEmpty
                  ? Image.network(
                      provider.photoUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.primary,
                      child: Center(
                        child: Text(
                          provider.name.isNotEmpty
                              ? provider.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 72,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    provider.category ?? 'Service Provider',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          provider.location ?? 'Kampala',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        '${provider.rating ?? 4.8}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${provider.reviewCount ?? 0} reviews',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'About',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    provider.about ??
                        'Experienced professional service provider committed to quality work and customer satisfaction.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Skills',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: (provider.skills ?? ['Professional'])
                        .map(
                          (skill) => Chip(
                            label: Text(skill),
                          ),
                        )
                        .toList(),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Experience',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '${provider.yearsExperience ?? 1} years experience',
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Availability',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(
                        provider.available == false
                            ? Icons.cancel
                            : Icons.check_circle,
                        color: provider.available == false
                            ? Colors.red
                            : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        provider.available == false
                            ? 'Currently unavailable'
                            : 'Available now',
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Call feature coming next phase'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('WhatsApp feature coming next phase'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Hire request feature coming next phase'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.handshake),
                      label: const Text(
                        'Request to Hire',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}