import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import '../screens/provider_profile_screen.dart';

class ProviderCard extends StatelessWidget {
  final ServiceProvider provider;

  const ProviderCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProviderProfileScreen(provider: provider),
            ),
          );
        },
        child: ListTile(
          leading: CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(provider.profileImageUrl),
          ),
          title: Text(provider.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${provider.category} • ${provider.location}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),
              Text(provider.rating.toString()),
            ],
          ),
        ),
      ),
    );
  }
}