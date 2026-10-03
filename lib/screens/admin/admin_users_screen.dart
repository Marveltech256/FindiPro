import 'package:flutter/material.dart';
import '../../core/config/supabase_config.dart';
import '../../services/admin_service.dart';

class AdminUsersScreen extends StatefulWidget {
  final String? filterRole; // null for all, 'provider', or 'customer'

  const AdminUsersScreen({super.key, this.filterRole});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService _adminService = AdminService();
  String _searchQuery = '';
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await SupabaseConfig.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('>>> [AdminUsersScreen._loadUsers] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.filterRole == 'provider'
        ? 'Providers'
        : (widget.filterRole == 'customer' ? 'Customers' : 'Users');

    final filteredUsers = _users.where((u) {
      final role = (u['role'] ?? 'customer').toString().toLowerCase();
      if (widget.filterRole != null && widget.filterRole!.isNotEmpty) {
        if (widget.filterRole == 'provider' && role != 'provider' && role != 'technician') {
          return false;
        }
        if (widget.filterRole == 'customer' && role != 'customer' && role != 'client') {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final name = (u['full_name'] ?? u['name'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || email.contains(_searchQuery);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh Users',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
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
                    onRefresh: _loadUsers,
                    child: filteredUsers.isEmpty
                        ? Center(
                            child: ListView(
                              shrinkWrap: true,
                              children: const [
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('No matching users found.'),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final name = (user['full_name'] ?? user['name'] ?? 'User').toString();
                              final email = (user['email'] ?? '').toString();
                              final id = user['id'].toString();
                              final role = (user['role'] ?? 'customer').toString().toLowerCase();
                              final isProvider = role == 'provider' || role == 'technician';
                              final plan = (user['plan'] ?? (user['is_premium'] == true || user['premium'] == true ? 'premium' : (user['is_verified'] == true || user['verified'] == true ? 'verified' : 'basic'))).toString().toLowerCase();
                              final isBlocked = user['is_blocked'] == true;
                              final isVerified = user['is_verified'] == true || user['verified'] == true || (user['verification_status'] ?? '').toString().toLowerCase() == 'approved';
                              final isPremium = plan == 'premium' || user['is_premium'] == true || user['premium'] == true;

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U'),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isPremium) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.stars_rounded, size: 16, color: Color(0xFFF59E0B)),
                                            ] else if (isVerified) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.verified, size: 16, color: Color(0xFF3B82F6)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isProvider
                                              ? (isPremium
                                                  ? const Color(0xFFF59E0B).withAlpha(30)
                                                  : const Color(0xFF06B6D4).withAlpha(30))
                                              : theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isProvider ? (isPremium ? 'PREMIUM 🌟' : (isVerified ? 'VERIFIED 🛡️' : 'PROVIDER')) : role.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isProvider
                                                ? (isPremium ? const Color(0xFFD97706) : const Color(0xFF06B6D4))
                                                : theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (email.isNotEmpty) Text(email),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            isBlocked ? 'Status: BLOCKED 🛑' : 'Status: ACTIVE ✅',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isBlocked ? Colors.red : Colors.green,
                                            ),
                                          ),
                                          if (isProvider) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '• Plan: ${plan.toUpperCase()}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isPremium ? const Color(0xFFD97706) : Colors.blueGrey,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      try {
                                        if (value == 'assign_badge') {
                                          _showAssignPlanModal(user);
                                        } else if (value == 'block') {
                                          await _adminService.blockUser(id, true);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('$name has been blocked.')),
                                            );
                                          }
                                          _loadUsers();
                                        } else if (value == 'unblock') {
                                          await _adminService.blockUser(id, false);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('$name has been unblocked.')),
                                            );
                                          }
                                          _loadUsers();
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Failed to update user status.')),
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'assign_badge',
                                        child: Row(
                                          children: [
                                            Icon(Icons.workspace_premium, color: Color(0xFFF59E0B), size: 18),
                                            SizedBox(width: 8),
                                            Text('Assign Plan & Badge'),
                                          ],
                                        ),
                                      ),
                                      if (!isBlocked)
                                        const PopupMenuItem(
                                          value: 'block',
                                          child: Text('Block User'),
                                        )
                                      else
                                        const PopupMenuItem(
                                          value: 'unblock',
                                          child: Text('Unblock User'),
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

  void _showAssignPlanModal(Map<String, dynamic> user) {
    final name = (user['full_name'] ?? user['name'] ?? 'User').toString();
    final uid = user['id'].toString();
    String selectedPlan = (user['plan'] ?? 'premium').toString().toLowerCase();
    bool isVerified = user['is_verified'] == true || user['verified'] == true || (user['verification_status'] ?? '').toString().toLowerCase() == 'approved';
    bool isPremium = selectedPlan == 'premium' || user['is_premium'] == true || user['premium'] == true;
    String verificationStatus = (user['verification_status'] ?? (isVerified ? 'approved' : 'none')).toString().toLowerCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Manage Badge & Tier for $name',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Directly grant or revoke subscription tier and verification badges:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Plan selection
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selectedPlan == 'premium' ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                          width: selectedPlan == 'premium' ? 2 : 1,
                        ),
                      ),
                      leading: const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 28),
                      title: const Text('Premium Tier (Golden Badge)', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Gold badge, analytics dashboard, top ranking & unlimited services'),
                      trailing: Icon(
                        selectedPlan == 'premium' ? Icons.check_circle : Icons.circle_outlined,
                        color: selectedPlan == 'premium' ? const Color(0xFFF59E0B) : Colors.grey,
                      ),
                      onTap: () {
                        setModalState(() {
                          selectedPlan = 'premium';
                          isPremium = true;
                          isVerified = true;
                          verificationStatus = 'approved';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selectedPlan == 'verified' ? const Color(0xFF3B82F6) : Colors.grey.shade300,
                          width: selectedPlan == 'verified' ? 2 : 1,
                        ),
                      ),
                      leading: const Icon(Icons.verified, color: Color(0xFF3B82F6), size: 28),
                      title: const Text('Verified / Pro Tier (Blue Badge)', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Blue verification checkmark, verified search filter & max 5 images'),
                      trailing: Icon(
                        selectedPlan == 'verified' ? Icons.check_circle : Icons.circle_outlined,
                        color: selectedPlan == 'verified' ? const Color(0xFF3B82F6) : Colors.grey,
                      ),
                      onTap: () {
                        setModalState(() {
                          selectedPlan = 'verified';
                          isPremium = false;
                          isVerified = true;
                          verificationStatus = 'approved';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selectedPlan == 'basic' ? Colors.blueGrey : Colors.grey.shade300,
                          width: selectedPlan == 'basic' ? 2 : 1,
                        ),
                      ),
                      leading: const Icon(Icons.circle_outlined, color: Colors.grey, size: 28),
                      title: const Text('Basic Tier (Standard)', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('No badges, basic service limits'),
                      trailing: Icon(
                        selectedPlan == 'basic' ? Icons.check_circle : Icons.circle_outlined,
                        color: selectedPlan == 'basic' ? Colors.blueGrey : Colors.grey,
                      ),
                      onTap: () {
                        setModalState(() {
                          selectedPlan = 'basic';
                          isPremium = false;
                          isVerified = false;
                          verificationStatus = 'none';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      title: const Text('Golden Premium Badge Active'),
                      subtitle: const Text('Forces the golden star badge on profile & listings'),
                      value: isPremium,
                      onChanged: (val) => setModalState(() => isPremium = val),
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Blue Verified Checkmark Active'),
                      subtitle: const Text('Marks identity as verified'),
                      value: isVerified,
                      onChanged: (val) => setModalState(() {
                        isVerified = val;
                        verificationStatus = val ? 'approved' : 'none';
                      }),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(modalCtx);
                          try {
                            await _adminService.updateProviderPlanAndBadge(
                              uid: uid,
                              plan: selectedPlan,
                              isVerified: isVerified,
                              isPremium: isPremium,
                              verificationStatus: verificationStatus,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Updated $name to ${selectedPlan.toUpperCase()} successfully!'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                            _loadUsers();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to update provider plan.')),
                              );
                            }
                          }
                        },
                        child: const Text('Save & Apply Badge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
}
