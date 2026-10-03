import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/review_model.dart';
import '../../models/user_model.dart';
import '../../repositories/booking_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/review_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/presence_service.dart';
import '../chat_screen.dart';
import '../messages/messages_screen.dart';
import '../notifications/notifications_screen.dart';
import 'provider_detail_screen.dart';
import 'provider_plan_screen.dart';
import '../profile/edit_profile_screen.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _userRepo = UserRepository();
  final _bookingRepo = BookingRepository();
  final _reviewRepo = ReviewRepository();
  final _notifRepo = NotificationRepository();
  final _presenceService = PresenceService();

  late TabController _tabController;
  UserModel? _currentUser;
  bool _loading = true;
  List<Map<String, dynamic>> _allRequests = [];
  Map<String, dynamic> _ratingSummary = {'average': 0.0, 'count': 0};
  List<ReviewModel> _recentReviews = [];
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
          _ratingSummary = {'average': 0.0, 'count': 0};
          _recentReviews = [];
          _loading = false;
        });
      }
      return;
    }

    try {
      final results = await Future.wait([
        _userRepo.getUser(uid),
        _bookingRepo.getProviderRequests(uid),
        _reviewRepo.getProviderRatingSummary(uid),
        _reviewRepo.getProviderReviews(uid),
      ]);

      final user = results[0] as UserModel?;
      final requests = results[1] as List<Map<String, dynamic>>;
      final summary = results[2] as Map<String, dynamic>;
      final reviews = results[3] as List<ReviewModel>;

      if (mounted) {
        setState(() {
          _currentUser = user;
          _allRequests = requests;
          _ratingSummary = summary;
          _recentReviews = reviews;
          _loading = false;
        });
        if (user != null) {
          _checkAndShowPremiumCelebrationPopup(user);
        }
      }
    } catch (e) {
      debugPrint('>>> [ProviderDashboardScreen._loadDashboardData] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkAndShowPremiumCelebrationPopup(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'has_seen_premium_welcome_popup_${user.uid}';
      final hasSeen = prefs.getBool(key) ?? false;
      if (hasSeen) return;

      await prefs.setBool(key, true);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withAlpha(100),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.stars, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Welcome to FindiPro Premium! 🎉',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Congratulations! Your provider account is activated with a Limited Promotional Trial. All VIP features are unlocked for you during this trial period.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD97706).withAlpha(60)),
                    ),
                    child: Column(
                      children: [
                        _perkRow(Icons.verified, 'Golden VIP & Verified Badge Active', const Color(0xFFD97706)),
                        const SizedBox(height: 8),
                        _perkRow(Icons.trending_up, 'Priority Marketplace Search Ranking', Colors.green),
                        const SizedBox(height: 8),
                        _perkRow(Icons.photo_library, 'Unlimited Portfolio Work Photos', Colors.blue),
                        const SizedBox(height: 8),
                        _perkRow(Icons.analytics, 'Real-Time Insights & Analytics', Colors.purple),
                        const SizedBox(height: 8),
                        _perkRow(Icons.lock_open, 'Zero Locked Features or Paywalls', Colors.teal),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Start Exploring Dashboard',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {}
  }

  Widget _perkRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _newRequests => _allRequests
      .where((r) => (r['status'] ?? '').toString().toLowerCase() == 'requested')
      .toList();

  List<Map<String, dynamic>> get _activeJobs => _allRequests.where((r) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        return status == 'accepted' || status == 'in_progress';
      }).toList();

  List<Map<String, dynamic>> get _completedJobs => _allRequests
      .where((r) => (r['status'] ?? '').toString().toLowerCase() == 'completed')
      .toList();

  num get _totalEarnings {
    num total = 0;
    for (final r in _completedJobs) {
      final budget = r['estimated_budget'] ?? r['estimatedBudget'] ?? r['budget'];
      if (budget != null) {
        total += (num.tryParse(budget.toString()) ?? 0);
      }
    }
    return total;
  }

  Future<void> _updateJobStatus(String requestId, String newStatus) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await _bookingRepo.updateStatus(
        requestId,
        newStatus,
        currentUserId: uid,
        isProviderUpdating: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'accepted'
                  ? 'Request Accepted! Client has been notified.'
                  : (newStatus == 'in_progress'
                      ? 'Job started! Client has been notified.'
                      : (newStatus == 'completed'
                          ? 'Job marked as completed! 🎉'
                          : 'Job status updated.')),
            ),
            backgroundColor: newStatus == 'completed'
                ? const Color(0xFF10B981)
                : const Color(0xFF06B6D4),
          ),
        );
      }

      await _loadDashboardData();
    } catch (e) {
      debugPrint('>>> [ProviderDashboardScreen._updateJobStatus] error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update job status. Please try again.')),
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
        appBar: AppBar(title: const Text('Provider Dashboard')),
        body: const Center(child: Text('Please log in to view provider dashboard.')),
      );
    }

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Provider Dashboard')),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final user = _currentUser;
    final avgRating = (_ratingSummary['average'] as num?)?.toDouble() ?? 0.0;
    final revCount = (_ratingSummary['count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Provider Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
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

            // 2. Metrics & Overview Cards (New, Active, Completed, Earnings, Rating)
            _buildMetricsGrid(avgRating, revCount, isDark),
            const SizedBox(height: 20),

            // 3. Earnings & Subscription Summary Banner
            _buildEarningsAndPlanBanner(user, isDark),
            const SizedBox(height: 20),

            // 4. Analytics Dashboard (Exclusive for Premium Users)
            _buildAnalyticsSection(user, isDark),
            const SizedBox(height: 20),

            // 5. Promotional & Growth Tools (Exclusive for Premium Users)
            _buildPromotionalToolsSection(user, isDark),
            const SizedBox(height: 20),

            // 6. Job Management Section (Tabbed: New Requests / Active / Completed)
            _buildJobsSectionHeader(),
            const SizedBox(height: 12),
            _buildJobsTabContainer(isDark),
            const SizedBox(height: 24),

            // 7. Recent Reviews & Ratings Section
            _buildRecentReviewsSection(isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Top Profile and Real-time Presence Card.
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
            child: Column(
              children: [
                Row(
                  children: [
                // Avatar with presence badge
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      backgroundImage: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 36, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
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
                // Name, Category, Presence status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user?.name.isNotEmpty == true ? user!.name : 'Service Provider',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user?.isPremiumBadge == true)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.stars, color: Color(0xFFD97706), size: 18),
                            )
                          else if (user?.isVerifiedBadge == true)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified, color: Colors.blue, size: 18),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.category?.isNotEmpty == true
                            ? user!.category!
                            : 'Service Professional',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF06B6D4),
                          fontWeight: FontWeight.w600,
                        ),
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
                // Online/Offline status switch
                IconButton(
                  tooltip: isOnline ? 'Set Offline' : 'Set Online',
                  icon: Icon(
                    isOnline ? Icons.toggle_on : Icons.toggle_off,
                    color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                    size: 36,
                  ),
                  onPressed: () async {
                    if (isOnline) {
                      await _presenceService.setOffline(uid);
                    } else {
                      await _presenceService.setOnline(uid);
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(
                              name: user.name,
                              phone: user.phone,
                              location: user.location ?? '',
                              photoUrl: user.photoUrl,
                            ),
                          ),
                        ).then((_) => _loadDashboardData());
                      }
                    },
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: Text('Portfolio (${user?.images.length ?? 0})', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProviderDetailScreen(provider: user),
                          ),
                        ).then((_) => _loadDashboardData());
                      }
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Public Profile', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);
  }

  /// Metric cards grid showing New Requests, Active Jobs, Completed Jobs, and Ratings.
  Widget _buildMetricsGrid(double avgRating, int revCount, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            // New Requests Card
            Expanded(
              child: _buildMetricCard(
                title: 'New Requests',
                value: '${_newRequests.length}',
                icon: Icons.notifications_active_outlined,
                accentColor: _newRequests.isNotEmpty ? const Color(0xFFF59E0B) : Colors.grey,
                subtitle: _newRequests.isNotEmpty ? 'Action needed' : 'Up to date',
                onTap: () => _tabController.animateTo(0),
              ),
            ),
            const SizedBox(width: 12),
            // Active Jobs Card
            Expanded(
              child: _buildMetricCard(
                title: 'Active Jobs',
                value: '${_activeJobs.length}',
                icon: Icons.work_outline,
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
            // Completed Jobs Card
            Expanded(
              child: _buildMetricCard(
                title: 'Completed',
                value: '${_completedJobs.length}',
                icon: Icons.task_alt,
                accentColor: const Color(0xFF10B981),
                subtitle: 'Total completed',
                onTap: () => _tabController.animateTo(2),
              ),
            ),
            const SizedBox(width: 12),
            // Rating & Reviews Card
            Expanded(
              child: _buildMetricCard(
                title: 'Rating & Reviews',
                value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '—',
                icon: Icons.star_rate_rounded,
                accentColor: Colors.amber,
                subtitle: '$revCount ${revCount == 1 ? 'review' : 'reviews'}',
                onTap: () {
                  if (_currentUser != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderDetailScreen(provider: _currentUser!),
                      ),
                    );
                  }
                },
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

  /// Earnings and Subscription Plan Banner.
  Widget _buildEarningsAndPlanBanner(UserModel? user, bool isDark) {
    final currency = user?.subscriptionCurrency ?? 'UGX';
    final earnings = _totalEarnings;
    final planName = (user?.effectivePlan ?? 'basic').toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF06B6D4),
            Color(0xFF0284C7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Revenue from Jobs',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Plan: $planName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$currency ${earnings.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  user?.isSubscriptionActive == true
                      ? 'Subscription active & verified'
                      : 'Upgrade to Verified or Premium for top ranking',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProviderPlanScreen()),
                ).then((_) => _loadDashboardData()),
                child: const Text('Manage Plan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section Header for Job Management.
  Widget _buildJobsSectionHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Jobs & Bookings Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Tabbed Container for New Requests, Active, and Completed Jobs.
  Widget _buildJobsTabContainer(bool isDark) {
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
              Tab(text: 'New (${_newRequests.length})'),
              Tab(text: 'Active (${_activeJobs.length})'),
              Tab(text: 'Completed (${_completedJobs.length})'),
            ],
          ),
          SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsList(_newRequests, 'No new hire requests at the moment.'),
                _buildRequestsList(_activeJobs, 'No active jobs in progress.'),
                _buildRequestsList(_completedJobs, 'No completed jobs yet.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(List<Map<String, dynamic>> items, String emptyMessage) {
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

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final req = items[index];
        final id = (req['id'] ?? '').toString();
        final clientName = (req['client_name'] ?? req['clientName'] ?? 'Customer').toString();
        final clientId = (req['client_id'] ?? req['clientId'] ?? req['customer_id'] ?? '').toString();
        final service = (req['service_needed'] ?? req['serviceNeeded'] ?? req['title'] ?? 'Service Request').toString();
        final location = (req['location'] ?? req['address'] ?? req['city'] ?? '').toString();
        final status = (req['status'] ?? 'requested').toString().toLowerCase();
        final budget = req['estimated_budget'] ?? req['estimatedBudget'] ?? req['budget'];
        final notes = (req['notes'] ?? req['description'] ?? '').toString();

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
                    const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(clientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
                    if (clientId.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('Chat'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                currentUserId: currentUid,
                                otherUserId: clientId,
                                otherUserName: clientName,
                                bookingId: id,
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 8),
                    if (status == 'requested') ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _updateJobStatus(id, 'declined'),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _updateJobStatus(id, 'accepted'),
                        child: const Text('Accept'),
                      ),
                    ] else if (status == 'accepted') ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _updateJobStatus(id, 'in_progress'),
                        child: const Text('Start Job'),
                      ),
                    ] else if (status == 'in_progress') ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _updateJobStatus(id, 'completed'),
                        child: const Text('Mark Completed'),
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

  /// Recent Reviews & Ratings Card.
  Widget _buildRecentReviewsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Reviews & Feedback',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_currentUser != null)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProviderDetailScreen(provider: _currentUser!),
                  ),
                ),
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentReviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No reviews received yet. Complete jobs to receive reviews from clients!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentReviews.take(3).length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = _recentReviews[index];
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
                          (r.customerName != null && r.customerName!.isNotEmpty)
                              ? r.customerName!
                              : 'Client',
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
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  /// Analytics Dashboard Section (Exclusive to Premium providers).
  Widget _buildAnalyticsSection(UserModel? user, bool isDark) {
    final isPremium = user?.isPremiumBadge == true;
    final currency = user?.subscriptionCurrency ?? 'UGX';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium ? const Color(0xFFD97706).withAlpha(80) : Colors.grey.withAlpha(50),
          width: isPremium ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: isPremium ? const Color(0xFFD97706) : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Analytics Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPremium
                      ? const Color(0xFFD97706).withAlpha(30)
                      : Colors.grey.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPremium ? 'PREMIUM EXCLUSIVE' : 'LOCKED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isPremium ? const Color(0xFFD97706) : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isPremium) ...[
            // Premium Analytics Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsMetricCard(
                    title: 'Profile Views',
                    value: '128',
                    change: '+18% this wk',
                    icon: Icons.visibility_outlined,
                    color: const Color(0xFF06B6D4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildAnalyticsMetricCard(
                    title: 'Search Impressions',
                    value: '412',
                    change: '+24% this wk',
                    icon: Icons.search_outlined,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsMetricCard(
                    title: 'Hire Conversion',
                    value: '84%',
                    change: 'High demand',
                    icon: Icons.trending_up,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildAnalyticsMetricCard(
                    title: 'Avg. Job Value',
                    value: '$currency 75k',
                    change: 'Based on jobs',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Locked Overlay State for Non-Premium Users
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade400.withAlpha(80)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_outline, size: 36, color: Color(0xFFD97706)),
                  const SizedBox(height: 8),
                  const Text(
                    'Analytics Dashboard is Locked',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upgrade to FindiPro Premium to unlock detailed profile views, search appearances, hire conversion rates, and revenue trajectory metrics.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProviderPlanScreen()),
                      );
                    },
                    icon: const Icon(Icons.stars, size: 18),
                    label: const Text('Upgrade to Premium', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetricCard({
    required String title,
    required String value,
    required String change,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            change,
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withAlpha(140)),
          ),
        ],
      ),
    );
  }

  /// Promotional & Growth Tools Section (Exclusive to Premium providers).
  Widget _buildPromotionalToolsSection(UserModel? user, bool isDark) {
    final isPremium = user?.isPremiumBadge == true;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium ? const Color(0xFF06B6D4).withAlpha(80) : Colors.grey.withAlpha(50),
          width: isPremium ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.campaign_outlined, color: Color(0xFF06B6D4), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Promotional & Growth Tools',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPremium
                      ? const Color(0xFF06B6D4).withAlpha(30)
                      : Colors.grey.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPremium ? 'ACTIVE' : 'LOCKED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isPremium ? const Color(0xFF06B6D4) : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isPremium) ...[
            _buildPromoFeatureRow(
              icon: Icons.stars,
              iconColor: const Color(0xFFD97706),
              title: 'Golden Pro Badge',
              subtitle: 'Displayed across search cards, explore listings, and profile.',
            ),
            const Divider(height: 16),
            _buildPromoFeatureRow(
              icon: Icons.trending_up,
              iconColor: const Color(0xFF10B981),
              title: 'Priority Search Ranking',
              subtitle: 'Placed at the top of client search and category results.',
            ),
            const Divider(height: 16),
            _buildPromoFeatureRow(
              icon: Icons.star_border,
              iconColor: const Color(0xFF06B6D4),
              title: 'Featured Explore Placement',
              subtitle: 'Highlighted prominently in the top featured providers banner.',
            ),
            const Divider(height: 16),
            _buildPromoFeatureRow(
              icon: Icons.all_inclusive,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Unlimited Services Listing',
              subtitle: 'Add as many specialized services and skills as you need.',
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF06B6D4).withAlpha(40)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.campaign_outlined, size: 36, color: Color(0xFF06B6D4)),
                  const SizedBox(height: 8),
                  const Text(
                    'Promotional Tools (Premium Only)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unlock featured placement on the Explore screen, priority search ranking, unlimited service listings, and the Golden Pro badge.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProviderPlanScreen()),
                      );
                    },
                    icon: const Icon(Icons.stars, size: 18),
                    label: const Text('Unlock with Premium', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPromoFeatureRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
