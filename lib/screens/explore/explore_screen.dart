import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../../services/distance_service.dart';
import '../../services/location_service.dart';
import '../Provider/provider_detail_screen.dart';
import '../category_providers_screen.dart';
import '../../core/utils/category_icons.dart';

class ExploreScreen extends StatefulWidget { const ExploreScreen({super.key}); @override State<ExploreScreen> createState()=>_ExploreScreenState(); }
class _ExploreScreenState extends State<ExploreScreen>{
  Position? _position; bool _locationLoading=false;
  final TextEditingController _search = TextEditingController();
  final _repo=UserRepository();
  List<UserModel> _providers = [];
  final _categories=const ['Plumbing','Electrical','Cleaning','Mechanic','Painting','Gardening','Carpentry','Moving','Beauty','Construction','IT & Technology','Other'];
  String _searchQuery = '';
  String _locationQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProviders();
    _useLocation();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'provider')
        .where('isApproved', isEqualTo: true)
        .get();

    final providers =
        snapshot.docs.map((d) => UserModel.fromFirestore(d)).toList();

    providers.sort((a, b) {
      final aScore =
          (a.premium ? 2 : 0) + (a.verified ? 1 : 0);

      final bScore =
          (b.premium ? 2 : 0) + (b.verified ? 1 : 0);

      return bScore.compareTo(aScore);
    });

    try {
      final position = await Geolocator.getCurrentPosition();

      providers.sort((a, b) {
        final da = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          a.latitude ?? 0,
          a.longitude ?? 0,
        );

        final db = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          b.latitude ?? 0,
          b.longitude ?? 0,
        );

        return da.compareTo(db);
      });
    } catch (_) {
      // Ignore location errors; keep original order
    }

    if (mounted) {
      setState(() => _providers = providers);
    }
  }

  Future<void> _useLocation() async {
    setState(() => _locationLoading = true);
    final p = await LocationService().getCurrentLocation();
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
                stream: _repo.getProvidersStream(), // This can be removed if _loadProviders is sufficient
                builder: (context, s) {
                  if (s.connectionState == ConnectionState.waiting && _providers.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.hasError) {
                    return Center(child: Text('Could not load providers. ${s.error}'));
                  }

                  // Use stream data if available, otherwise use the one-time loaded data
                  final allProviders = s.hasData ? s.data! : _providers;

                  return RefreshIndicator(
                      onRefresh: _useLocation,
                      child: ListView(padding: const EdgeInsets.all(20), children: [
                        Row(children: [
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Hello ${FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ?? 'there'} 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.location_on, size: 18, color: Color(0xFF06B6D4)),
                              const SizedBox(width: 4),
                              Expanded(child: Text(_position == null ? 'Location unavailable' : 'Service providers near your location', style: const TextStyle(color: Colors.black54)))
                            ])
                          ])),
                          const CircleAvatar(radius: 26, child: Icon(Icons.person))
                        ]),
                        const SizedBox(height: 22),
                        // Search Fields
                        TextField(
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
                          },
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
                            suffixIcon: IconButton(onPressed: _useLocation, icon: _locationLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location)),
                          ),
                          onChanged: (value) {
                            setState(() => _locationQuery = value);
                          },
                        ),
                        const SizedBox(height: 24),
                        Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF06B6D4)])),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Find trusted experts nearby', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              const Text('Search by profession, service or location.', style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(onPressed: _useLocation, icon: const Icon(Icons.location_searching), label: const Text('Use my location'))
                            ])),
                        const SizedBox(height: 28),
                        _title('Categories'),
                        const SizedBox(height: 12),
                        SizedBox(height: 110, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _categories.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (c, i) => _categoryTile(c, _categories[i]))),
                        const SizedBox(height: 28),
                        _title('Available providers'),
                        const SizedBox(height: 12),
                        Builder(builder: (context) {
                          final filteredProviders = allProviders.where((provider) {
                            final search = _searchQuery.toLowerCase();
                            final location = _locationQuery.toLowerCase();

                            final hay = [provider.name, provider.category ?? '', provider.location ?? '', provider.businessName ?? '', provider.about ?? '', ...provider.skills].join(' ').toLowerCase();
                            final matchesSearch = search.isEmpty || hay.contains(search);

                            final matchesLocation = location.isEmpty || (provider.location ?? '').toLowerCase().contains(location);

                            return matchesSearch && matchesLocation;
                          }).toList();

                          if (filteredProviders.isEmpty) {
                            return const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No providers match your search.')));
                          }

                          return Column(
                            children: filteredProviders.map((p) => _providerCard(context, p)).toList(),
                          );
                        }),
                      ]));
                })));
  }

  Widget _title(String t) => Row(children: [Expanded(child: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))), if (t == 'Categories') const SizedBox()]);

  Widget _categoryTile(BuildContext c, String name) => InkWell(
      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CategoryProvidersScreen(category: name))),
      child: Container(
          width: 110,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black12)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(categoryIcon(name), color: const Color(0xFF06B6D4)), const SizedBox(height: 8), Text(name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))])));

  Widget _providerCard(BuildContext c, UserModel p) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: p))),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    CircleAvatar(radius: 34, backgroundImage: p.photoUrl == null ? null : NetworkImage(p.photoUrl!), child: p.photoUrl == null ? const Icon(Icons.person) : null),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.businessName?.isNotEmpty == true ? p.businessName! : p.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (p.verified)
                            const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(p.category ?? 'Service provider', style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(p.location ?? 'Location not specified', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 5),
                      Row(children: [const Icon(Icons.star, size: 16, color: Colors.amber), Text(' ${p.rating.toStringAsFixed(1)} (${p.reviewCount})')])
                    ])),
                    const Icon(Icons.chevron_right)
                  ])))));
}
