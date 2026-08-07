import 'package:flutter/material.dart';
import 'package:findipro/data/mock_data.dart';
import 'package:findipro/models/category_model.dart';
import 'package:findipro/screens/provider_card.dart';

class CategoryProvidersScreen extends StatelessWidget {
  final Category category;
  const CategoryProvidersScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    // Filter providers based on the selected category
    final filteredProviders = MockData.providers
        .where((provider) => provider.category == category.name)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
      ),
      body: filteredProviders.isEmpty
          ? Center(
              child: Text(
                'No providers found for this category.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: filteredProviders.length,
              itemBuilder: (context, index) {
                return ProviderCard(provider: filteredProviders[index]);
              },
            ),
    );
  }
}