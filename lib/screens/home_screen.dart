import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/provider_model.dart';
import '../widgets/category_card.dart';
import '../widgets/provider_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ServiceProvider> _filteredProviders = MockData.providers;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProviders);
  }
  
  void _filterProviders() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProviders = MockData.providers.where((provider) {
        final providerText = '${provider.name} ${provider.category} ${provider.location}'.toLowerCase();
        return providerText.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text('Hi there 👋', style: textTheme.bodyLarge),
              Text('Find a pro for the job', style: textTheme.headlineSmall),
              const SizedBox(height: 24),

              // Search Field
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search plumber, mechanic...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 24),

              // Categories Section
              Text('Categories', style: textTheme.titleLarge),
              const SizedBox(height: 16),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: MockData.categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return CategoryCard(category: MockData.categories[index]);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Providers Section
              Text('Top Rated Providers', style: textTheme.titleLarge),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredProviders.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return ProviderCard(provider: _filteredProviders[index]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}