import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/review_model.dart';
import '../../models/user_model.dart';
import '../../repositories/booking_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/review_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/presence_service.dart';
import '../../services/saved_provider_service.dart';
import '../chat_screen.dart';
import '../messages/messages_screen.dart';
import '../notifications/notifications_screen.dart';
import '../provider/provider_detail_screen.dart';
import '../provider/write_review_screen.dart';
import '../saved_screen.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _userRepo = UserRepository();
  final _bookingRepo = BookingRepository();
  final _reviewRepo = ReviewRepository();
  final _notifRepo = NotificationRepository();
  final _savedService = SavedProviderService();
  final _presenceService = PresenceService();

  late TabController _tabController;
  UserModel? _currentUser;
  bool _loading = true;
  List<Map<String, dynamic>> _allRequests = [];
  List<ReviewModel> _submittedReviews = [];
  List<UserModel> _savedProviders = [];
  final Map<String, bool> _reviewedJobCache = {};
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardData();

    // Auto-refresh when user switches/logs in/out
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _loadDashboardData();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _currentUser = null;
          _allRequests = [];
          _submittedReviews = [];
          _savedProviders = [];
          _loading = false;
        });
      }
      return;
    }

    try {
      // Parallelize top-level fetch operations
      final results = await Future.wait([
        _userRepo.getUser(uid),
        _bookingRepo.getClientRequests(uid),
        _reviewRepo.getCustomerReviews(uid),
        _savedService.getSavedIds(),
      ]);

      final user = results[0] as UserModel?;
      final requests = results[1] as List<Map<String, dynamic>>;
      final reviews = results[2] as List<ReviewModel>;
      final savedIds = results[3] as List<String>;

      // Concurrently load saved provider profiles
      List<UserModel> savedList = [];
      if (savedIds.isNotEmpty) {
        final providerFutures = savedIds.map((pId) => _userRepo.getUser(pId));
        final providers = await Future.wait(providerFutures);
        savedList = providers.whereType<UserModel>().toList();
      }

      // Check review status for completed jobs in parallel
      final completedJobs = requests.where((r) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        final reqId = (r['id'] ?? '').toString();
        return status == 'completed' && reqId.isNotEmpty;
      }).toList();

      if (completedJobs.isNotEmpty) {
        final reviewCheckFutures = completedJobs.map((r) async {
          final reqId = (r['id'] ?? '').toString();
          final sourceTable = (r['source_table'] ?? 'bookings').toString();
          final providerId = (r['provider_id'] ?? r['providerId'] ?? '').toString();

          final isReviewed = await _reviewRepo.hasReviewed(
            customerId: uid,
            jobId: sourceTable == 'jobs' ? reqId : null,
            bookingId: sourceTable == 'bookings' ? reqId : null,
            providerId: providerId.isNotEmpty ? providerId : null,
          );
          return MapEntry(reqId, isReviewed);
        });

        final checked = await Future.wait(reviewCheckFutures);
        for (final entry in checked) {
          _reviewedJobCache[entry.key] = entry.value;
        }
      }

      if (mounted) {
        setState(() {
          _currentUser = user;
          _allRequests = requests;
          _submittedReviews = reviews;
          _savedProviders = savedList;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('>>> [ClientDashboardScreen._loadDashboardData] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _pendingRequests => _allRequests
      .where((r) => (r['status'] ?? '').toString().toLowerCase() == 'requested')
      .toList();

  List<Map<String, dynamic>> get _activeServices => _allRequests.where((r) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        return status == 'accepted' || status == 'in_progress';
      }).toList();

  List<Map<String, dynamic>> get _completedServices => _allRequests
      .where((r) => (r['status'] ?? '').toString().toLowerCase() == 'completed')
      .toList();

  Future<void> _cancelRequest(String requestId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await _bookingRepo.updateStatus(
        requestId,
        'cancelled',
        currentUserId: uid,
        isProviderUpdating: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled successfully.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _loadDashboardData();
    } catch (e) {
      debugPrint('>>> [ClientDashboardScreen._cancelRequest] error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel request. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Client Dashboard')),
        body: const Center(child: Text('Please log in to view client dashboard.')),
      );
    }

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Client Dashboard')),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final user = _currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Client Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Saved / Favorites shortcut
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Saved Providers',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedScreen()),
            ).then((_) => _loadDashboardData()),
          ),
          // Messages shortcut
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Messages',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesScreen()),
            ),
          ),
          // Notifications shortcut with unread badge
          StreamBuilder<int>(
            stream: _notifRepo.getUnreadCountStream(uid),
            builder: (context, snap) {
              final unread = snap.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ).then((_) => _loadDashboardData()),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
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
                            fontSize: 10,
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
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Profile & Presence Card
            _buildProfilePresenceCard(user, isDark),
            const SizedBox(height: 16),

            // 2. Metrics & Overview Grid (Pending, Active, Completed, Saved)
            _buildMetricsGrid(isDark),
            const SizedBox(height: 20),

            // 3. Saved / Favorite Providers Carousel
            if (_savedProviders.isNotEmpty) ...[
              _buildSavedProvidersSection(isDark),
              const SizedBox(height: 20),
            ],

            // 4. Services Management Tabs (Pending Requests / Active Services / Completed History)
            _buildServicesSectionHeader(),
            const SizedBox(height: 12),
            _buildServicesTabContainer(isDark),
            const SizedBox(height: 24),

            // 5. Reviews Submitted Section
            _buildSubmittedReviewsSection(isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Header Profile & Real-time Presence Card.
  Widget _buildProfilePresenceCard(UserModel? user, bool isDark) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<Map<String, dynamic>>(
      stream: _presenceService.watchPresence(uid),
      builder: (context, presenceSnap) {
        final isOnline = presenceSnap.data?['is_online'] ?? (user?.isOnline ?? true);
        final lastSeen = presenceSnap.data?['last_seen'] as DateTime? ?? user?.lastSeen;
        final presenceText = UserModel.formatPresence(isOnline: isOnline, lastSeen: lastSeen);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with presence badge
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      backgroundImage: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 32, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).cardTheme.color ?? Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // Name, Role, Presence status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name.isNotEmpty == true ? user!.name : 'Client Account',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email.isNotEmpty == true ? user!.email : 'FindiPro Customer',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            presenceText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
                              color: isOnline
                                  ? const Color(0xFF10B981)
                                  : Theme.of(context).colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Metrics & Overview Cards Grid.
  Widget _buildMetricsGrid(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            // My Requests (Pending)
            Expanded(
              child: _buildMetricCard(
                title: 'My Requests',
                value: '${_pendingRequests.length}',
                icon: Icons.send_outlined,
                accentColor: _pendingRequests.isNotEmpty ? const Color(0xFFF59E0B) : Colors.grey,
                subtitle: _pendingRequests.isNotEmpty ? 'Awaiting response' : 'None pending',
                onTap: () => _tabController.animateTo(0),
              ),
            ),
            const SizedBox(width: 12),
            // Active Services
            Expanded(
              child: _buildMetricCard(
                title: 'Active Services',
                value: '${_activeServices.length}',
                icon: Icons.handyman_outlined,
                accentColor: const Color(0xFF06B6D4),
                subtitle: 'In progress',
                onTap: () => _tabController.animateTo(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Completed Services
            Expanded(
              child: _buildMetricCard(
                title: 'Completed',
                value: '${_completedServices.length}',
                icon: Icons.task_alt,
                accentColor: const Color(0xFF10B981),
                subtitle: 'Service history',
                onTap: () => _tabController.animateTo(2),
              ),
            ),
            const SizedBox(width: 12),
            // Reviews Submitted
            Expanded(
              child: _buildMetricCard(
                title: 'Reviews Left',
                value: '${_submittedReviews.length}',
                icon: Icons.rate_review_outlined,
                accentColor: Colors.amber,
                subtitle: 'Feedback submitted',
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accentColor.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Icon(icon, color: accentColor, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Saved / Favorite Providers Carousel Section.
  Widget _buildSavedProvidersSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Saved Providers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedScreen()),
              ).then((_) => _loadDashboardData()),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _savedProviders.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final p = _savedProviders[index];
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: p)),
                ).then((_) => _loadDashboardData()),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: (p.photoUrl != null && p.photoUrl!.isNotEmpty)
                            ? NetworkImage(p.photoUrl!)
                            : null,
                        child: (p.photoUrl == null || p.photoUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 20)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        p.category ?? 'Provider',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF06B6D4)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Section Header for Services & Bookings.
  Widget _buildServicesSectionHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Services & Requests',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Tabbed Container for Pending Requests, Active Services, and Completed History.
  Widget _buildServicesTabContainer(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF06B6D4),
            unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withAlpha(153),
            indicatorColor: const Color(0xFF06B6D4),
            tabs: [
              Tab(text: 'Requests (${_pendingRequests.length})'),
              Tab(text: 'Active (${_activeServices.length})'),
              Tab(text: 'History (${_completedServices.length})'),
            ],
          ),
          SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildServicesList(_pendingRequests, 'No pending service requests.', isPending: true),
                _buildServicesList(_activeServices, 'No active services in progress.'),
                _buildServicesList(_completedServices, 'No completed services yet.', isHistory: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList(
    List<Map<String, dynamic>> items,
    String emptyMessage, {
    bool isPending = false,
    bool isHistory = false,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(80),
              ),
              const SizedBox(height: 8),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final req = items[index];
        final id = (req['id'] ?? '').toString();
        final providerName = (req['provider_name'] ?? req['providerName'] ?? 'Provider').toString();
        final providerId = (req['provider_id'] ?? req['providerId'] ?? '').toString();
        final service = (req['service_needed'] ?? req['serviceNeeded'] ?? req['title'] ?? 'Service').toString();
        final location = (req['location'] ?? req['address'] ?? req['city'] ?? '').toString();
        final status = (req['status'] ?? 'requested').toString().toLowerCase();
        final budget = req['estimated_budget'] ?? req['estimatedBudget'] ?? req['budget'];
        final notes = (req['notes'] ?? req['description'] ?? '').toString();
        final isReviewed = _reviewedJobCache[id] == true;

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
                    Expanded(
                      child: Text(
                        service,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.engineering_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(providerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    if (budget != null) ...[
                      const Spacer(),
                      Text(
                        'Budget: UGX $budget',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ],
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Action buttons based on status
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Chat button
                    if (providerId.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('Chat'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                currentUserId: currentUid,
                                otherUserId: providerId,
                                otherUserName: providerName,
                                bookingId: id,
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 8),
                    if (isPending) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _cancelRequest(id),
                        child: const Text('Cancel Request'),
                      ),
                    ] else if (isHistory && status == 'completed') ...[
                      if (isReviewed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withAlpha(50)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Reviewed ✓',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.star, size: 16, color: Colors.amber),
                          label: const Text('Write Review'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            final nav = Navigator.of(context);
                            final providerUser = await _userRepo.getUser(providerId) ??
                                UserModel(
                                  uid: providerId,
                                  name: providerName,
                                  email: '',
                                  role: 'provider',
                                );
                            if (mounted) {
                              nav.push(
                                MaterialPageRoute(
                                  builder: (_) => WriteReviewScreen(
                                    provider: providerUser,
                                    bookingId: id,
                                  ),
                                ),
                              ).then((_) => _loadDashboardData());
                            }
                          },
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
      case 'rejected':
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

  /// Reviews Submitted by Client Section.
  Widget _buildSubmittedReviewsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Reviews Submitted',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_submittedReviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'You haven\'t submitted any reviews yet. Complete services to leave feedback for providers!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _submittedReviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = _submittedReviews[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Review for Service',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Row(
                          children: List.generate(
                            5,
                            (starIndex) => Icon(
                              starIndex < r.rating.floor() ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (r.comment != null && r.comment!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        r.comment!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
