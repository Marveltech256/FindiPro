import 'package:flutter/material.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Plumbing', 'icon': Icons.plumbing, 'color': Color(0xFF06B6D4)},
    {'name': 'Electrical', 'icon': Icons.electrical_services, 'color': Color(0xFF0F172A)},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services, 'color': Color(0xFF22C55E)},
    {'name': 'Mechanic', 'icon': Icons.car_repair, 'color': Color(0xFF2563EB)},
    {'name': 'Painting', 'icon': Icons.format_paint, 'color': Color(0xFFEA580C)},
    {'name': 'Gardening', 'icon': Icons.yard, 'color': Color(0xFF16A34A)},
    {'name': 'Carpentry', 'icon': Icons.handyman, 'color': Color(0xFF92400E)},
    {'name': 'Moving', 'icon': Icons.local_shipping, 'color': Color(0xFF475569)},
    {'name': 'Beauty', 'icon': Icons.face_retouching_natural, 'color': Color(0xFFDB2777)},
    {'name': 'Tutoring', 'icon': Icons.menu_book, 'color': Color(0xFF7C3AED)},
    {'name': 'Photography', 'icon': Icons.camera_alt, 'color': Color(0xFF111827)},
    {'name': 'IT Support', 'icon': Icons.computer, 'color': Color(0xFF0891B2)},
  ];

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _categories
        .where((c) => (c['name'] as String)
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Categories',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Find trusted professionals by service type.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),

            // Search
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _query = value);
              },
              decoration: InputDecoration(
                hintText: 'Search categories...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Featured banner
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF22C55E)],
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
                          'Need help nearby?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Discover professionals closest to your location in just one tap.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F172A),
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
                          label: const Text('Search nearby'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.place_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'All Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${filtered.length} services',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),

            const SizedBox(height: 18),

            GridView.builder(
              itemCount: filtered.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final category = filtered[index];
                final color = category['color'] as Color;

                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${category['name']} selected'),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            category['icon'] as IconData,
                            color: color,
                            size: 30,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          category['name'] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Trusted local experts',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}