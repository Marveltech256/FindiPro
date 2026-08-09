import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/provider_model.dart';
import '../theme/app_theme.dart';

class ProviderCard extends StatelessWidget {
  final ServiceProvider provider;

  const ProviderCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: provider.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 80,
                  height: 80,
                  color: AppTheme.subtleBorderColor.withValues(alpha: 0.5),
                  child: const Center(child: Icon(Icons.image, color: AppTheme.iconColor)),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.business, size: 40, color: AppTheme.iconColor),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${provider.category} • ${provider.location}',
                    style: textTheme.bodySmall?.copyWith(color: AppTheme.iconColor),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(provider.rating.toString(), style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                // TODO: Navigate to provider detail screen
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentColor,
                backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }
}