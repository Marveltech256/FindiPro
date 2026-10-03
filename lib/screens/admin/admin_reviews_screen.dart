import 'package:flutter/material.dart';
import '../../core/config/supabase_config.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  String _searchQuery = '';
  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await SupabaseConfig.client
          .from('reviews')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('>>> [AdminReviewsScreen._loadReviews] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review? This action will recalculate the provider\'s rating automatically and cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseConfig.client.from('reviews').delete().eq('id', reviewId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review deleted successfully.')),
          );
        }
        _loadReviews();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete review.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredReviews = _reviews.where((r) {
      if (_searchQuery.isNotEmpty) {
        final comment = (r['comment'] ?? '').toString().toLowerCase();
        final customerName = (r['customer_name'] ?? '').toString().toLowerCase();
        return comment.contains(_searchQuery) || customerName.contains(_searchQuery);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews Moderation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReviews,
            tooltip: 'Refresh Reviews',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search reviews by comment or customer name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : RefreshIndicator(
                    onRefresh: _loadReviews,
                    child: filteredReviews.isEmpty
                        ? Center(
                            child: ListView(
                              shrinkWrap: true,
                              children: const [
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('No reviews found.'),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredReviews.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final r = filteredReviews[index];
                              final id = (r['id'] ?? '').toString();
                              final customerName = (r['customer_name'] ?? 'Client').toString();
                              final comment = (r['comment'] ?? '').toString();
                              final rating = (r['rating'] as num?)?.toDouble() ?? 0.0;
                              final createdAt = (r['created_at'] ?? '').toString();

                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            customerName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Row(
                                            children: List.generate(
                                              5,
                                              (star) => Icon(
                                                star < rating.floor() ? Icons.star : Icons.star_border,
                                                color: Colors.amber,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (comment.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(comment, style: const TextStyle(fontSize: 13)),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Date: ${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                          TextButton.icon(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                                            label: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 12)),
                                            onPressed: () => _deleteReview(id),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
