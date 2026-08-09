import 'package:flutter/material.dart';

class ProviderProfileScreen extends StatefulWidget {
  final Map<String, dynamic> provider;

  const ProviderProfileScreen({
    super.key,
    required this.provider,
  });

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  bool isSaved = false;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: const Color(0xFF0057FF),
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(
                    provider['image'] ??
                        'https://images.unsplash.com/photo-1522202176988-66273c2fd55f',
                    fit: BoxFit.cover,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        isSaved = !isSaved;
                      });
                    },
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider['name'] ?? 'Service Provider',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(Icons.work_outline,
                              color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Text(provider['category'] ?? 'Service'),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              provider['location'] ?? 'Kampala',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '\${provider['rating'] ?? '4.8'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(\${provider['reviews'] ?? '120'} reviews)',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _buildInfoCard(
                        icon: Icons.phone,
                        title: 'Phone',
                        value: provider['phone'] ?? '+256 700 000000',
                      ),

                      const SizedBox(height: 12),

                      _buildInfoCard(
                        icon: Icons.email_outlined,
                        title: 'Email',
                        value: provider['email'] ?? 'provider@example.com',
                      ),

                      const SizedBox(height: 12),

                      _buildInfoCard(
                        icon: Icons.access_time,
                        title: 'Experience',
                        value:
                            '\${provider['experience'] ?? '5'} years',
                      ),

                      const SizedBox(height: 12),

                      _buildInfoCard(
                        icon: Icons.attach_money,
                        title: 'Price Range',
                        value:
                            provider['price'] ?? 'UGX 50,000 - 150,000',
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'About',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        provider['about'] ??
                            'Professional service provider with years of experience delivering quality work.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Skills',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _skillChip('Installation'),
                          _skillChip('Repair'),
                          _skillChip('Maintenance'),
                          _skillChip('Emergency Service'),
                        ],
                      ),

                      const SizedBox(height: 28),

                      const Text(
                        'Recent Reviews',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _reviewCard(
                        name: 'Sarah N.',
                        rating: 5,
                        comment:
                            'Excellent service. Arrived on time and fixed the issue perfectly.',
                      ),

                      const SizedBox(height: 12),

                      _reviewCard(
                        name: 'David M.',
                        rating: 4,
                        comment:
                            'Professional and friendly. I would hire again.',
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text('Rate this provider'),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFF0057FF)),
                            foregroundColor: const Color(0xFF0057FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Hire request feature coming next phase'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0057FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 6,
              ),
              child: const Text(
                'Request to Hire',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE6EEFF),
            child: Icon(icon, color: const Color(0xFF0057FF)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0057FF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _reviewCard({
    required String name,
    required int rating,
    required String comment,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF2FF),
                child: Text(name[0]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    size: 18,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: TextStyle(color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}