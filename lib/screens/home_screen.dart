import 'package:findipro/models/user_model.dart';
import 'package:findipro/repositories/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userRepository = context.read<UserRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FindiPro'),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: userRepository.getProvidersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load providers: ${snapshot.error}'),
            );
          }

          final providers = snapshot.data ?? [];

          if (providers.isEmpty) {
            return const Center(
              child: Text('No service providers available yet.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: providers.length,
              itemBuilder: (context, index) {
                final provider = providers[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: provider.photoUrl != null &&
                              provider.photoUrl!.isNotEmpty
                          ? NetworkImage(provider.photoUrl!)
                          : null,
                      child: provider.photoUrl == null ||
                              provider.photoUrl!.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(provider.name),
                    subtitle: Text(
                      '${provider.category ?? 'Service Provider'} • ${provider.location ?? 'Kampala'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // This part is a placeholder. The ProviderProfileScreen needs to be updated
                      // to accept a providerId and fetch the data itself.
                      // For now, this will cause an error if ProviderProfileScreen expects a ServiceProvider object.
                      // We will address this in a later step.
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}