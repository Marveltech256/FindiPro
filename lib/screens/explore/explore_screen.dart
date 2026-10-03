import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../../services/location_service.dart';
import '../provider/provider_detail_screen.dart';
import '../category_providers_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../core/utils/category_icons.dart';
import '../../repositories/notification_repository.dart';
import '../../services/analytics_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  Position? _position;
  bool _locationLoading = false;
  final TextEditingController _search = TextEditingController();
  final _repo = UserRepository();
  final _locationService = LocationService();
  UserModel? _me;
  final _categories = const [
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
  String _searchQuery = '';
  String _locationQuery = '';

  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _useLocation();
    _loadMe();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) {
        _loadMe();
      }
    });
  }

  Future<void> _loadMe() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _me = null);
      return;
    }
    final me = await _repo.getUser(uid);
    if (mounted) {
      setState(() => _me = me);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    setState(() => _locationLoading = true);
    final p = await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _position = p;
        _locationLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<UserModel>>(
          stream: _repo.getProvidersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Could not load providers. ${snapshot.error}'));
            }

            final rawProviders = snapshot.data ?? [];
            final sortedProviders = LocationService.sortProvidersByDistance(rawProviders, _position);

            return RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_useLocation(), _loadMe()]);
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello ${(_me != null && _me!.name.isNotEmpty ? _me!.name.split(' ').first : null) ?? FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ?? 'there'} 👋',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 18, color: Color(0xFF06B6D4)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _position == null
                                        ? 'Location unavailable (showing all providers)'
                                        : 'Showing providers near your location',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      StreamBuilder<int>(
                        stream: FirebaseAuth.instance.currentUser?.uid != null
                            ? NotificationRepository().getUnreadCountStream(FirebaseAuth.instance.currentUser!.uid)
                            : Stream.value(0),
                        builder: (context, notifSnapshot) {
                          final unread = notifSnapshot.data ?? 0;
                          return Stack(
                            alignment: Alignment.topRight,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined, size: 28),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                  );
                                },
                              ),
                              if (unread > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ClipOval(
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: (_me?.photoUrl != null && _me!.photoUrl!.isNotEmpty)
                              ? Image.network(
                                  _me!.photoUrl!,
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFF06B6D4).withAlpha(30),
                                    child: const Icon(Icons.person, color: Color(0xFF06B6D4)),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF06B6D4).withAlpha(30),
                                  child: const Icon(Icons.person, color: Color(0xFF06B6D4)),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  // Search Fields
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search services or providers',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      if (value.trim().length >= 3) {
                        AnalyticsService().trackSearch(query: value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(right: 6, top: 6),
                          child: Text('Suggested:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                        ),
                        ...['Plumbing', 'Electrical', 'Cleaning', 'Mechanic', 'Painting', 'Ntinda', 'Kampala'].map((s) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Theme.of(context).cardColor,
                                side: BorderSide(color: const Color(0xFF06B6D4).withAlpha(50)),
                                onPressed: () {
                                  _search.text = s;
                                  setState(() => _searchQuery = s);
                                  AnalyticsService().trackSearch(query: s);
                                },
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by location (e.g. Ntinda, Kampala)',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        onPressed: _useLocation,
                        icon: _locationLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _locationQuery = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF06B6D4)]),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Find trusted experts nearby',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Search by profession, service or location.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _useLocation,
                          icon: const Icon(Icons.location_searching),
                          label: const Text('Use my location'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _title('Categories'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (c, i) => _categoryTile(c, _categories[i]),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _title('Available providers'),
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final filteredProviders = sortedProviders.where((provider) {
                      final search = _searchQuery.toLowerCase();
                      final location = _locationQuery.toLowerCase();

                      final hay = [
                        provider.name,
                        provider.category ?? '',
                        provider.location ?? '',
                        provider.businessName ?? '',
                        provider.about ?? '',
                        ...provider.skills
                      ].join(' ').toLowerCase();

                      final matchesSearch = search.isEmpty || hay.contains(search);
                      final matchesLocation = location.isEmpty ||
                          (provider.location ?? '').toLowerCase().contains(location);

                      return matchesSearch && matchesLocation;
                    }).toList();

                    if (filteredProviders.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(30),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              const Text('No providers match your search.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: filteredProviders.map((p) => _providerCard(context, p)).toList(),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _title(String t) => Row(children: [
        Expanded(child: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
        if (t == 'Categories') const SizedBox(),
      ]);

  Widget _categoryTile(BuildContext c, String name) => InkWell(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CategoryProvidersScreen(category: name))),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 110,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Theme.of(context).dividerColor.withAlpha(40)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(categoryIcon(name), color: const Color(0xFF06B6D4), size: 28),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
        ),
      );

  Widget _providerCard(BuildContext c, UserModel p) {
    String? distanceText;
    if (_position != null && p.latitude != null && p.longitude != null && (p.latitude != 0 || p.longitude != 0)) {
      final dKm = LocationService.calculateDistanceKm(
        _position!.latitude,
        _position!.longitude,
        p.latitude!,
        p.longitude!,
      );
      distanceText = LocationService.formatDistance(dKm);
    }

    final hasPhoto = p.photoUrl != null && p.photoUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Theme.of(c).cardColor,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: p))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: hasPhoto
                        ? Image.network(
                            p.photoUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF06B6D4).withAlpha(25),
                              child: const Icon(Icons.person, size: 34, color: Color(0xFF06B6D4)),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF06B6D4).withAlpha(25),
                            child: const Icon(Icons.person, size: 34, color: Color(0xFF06B6D4)),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.businessName?.isNotEmpty == true ? p.businessName! : (p.name.isNotEmpty ? p.name : 'Service Provider'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (p.isPremiumBadge) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706).withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFD97706), width: 0.8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.stars, color: Color(0xFFD97706), size: 12),
                                        SizedBox(width: 3),
                                        Text(
                                          'PREMIUM',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (p.isVerifiedBadge) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: Colors.blue, size: 18),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.category ?? 'Service provider',
                        style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.location ?? 'Location not specified',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (distanceText != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                distanceText,
                                style: const TextStyle(
                                  color: Color(0xFF0891B2),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          Text(' ${p.rating.toStringAsFixed(1)} (${p.reviewCount})'),
                          const Spacer(),
                          if (p.available)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Available',
                                style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}