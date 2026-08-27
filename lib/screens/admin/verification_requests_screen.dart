import 'package:flutter/material.dart';
import '../../models/verification_request.dart';
import '../../repositories/verification_repository.dart';

class VerificationRequestsScreen extends StatefulWidget {
  const VerificationRequestsScreen({super.key});

  @override
  State<VerificationRequestsScreen> createState() => _VerificationRequestsScreenState();
}

class _VerificationRequestsScreenState extends State<VerificationRequestsScreen> {
  final VerificationRepository _repo = VerificationRepository();
  String _selectedStatus = 'pending';

  void _showDocumentPreview(BuildContext context, String title, String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (url.startsWith('http')) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Text('Unable to preview image file directly.'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SelectableText(
              url,
              style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.primary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, VerificationRequest req) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide feedback for ${req.providerName}:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Document image is blurry, please upload a clear copy of your National ID.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(dialogCtx);
              try {
                await _repo.rejectRequest(req.id, req.providerId, reason: reason.isNotEmpty ? reason : null);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification request rejected.')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to reject verification request.')),
                  );
                }
              }
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    final statuses = [
      {'key': 'pending', 'label': 'Pending'},
      {'key': 'approved', 'label': 'Approved'},
      {'key': 'rejected', 'label': 'Rejected'},
      {'key': 'all', 'label': 'All Requests'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: statuses.map((s) {
          final isSelected = _selectedStatus == s['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedStatus = s['key']!);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Requests'),
      ),
      body: Column(
        children: [
          _buildStatusFilterChips(),
          Expanded(
            child: StreamBuilder<List<VerificationRequest>>(
              stream: _repo.getPendingRequests(status: _selectedStatus),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Unable to load verification requests: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!;

                if (docs.isEmpty) {
                  return Center(
                    child: Text('No ${_selectedStatus == 'all' ? '' : '$_selectedStatus '}verification requests.'),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final req = docs[index];
                    final isPending = req.status.toLowerCase() == 'pending';
                    final isApproved = req.status.toLowerCase() == 'approved';

                    Color statusColor = Colors.orange;
                    if (isApproved) statusColor = Colors.green;
                    if (req.status.toLowerCase() == 'rejected') statusColor = Colors.red;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    req.providerName.isNotEmpty ? req.providerName : 'Provider ${req.providerId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    req.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Submitted on ${req.createdAt.day}/${req.createdAt.month}/${req.createdAt.year}',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            if (req.nationalIdNumber != null && req.nationalIdNumber!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.credit_card, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ID Number: ${req.nationalIdNumber}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Text(
                              'Submitted Documents:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            if (req.idFrontUrl != null && req.idFrontUrl!.isNotEmpty) ...[
                              InkWell(
                                onTap: () => _showDocumentPreview(context, 'Government ID (Front)', req.idFrontUrl!),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF06B6D4)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'ID Document (Front): ${req.idFrontUrl}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF06B6D4),
                                            decoration: TextDecoration.underline,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (req.idBackUrl != null && req.idBackUrl!.isNotEmpty) ...[
                              InkWell(
                                onTap: () => _showDocumentPreview(context, 'Government ID (Back)', req.idBackUrl!),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.flip_to_back_outlined, size: 16, color: Color(0xFF06B6D4)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'ID Document (Back): ${req.idBackUrl}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF06B6D4),
                                            decoration: TextDecoration.underline,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (req.businessDocUrl != null && req.businessDocUrl!.isNotEmpty) ...[
                              InkWell(
                                onTap: () => _showDocumentPreview(context, 'Business / Skill Document', req.businessDocUrl!),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.description_outlined, size: 16, color: Color(0xFF06B6D4)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Business Document: ${req.businessDocUrl}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF06B6D4),
                                            decoration: TextDecoration.underline,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (req.notes != null && req.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withAlpha(15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withAlpha(50)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: Colors.red),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Admin Feedback: ${req.notes}',
                                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (isPending) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Approve'),
                                      onPressed: () async {
                                        try {
                                          await _repo.approveRequest(req.id, req.providerId);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Provider verification approved! Blue badge activated.'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (_) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Failed to approve verification request.'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Reject'),
                                      onPressed: () => _showRejectDialog(context, req),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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