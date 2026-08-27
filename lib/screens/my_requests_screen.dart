import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/booking_repository.dart';
import '../repositories/review_repository.dart';
import '../repositories/user_repository.dart';
import '../widgets/empty_state.dart';
import 'chat_screen.dart';
import 'provider/write_review_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final _repo = BookingRepository();
  final _userRepo = UserRepository();
  final _reviewRepo = ReviewRepository();
  UserModel? _currentUser;
  bool _loadingUser = true;
  final Map<String, bool> _reviewedCache = {};

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final user = await _userRepo.getUser(uid);
      if (mounted) {
        setState(() {
          _currentUser = user;
          _loadingUser = false;
        });
      }
    } else {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRequests() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    List<Map<String, dynamic>> requests;
    if (_currentUser?.isProvider == true) {
      final providerRequests = await _repo.getProviderRequests(uid);
      if (providerRequests.isNotEmpty) {
        requests = providerRequests;
      } else {
        requests = await _repo.getClientRequests(uid);
      }
    } else {
      requests = await _repo.getClientRequests(uid);
    }

    // Check reviewed status for completed requests
    if (_currentUser?.isProvider != true) {
      for (final r in requests) {
        final status = (r['status'] ?? '').toString();
        final requestId = (r['id'] ?? '').toString();
        final sourceTable = (r['source_table'] ?? 'hire_requests').toString();
        final providerId = (r['provider_id'] ?? r['providerId'] ?? '').toString();
        if (status == 'completed' && requestId.isNotEmpty) {
          final isReviewed = await _reviewRepo.hasReviewed(
            customerId: uid,
            jobId: sourceTable == 'jobs' ? requestId : null,
            bookingId: sourceTable == 'bookings' ? requestId : null,
            providerId: providerId.isNotEmpty ? providerId : null,
          );
          _reviewedCache[requestId] = isReviewed;
        }
      }
    }

    return requests;
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isProvider = _currentUser?.isProvider == true;
    final requestId = (request['id'] ?? '').toString();
    final sourceTable = (request['source_table'] ?? 'bookings').toString();
    final clientName = (request['client_name'] ?? request['clientName'] ?? 'Customer').toString();
    final clientPhone = (request['client_phone'] ?? request['clientPhone'] ?? '').toString();
    final providerId = (request['provider_id'] ?? request['providerId'] ?? '').toString();
    final providerName = (request['provider_name'] ?? request['providerName'] ?? 'Provider').toString();
    final serviceNeeded = (request['service_needed'] ?? request['serviceNeeded'] ?? request['title'] ?? 'Service').toString();
    final location = (request['location'] ?? request['address'] ?? '').toString();
    final notes = (request['notes'] ?? request['description'] ?? '').toString();
    final status = (request['status'] ?? 'requested').toString();
    final otherUserId = isProvider
        ? (request['client_id'] ?? request['clientId'] ?? '').toString()
        : providerId;
    final otherUserName = isProvider ? clientName : providerName;
    final isReviewed = _reviewedCache[requestId] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            serviceNeeded,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ),
                        statusChip(status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _detailRow(Icons.person_outline, isProvider ? 'Customer' : 'Provider', otherUserName),
                    if (clientPhone.isNotEmpty)
                      _detailRow(Icons.phone_outlined, 'Contact', clientPhone),
                    if (location.isNotEmpty)
                      _detailRow(Icons.location_on_outlined, 'Location', location),
                    if (request['requested_date'] != null || request['requestedDate'] != null)
                      _detailRow(
                        Icons.calendar_today_outlined,
                        'Date',
                        _formatDate(request['requested_date'] ?? request['requestedDate']),
                      ),
                    if (notes.isNotEmpty)
                      _detailRow(Icons.notes_outlined, 'Notes', notes),
                    const SizedBox(height: 20),

                    // Actions for Provider
                    if (isProvider) ...[
                      if (status == 'requested' || status == 'pending') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.check),
                                label: const Text('Accept Request'),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _repo.updateStatus(requestId, 'accepted', isProviderUpdating: true);
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                icon: const Icon(Icons.close),
                                label: const Text('Decline'),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _repo.updateStatus(requestId, 'cancelled', isProviderUpdating: true);
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ] else if (status == 'accepted') ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Service / In Progress'),
                            onPressed: () async {
                              Navigator.pop(context);
                              await _repo.updateStatus(requestId, 'in_progress', isProviderUpdating: true);
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ] else if (status == 'in_progress') ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.done_all),
                            label: const Text('Complete Service'),
                            onPressed: () async {
                              Navigator.pop(context);
                              await _repo.updateStatus(requestId, 'completed', isProviderUpdating: true);
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    // Rate Provider Action for Customer when job is completed
                    if (!isProvider && status == 'completed') ...[
                      if (!isReviewed) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.star_outline),
                            label: const Text('Rate Provider / Write Review'),
                            onPressed: () async {
                              final nav = Navigator.of(context);
                              nav.pop();
                              final providerUser = await _userRepo.getUser(providerId);
                              if (providerUser != null) {
                                final res = await nav.push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => WriteReviewScreen(
                                      provider: providerUser,
                                      // A request's `id` only exists in
                                      // one underlying table -- passing
                                      // it as both jobId and bookingId
                                      // trips the reviews table's strict
                                      // foreign key constraints. Only
                                      // set the one that actually matches
                                      // where this request came from.
                                      jobId: sourceTable == 'jobs' ? requestId : null,
                                      // reviews.booking_id's foreign key
                                      // only accepts real bookings.id
                                      // values -- hire_requests is a
                                      // different table with no matching
                                      // reviews column, so leave both
                                      // null for that source (the review
                                      // still submits fine unassociated,
                                      // since both columns are nullable).
                                      bookingId: sourceTable == 'bookings' ? requestId : null,
                                    ),
                                  ),
                                );
                                if (res == true && mounted) {
                                  setState(() {
                                    _reviewedCache[requestId] = true;
                                  });
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 18),
                              SizedBox(width: 6),
                              Text('Reviewed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    // Chat Action for both Client & Provider
                    if (otherUserId.isNotEmpty && uid != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text('Message $otherUserName'),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  currentUserId: uid,
                                  otherUserId: otherUserId,
                                  otherUserName: otherUserName,
                                  bookingId: requestId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF06B6D4)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(153))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    final dt = date is DateTime ? date : DateTime.tryParse(date.toString());
    if (dt == null) return date.toString();
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view your requests.')),
      );
    }

    if (_loadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final isProvider = _currentUser?.isProvider == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(isProvider ? 'Service Requests' : 'My Requests'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchRequests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Could not load your requests.'));
            }

            final docs = snapshot.data ?? [];
            if (docs.isEmpty) {
              return EmptyState(
                icon: Icons.receipt_long_outlined,
                title: isProvider ? 'No Service Requests' : 'No Requests Yet',
                subtitle: isProvider
                    ? 'When clients request your services, they will appear here.'
                    : 'When you request a service from a provider, it will appear here.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final d = docs[i];
                final clientName = (d['client_name'] ?? d['clientName'] ?? 'Customer').toString();
                final providerName = (d['provider_name'] ?? d['providerName'] ?? 'Provider').toString();
                final displayName = isProvider ? clientName : providerName;
                final serviceNeeded = (d['service_needed'] ?? d['serviceNeeded'] ?? d['title'] ?? 'Service').toString();
                final status = (d['status'] ?? 'requested').toString();
                final location = (d['location'] ?? d['address'] ?? '').toString();
                final requestId = (d['id'] ?? '').toString();
                final isReviewed = _reviewedCache[requestId] == true;

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          serviceNeeded,
                          style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w600),
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            location,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(153), fontSize: 12),
                          ),
                        ],
                        if (!isProvider && status == 'completed') ...[
                          const SizedBox(height: 6),
                          isReviewed
                              ? const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 14),
                                    SizedBox(width: 4),
                                    Text('Reviewed', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Icon(Icons.star, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text('Rate Provider', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                        ],
                      ],
                    ),
                    trailing: statusChip(status),
                    onTap: () => _showRequestDetails(d),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

Widget statusChip(String status) {
  Color color;
  switch (status.toLowerCase()) {
    case 'accepted':
      color = Colors.green;
      break;
    case 'in_progress':
      color = Colors.blue;
      break;
    case 'completed':
      color = Colors.teal;
      break;
    case 'cancelled':
    case 'declined':
      color = Colors.red;
      break;
    case 'assigned':
      color = Colors.indigo;
      break;
    default: // 'requested' / 'pending'
      color = Colors.orange;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      status.replaceAll('_', ' ').toUpperCase(),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    ),
  );
}