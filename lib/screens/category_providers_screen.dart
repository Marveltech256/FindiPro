import 'package:findipro/models/user_model.dart';
import 'package:findipro/repositories/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CategoryProvidersScreen extends StatelessWidget {
  final String category;

  const CategoryProvidersScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<UserRepository>();

    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: StreamBuilder<List<UserModel>>(
        stream: repo.getProvidersStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final providers = snapshot.data!
              .where((p) =>
                  (p.category ?? '').toLowerCase() ==
                  category.toLowerCase())
              .toList();

          if (providers.isEmpty) {
            return Center(child: Text('No providers found for $category'));
          }

          return ListView.builder(
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];

              return ListTile(
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
                subtitle: Text(provider.location ?? 'Kampala'),
                onTap: () {
                  // This part is a placeholder. The ProviderProfileScreen needs to be updated
                  // to accept a providerId and fetch the data itself.
                },
              );
            },
          );
        },
      ),
    );
  }
}