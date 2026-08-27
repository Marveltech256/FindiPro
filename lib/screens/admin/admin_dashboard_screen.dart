import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/config/supabase_config.dart';
import '../../repositories/user_repository.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import 'admin_users_screen.dart';
import 'verification_requests_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  final UserRepository _userRepo = UserRepository();
  AdminMetrics? _metrics;
  bool _loading = true;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    final userModel = await _userRepo.getUser(firebaseUser.uid);
    final isAdmin = userModel != null && (userModel.isAdmin || userModel.role == 'admin');

    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied: Administrator privileges required.'),
            backgroundColor: Colors.red,
          ),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
      return;
    }

    if (mounted) {
      setState(() => _authorized = true);
    }
    await _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _loading = true);
    try {
      final metrics = await _adminService.getDashboardMetrics();
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String title, IconData icon, VoidCallback onTap, {String? badge}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF06B6D4)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null && badge.isNotEmpty && badge != '0')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _showReportsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Reports'),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: () async {
            try {
              final res = await SupabaseConfig.client
                  .from('reports')
                  .select()
                  .order('created_at', ascending: false)
                  .limit(20);
              return List<Map<String, dynamic>>.from(res);
            } catch (_) {
              return <Map<String, dynamic>>[];
            }
          }(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator.adaptive());
            final reports = snapshot.data!;
            if (reports.isEmpty) return const Text('No user reports submitted yet.');
            return SizedBox(
              width: double.maxFinite,
              height: 250,
              child: ListView.builder(
                itemCount: reports.length,
                itemBuilder: (context, i) {
                  final r = reports[i];
                  return ListTile(
                    title: Text((r['reason'] ?? r['title'] ?? 'Report').toString()),
                    subtitle: Text((r['status'] ?? 'pending').toString()),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_authorized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
            tooltip: 'Refresh Metrics',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
            },
            tooltip: 'Logout Admin',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMetrics,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Platform Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_metrics != null)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  _metricCard('Total Users', '${_metrics!.totalUsers}', Icons.people_outline, const Color(0xFF06B6D4)),
                  _metricCard('Customers', '${_metrics!.customers}', Icons.person_outline, Colors.blue),
                  _metricCard('Providers', '${_metrics!.providers}', Icons.storefront_outlined, Colors.purple),
                  _metricCard('Verified Providers', '${_metrics!.verifiedProviders}', Icons.verified_outlined, Colors.blueAccent),
                  _metricCard('Premium Providers', '${_metrics!.premiumProviders}', Icons.stars_outlined, const Color(0xFFD97706)),
                  _metricCard('Pending Verifications', '${_metrics!.pendingVerifications}', Icons.pending_actions, Colors.orange),
                  _metricCard('Active Jobs', '${_metrics!.activeJobs}', Icons.work_outline, Colors.green),
                  _metricCard('Completed Jobs', '${_metrics!.completedJobs}', Icons.task_alt, Colors.teal),
                  _metricCard('Total Reviews', '${_metrics!.totalReviews}', Icons.star_half_outlined, Colors.amber),
                  _metricCard('Active Subscriptions', '${_metrics!.activeSubscriptions}', Icons.card_membership, Colors.indigo),
                ],
              ),
            const SizedBox(height: 24),
            const Text(
              'Management & Tools',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _tile(context, 'All Users', Icons.people, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
            }),
            _tile(context, 'Providers', Icons.store, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen(filterRole: 'provider')));
            }),
            _tile(
              context,
              'Verification Requests',
              Icons.verified_user,
              () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationRequestsScreen()));
                _loadMetrics();
              },
              badge: _metrics != null && _metrics!.pendingVerifications > 0 ? '${_metrics!.pendingVerifications}' : null,
            ),
            _tile(context, 'Reports', Icons.flag_outlined, () => _showReportsDialog(context)),
          ],
        ),
      ),
    );
  }
}
