import 'package:flutter/material.dart';
import '../../core/utils/category_icons.dart';
import '../category_providers_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const _categories = [
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Mechanic',
    'Painting',
    'Gardening',
    'Carpentry',
    'Moving',
    'Beauty',
    'Construction',
    'IT & Technology',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtleBorder = theme.colorScheme.outline.withAlpha(40);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Categories',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a service and find approved professionals.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.25,
              ),
              itemBuilder: (context, index) {
                final name = _categories[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryProvidersScreen(category: name),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: subtleBorder),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withAlpha(30),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            categoryIcon(name),
                            color: const Color(0xFF06B6D4),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
