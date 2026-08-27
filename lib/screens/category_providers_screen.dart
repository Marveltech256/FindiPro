import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/location_service.dart';
import 'Provider/provider_detail_screen.dart';

class CategoryProvidersScreen extends StatelessWidget {
  final String category;

  const CategoryProvidersScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: StreamBuilder<List<UserModel>>(
        stream: UserRepository().getProvidersStream(),
        builder: (context, s) {
          if (s.hasError) {
            return const Center(child: Text('Unable to load providers.'));
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawProviders = s.data!
              .where((p) => (p.category ?? '').toLowerCase() == category.toLowerCase())
              .toList();

          if (rawProviders.isEmpty) {
            return Center(child: Text('No approved providers found for $category.'));
          }

          final providers = LocationService.sortProvidersByDistance(rawProviders, null);

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: providers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = providers[i];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                leading: CircleAvatar(
                  backgroundImage: p.photoUrl == null ? null : NetworkImage(p.photoUrl!),
                  child: p.photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.businessName?.isNotEmpty == true ? p.businessName! : p.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (p.isPremiumBadge)
                      const Icon(Icons.stars, color: Color(0xFFD97706), size: 18)
                    else if (p.isVerifiedBadge)
                      const Icon(Icons.verified, color: Colors.blue, size: 18),
                  ],
                ),
                subtitle: Text('${p.location ?? 'Location not specified'} • ${p.rating.toStringAsFixed(1)} ★'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: p)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
