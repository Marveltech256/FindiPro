import 'package:flutter/material.dart';
import '../../core/config/supabase_config.dart';
import '../../repositories/booking_repository.dart';

class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  final BookingRepository _bookingRepo = BookingRepository();
  String _selectedFilter = 'all'; // all, requested, accepted, in_progress, completed, cancelled
  String _searchQuery = '';
  bool _loading = true;
  List<Map<String, dynamic>> _jobs = [];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await SupabaseConfig.client
          .from('jobs')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _jobs = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('>>> [AdminJobsScreen._loadJobs] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredJobs = _jobs.where((j) {
      final status = (j['status'] ?? 'requested').toString().toLowerCase();
      if (_selectedFilter != 'all' && status != _selectedFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final title = (j['title'] ?? '').toString().toLowerCase();
        final desc = (j['description'] ?? '').toString().toLowerCase();
        final address = (j['address'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery) ||
            desc.contains(_searchQuery) ||
            address.contains(_searchQuery);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hire Requests & Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJobs,
            tooltip: 'Refresh Jobs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _filterChip('all', 'All Jobs'),
                const SizedBox(width: 8),
                _filterChip('requested', 'New Requests'),
                const SizedBox(width: 8),
                _filterChip('accepted', 'Accepted'),
                const SizedBox(width: 8),
                _filterChip('in_progress', 'In Progress'),
                const SizedBox(width: 8),
                _filterChip('completed', 'Completed'),
                const SizedBox(width: 8),
                _filterChip('cancelled', 'Cancelled'),
              ],
            ),
          ),
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by title, location, or notes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          // Jobs list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : RefreshIndicator(
                    onRefresh: _loadJobs,
                    child: filteredJobs.isEmpty
                        ? Center(
                            child: ListView(
                              shrinkWrap: true,
                              children: const [
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('No hire requests or jobs found.'),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredJobs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final job = filteredJobs[index];
                              final id = (job['id'] ?? '').toString();
                              final title = (job['title'] ?? 'Service Request').toString();
                              final desc = (job['description'] ?? '').toString();
                              final location = (job['address'] ?? job['city'] ?? '').toString();
                              final status = (job['status'] ?? 'requested').toString().toLowerCase();
                              final createdAt = (job['created_at'] ?? '').toString();

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          _buildStatusChip(status),
                                        ],
                                      ),
                                      if (location.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                location,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (desc.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          desc,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        'Created: ${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt}',
                                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                      const Divider(height: 16),
                                      // Admin action buttons
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          PopupMenuButton<String>(
                                            onSelected: (newStatus) async {
                                              try {
                                                await _bookingRepo.updateStatus(id, newStatus, isProviderUpdating: false);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Job status updated to $newStatus')),
                                                  );
                                                }
                                                _loadJobs();
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Failed to update job status.')),
                                                  );
                                                }
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(value: 'accepted', child: Text('Set Accepted')),
                                              const PopupMenuItem(value: 'in_progress', child: Text('Set In Progress')),
                                              const PopupMenuItem(value: 'completed', child: Text('Set Completed')),
                                              const PopupMenuItem(value: 'cancelled', child: Text('Cancel / Terminate Job', style: TextStyle(color: Colors.red))),
                                            ],
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: const Color(0xFF06B6D4)),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text('Change Status', style: TextStyle(fontSize: 12, color: Color(0xFF06B6D4), fontWeight: FontWeight.bold)),
                                                  Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF06B6D4)),
                                                ],
                                              ),
                                            ),
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

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
      selectedColor: const Color(0xFF06B6D4).withAlpha(40),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? const Color(0xFF0891B2) : null,
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'requested':
        bg = const Color(0xFFF59E0B).withAlpha(30);
        fg = const Color(0xFFD97706);
        label = 'Pending';
        break;
      case 'accepted':
        bg = const Color(0xFF06B6D4).withAlpha(30);
        fg = const Color(0xFF0891B2);
        label = 'Accepted';
        break;
      case 'in_progress':
        bg = const Color(0xFF3B82F6).withAlpha(30);
        fg = const Color(0xFF2563EB);
        label = 'In Progress';
        break;
      case 'completed':
        bg = const Color(0xFF10B981).withAlpha(30);
        fg = const Color(0xFF059669);
        label = 'Completed';
        break;
      case 'cancelled':
      case 'declined':
        bg = Colors.red.withAlpha(30);
        fg = Colors.red;
        label = 'Cancelled';
        break;
      default:
        bg = Colors.grey.withAlpha(30);
        fg = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
