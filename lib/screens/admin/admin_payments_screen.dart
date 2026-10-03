import 'package:flutter/material.dart';
import '../../core/config/supabase_config.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'all';
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final res = await SupabaseConfig.client
          .from('provider_subscriptions')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _subscriptions = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('>>> [AdminPaymentsScreen._loadPayments] error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString().contains('42P01') || e.toString().contains('PGRST205')
              ? 'Subscriptions table not found. Please execute supabase_security_rls.sql in your Supabase SQL editor.'
              : 'Unable to load payments: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredSubs = _subscriptions.where((sub) {
      final status = (sub['status'] ?? 'active').toString().toLowerCase();
      if (_selectedStatus != 'all' && status != _selectedStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final tx = (sub['external_transaction_id'] ?? '').toString().toLowerCase();
        final plan = (sub['plan'] ?? '').toString().toLowerCase();
        final provId = (sub['provider_id'] ?? '').toString().toLowerCase();
        return tx.contains(_searchQuery) ||
            plan.contains(_searchQuery) ||
            provId.contains(_searchQuery);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Payments'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700, width: 0.8),
              ),
              child: Text(
                'COMING SOON',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPayments,
            tooltip: 'Refresh Payments',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Status Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _filterChip('all', 'All Transactions'),
                const SizedBox(width: 8),
                _filterChip('active', 'Active'),
                const SizedBox(width: 8),
                _filterChip('cancelled', 'Cancelled'),
                const SizedBox(width: 8),
                _filterChip('expired', 'Expired'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by transaction ref, plan, or provider ID...',
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
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadPayments,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPayments,
                        child: filteredSubs.isEmpty
                            ? Center(
                                child: ListView(
                                  shrinkWrap: true,
                                  children: const [
                                    Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text('No subscription transactions recorded.'),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: filteredSubs.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final sub = filteredSubs[index];
                    final plan = (sub['plan'] ?? 'basic').toString().toUpperCase();
                    final amount = sub['amount'] ?? 0;
                    final currency = (sub['currency'] ?? 'UGX').toString();
                    final billingPeriod = (sub['billing_period'] ?? 'monthly').toString();
                    final txRef = (sub['external_transaction_id'] ?? 'N/A').toString();
                    final paymentProvider = (sub['payment_provider'] ?? 'In-App').toString();
                    final status = (sub['status'] ?? 'active').toString().toLowerCase();
                    final createdAt = (sub['created_at'] ?? '').toString();
                    final expiresAt = (sub['expires_at'] ?? '').toString();

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
                                Row(
                                  children: [
                                    Icon(
                                      plan == 'PREMIUM' ? Icons.stars : Icons.verified,
                                      color: plan == 'PREMIUM' ? const Color(0xFFD97706) : Colors.blue,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$plan PLAN ($billingPeriod)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                _buildStatusBadge(status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Amount: $currency $amount',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Method: $paymentProvider',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            Text(
                              'Tx Ref: $txRef',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontFamily: 'monospace'),
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Paid: ${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                Text(
                                  'Expires: ${expiresAt.length >= 10 ? expiresAt.substring(0, 10) : expiresAt}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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
    final isSelected = _selectedStatus == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStatus = filterKey),
      selectedColor: const Color(0xFF06B6D4).withAlpha(40),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? const Color(0xFF0891B2) : null,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'active':
        bg = const Color(0xFF10B981).withAlpha(30);
        fg = const Color(0xFF059669);
        break;
      case 'cancelled':
        bg = Colors.orange.withAlpha(30);
        fg = Colors.orange.shade800;
        break;
      case 'expired':
        bg = Colors.grey.withAlpha(30);
        fg = Colors.grey.shade700;
        break;
      default:
        bg = Colors.red.withAlpha(30);
        fg = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
