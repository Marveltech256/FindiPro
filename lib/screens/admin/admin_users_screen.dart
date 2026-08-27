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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.filterRole == 'provider'
        ? 'Providers'
        : (widget.filterRole == 'customer' ? 'Customers' : 'Users');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseConfig.client
                  .from('profiles')
                  .stream(primaryKey: ['id'])
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Unable to load users: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.where((u) {
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

                if (docs.isEmpty) {
                  return const Center(child: Text('No matching users found.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final user = docs[index];
                    final name = (user['full_name'] ?? user['name'] ?? 'User').toString();
                    final email = (user['email'] ?? '').toString();
                    final id = user['id'].toString();
                    final role = (user['role'] ?? 'customer').toString();
                    final isBlocked = user['is_blocked'] == true;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U'),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: role.toLowerCase() == 'provider'
                                    ? const Color(0xFF06B6D4).withAlpha(30)
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: role.toLowerCase() == 'provider'
                                      ? const Color(0xFF06B6D4)
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
                            Text(
                              isBlocked ? 'Status: BLOCKED 🛑' : 'Status: ACTIVE ✅',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isBlocked ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            try {
                              if (value == 'block') {
                                await _adminService.blockUser(id, true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$name has been blocked.')),
                                  );
                                }
                              } else if (value == 'unblock') {
                                await _adminService.blockUser(id, false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$name has been unblocked.')),
                                  );
                                }
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
