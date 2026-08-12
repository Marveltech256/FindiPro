import 'package:flutter/material.dart';
import '../../models/user_model.dart';

class ProviderDetailScreen extends StatefulWidget {
  final UserModel provider;

  const ProviderDetailScreen({super.key, required this.provider});

  @override
  State<ProviderDetailScreen> createState() =>
      _ProviderDetailScreenState();
}

class _ProviderDetailScreenState
    extends State<ProviderDetailScreen> {
  bool _isSaved = false;

  void _toggleSaved() {
    setState(() {
      _isSaved = !_isSaved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            actions: [
              IconButton(
                onPressed: _toggleSaved,
                icon: Icon(
                  _isSaved
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: Colors.white,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: widget.provider.photoUrl != null &&
                      widget.provider.photoUrl!.isNotEmpty
                  ? Image.network(
                      widget.provider.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatar(),
                    )
                  : _avatar(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.provider.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      if (widget.provider.verified)
                        const Icon(
                          Icons.verified,
                          color: Colors.blue,
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    widget.provider.category ??
                        'Service Provider',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color:
                              const Color(0xFF06B6D4),
                        ),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.provider.location ??
                              'Kampala',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _heading('About'),

                  Text(
                    widget.provider.bio ??
                        'This professional has not added an about section yet.',
                    style:
                        const TextStyle(height: 1.5),
                  ),

                  const SizedBox(height: 24),

                  _heading('Professional details'),

                  _info(Icons.phone, 'Phone',
                      widget.provider.phone),

                  _info(Icons.email_outlined, 'Email',
                      widget.provider.email),

                  const SizedBox(height: 24),

                  _heading('Portfolio'),

                  _gallerySection(
                      widget.provider.images ?? []),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.work),
                      label:
                          const Text('Request Service'),
                      onPressed: () {
                        // Navigate to hire screen later.
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(
                          Icons.rate_review_outlined),
                      label:
                          const Text('Write Review'),
                      onPressed: () {
                        // Navigate to review screen later.
                      },
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Text(
          widget.provider.name.isEmpty
              ? '?'
              : widget.provider.name[0]
                  .toUpperCase(),
          style: const TextStyle(
            fontSize: 72,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _heading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _info(
      IconData icon, String title, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            const Color(0xFF06B6D4)
                .withValues(alpha: 0.12),
        child: Icon(icon,
            color: const Color(0xFF06B6D4)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 12,
        ),
      ),
      subtitle: Text(
        value.isEmpty ? 'Not provided' : value,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _gallerySection(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
            'No portfolio images yet'),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius:
                BorderRadius.circular(16),
            child: Image.network(
              images[index],
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
}