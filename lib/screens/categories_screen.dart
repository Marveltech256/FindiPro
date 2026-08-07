import 'package:flutter/material.dart';
import 'package:findipro/data/mock_data.dart';
import 'package:findipro/widgets/category_card.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Categories'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        itemCount: MockData.categories.length,
        itemBuilder: (context, index) {
          return CategoryCard(
            category: MockData.categories[index],
          );
        },
      ),
    );
  }
}