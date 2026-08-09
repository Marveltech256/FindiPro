import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:findipro/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/distance_service.dart';
import '../../models/user_model.dart';
import '../provider/provider_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

  Position? _currentPosition;
  List<UserModel> _nearbyProviders = [];
  bool _loadingNearby = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Plumbing', 'icon': Icons.plumbing},
    {'name': 'Electrical', 'icon': Icons.electrical_services},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services},
    {'name': 'Mechanic', 'icon': Icons.car_repair},
    {'name': 'Painting', 'icon': Icons.format_paint},
    {'name': 'Gardening', 'icon': Icons.yard},
  ];

  final List<Map<String, dynamic>> _providers = [
    {
      'name': 'Grace Nabirye',
      'service': 'Electrical',
      'location': 'Bugolobi, Kampala',
      'rating': 4.9,
      'reviews': 98,
    },
    {
      'name': 'Daniel Ssemanda',
      'service': 'Plumbing',
      'location': 'Ntinda, Kampala',
      'rating': 4.8,
      'reviews': 76,
    },
    {
      'name': 'Sarah Nakato',
      'service': 'Cleaning',
      'location': 'Kisaasi, Kampala',
      'rating': 5.0,
      'reviews': 42,
    },
  ];

  Future<void> _refresh() async {
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final location = await LocationService().getCurrentLocation();
    debugPrint('Location: ${location?.latitude}, ${location?.longitude}');
  }

  Future<void> _loadNearbyProviders(List<UserModel> providers) async {
    setState(() => _loadingNearby = true);

    final position = await LocationService().getCurrentLocation();

    if (position == null) {
      setState(() => _loadingNearby = false);
      return;
    }

    _currentPosition = position;

    final nearby = providers.where((provider) {
      return provider.latitude != null && provider.longitude != null;
    }).toList();

    nearby.sort((a, b) {
      final da = DistanceService.distanceKm(
        startLat: position.latitude,
        startLng: position.longitude,
        endLat: a.latitude!,
        endLng: a.longitude!,
      );

      final db = DistanceService.distanceKm(
        startLat: position.latitude,
        startLng: position.longitude,
        endLat: b.latitude!,
        endLng: b.longitude!,
      );

      return da.compareTo(db);
    });

    setState(() {
      _nearbyProviders = nearby.take(5).toList();
      _loadingNearby = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSearchBar(),
              const SizedBox(height: 28),
              _buildNearbyBanner(),
              const SizedBox(height: 32),
              const SizedBox(height: 16),
              Text(
                'Near You',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_loadingNearby)
                const Center(child: CircularProgressIndicator())
              else if (_nearbyProviders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Enable location to see nearby service providers.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _nearbyProviders.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final provider = _nearbyProviders[index];

                      final distance = DistanceService.distanceKm(
                        startLat: _currentPosition!.latitude,
                        startLng: _currentPosition!.longitude,
                        endLat: provider.latitude!,
                        endLng: provider.longitude!,
                      );

                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProviderDetailScreen(provider: provider),
                            ),
                          );
                        },
                        child: Container(
                          width: 260,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(provider.category ?? 'Service Provider'),
                              const Spacer(),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 4),
                                  Text('${distance.toStringAsFixed(1)} km away'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              _buildSectionTitle('Popular Categories'),
              const SizedBox(height: 16),
              _buildCategoriesGrid(),
              const SizedBox(height: 32),
              _buildSectionTitle('Nearby Service Providers'),
              const SizedBox(height: 16),
              ..._providers.map(_buildProviderCard),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hello Marvin 👋',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: const [
                  Icon(Icons.location_on, size: 18, color: Color(0xFF06B6D4)),
                  SizedBox(width: 4),
                  Text(
                    'Kampala, Uganda',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF06B6D4)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.person, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search nearby providers...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.my_location),
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildNearbyBanner() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find experts near you',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enable location and discover trusted professionals within a few kilometers.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.location_searching),
                  label: const Text('Use my location'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.place_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text('View all'),
        ),
      ],
    );
  }

  Widget _buildCategoriesGrid() {
    return GridView.builder(
      itemCount: _categories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final category = _categories[index];
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    category['icon'] as IconData,
                    color: const Color(0xFF06B6D4),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  category['name'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF06B6D4), Color(0xFF22C55E)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider['name'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider['service'] as String,
                        style: const TextStyle(
                          color: Color(0xFF06B6D4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              provider['location'] as String,
                              style: const TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 18,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${provider['rating']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${provider['reviews']} reviews)',
                            style: const TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}