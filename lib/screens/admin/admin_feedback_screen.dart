import 'package:flutter/material.dart';
import '../../models/feedback_model.dart';
import '../../repositories/feedback_repository.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final _feedbackRepo = FeedbackRepository();
  String _selectedFilter = 'all'; // 'all', 'feedback', 'feature_request'
  bool _loading = true;
  List<FeedbackItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await _feedbackRepo.getAllFeedbackForAdmin(typeFilter: _selectedFilter);
      if (mounted) {
        setState(() {
          _items = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showUpdateStatusDialog(FeedbackItem item) {
    String status = item.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(item.isFeatureRequest ? 'Update Feature Status' : 'Update Feedback Status'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                    DropdownMenuItem(value: 'planned', child: Text('Planned')),
                    DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'declined', child: Text('Declined')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => status = v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _feedbackRepo.updateStatus(item.id, status);
                  _loadData();
                },
                child: const Text('Save Status'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'in_progress':
        return Colors.purple;
      case 'planned':
        return const Color(0xFF0284C7);
      case 'under_review':
        return const Color(0xFFD97706);
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedbackCount = _items.where((i) => i.isFeedback).length;
    final featureCount = _items.where((i) => i.isFeatureRequest).length;
    
    final feedbackRatings = _items.where((i) => i.isFeedback && i.rating > 0).map((i) => i.rating).toList();
    final avgRating = feedbackRatings.isNotEmpty
        ? (feedbackRatings.reduce((a, b) => a + b) / feedbackRatings.length)
        : 5.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Feedback & Feature Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Overview Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF06B6D4).withAlpha(60)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Average App Rating', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Text('(${feedbackRatings.length})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.purple.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.purple.withAlpha(60)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Feature Requests', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.lightbulb_outline, color: Colors.purple, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '$featureCount',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Segmented Filters
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'all', label: Text('All (${_items.length})')),
                ButtonSegment(value: 'feedback', label: Text('Feedback ($feedbackCount)')),
                ButtonSegment(value: 'feature_request', label: Text('Features ($featureCount)')),
              ],
              selected: {_selectedFilter},
              onSelectionChanged: (newSelection) {
                setState(() => _selectedFilter = newSelection.first);
                _loadData();
              },
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No feedback entries found in this category.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ..._items.map((item) {
                final statusColor = _getStatusColor(item.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.isFeatureRequest ? Colors.purple.withAlpha(30) : const Color(0xFF06B6D4).withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.isFeatureRequest ? 'FEATURE REQUEST' : 'FEEDBACK',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: item.isFeatureRequest ? Colors.purple : const Color(0xFF0891B2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                          const Spacer(),
                          if (item.isFeatureRequest) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_drop_up, size: 16, color: Colors.blue),
                                  Text('${item.votes} votes', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          InkWell(
                            onTap: () => _showUpdateStatusDialog(item),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withAlpha(100), width: 0.8),
                              ),
                              child: Text(
                                item.status.toUpperCase().replaceAll('_', ' '),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (item.title.isNotEmpty) ...[
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (item.isFeedback && item.rating > 0) ...[
                        Row(
                          children: [
                            ...List.generate(5, (s) {
                              return Icon(
                                s < item.rating.round() ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                            const SizedBox(width: 6),
                            Text('(${item.rating.toStringAsFixed(1)})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        item.description,
                        style: TextStyle(fontSize: 13, height: 1.35, color: theme.colorScheme.onSurface.withAlpha(220)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            '${item.userName} (${item.userRole}) • ${item.userEmail}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit_note, size: 20),
                            tooltip: 'Change Status',
                            onPressed: () => _showUpdateStatusDialog(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete Entry?'),
                                  content: const Text('Are you sure you want to remove this feedback item?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _feedbackRepo.deleteFeedbackItem(item.id);
                                _loadData();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

