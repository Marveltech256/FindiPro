import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/quotation_model.dart';
import '../../models/user_model.dart';
import '../../repositories/quotation_repository.dart';
import '../../repositories/user_repository.dart';
import '../chat_screen.dart';
import 'quotation_maker_screen.dart';

class QuotationDetailScreen extends StatefulWidget {
  final String quotationId;
  final QuotationModel? initialQuotation;

  const QuotationDetailScreen({
    super.key,
    required this.quotationId,
    this.initialQuotation,
  });

  @override
  State<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  final _repo = QuotationRepository();
  final _userRepo = UserRepository();
  QuotationModel? _quotation;
  bool _loading = true;
  bool _processingAction = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _quotation = widget.initialQuotation;
    _fetchQuotation();
  }

  Future<void> _fetchQuotation() async {
    final q = await _repo.getQuotationById(widget.quotationId);
    if (mounted) {
      setState(() {
        if (q != null) _quotation = q;
        _loading = false;
      });
    }
  }

  bool get _isClient {
    if (_currentUserId == null || _quotation == null) return false;
    return _currentUserId == _quotation!.clientId;
  }

  bool get _isProvider {
    if (_currentUserId == null || _quotation == null) return false;
    return _currentUserId == _quotation!.providerId;
  }

  Future<void> _acceptQuotation() async {
    if (_quotation == null || _currentUserId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Accept Quotation?'),
          ],
        ),
        content: Text(
          'You are accepting quotation ${_quotation!.quotationNumber} from ${_quotation!.providerName} for a total of ${_quotation!.formattedTotal}.\n\nThe provider will be notified immediately.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Accept'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingAction = true);

    try {
      await _repo.acceptQuotation(
        quotation: _quotation!,
        currentUserId: _currentUserId!,
      );
      await _fetchQuotation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Quotation accepted! Provider notified.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting quotation: $e')),
      );
    } finally {
      if (mounted) setState(() => _processingAction = false);
    }
  }

  Future<void> _declineQuotation() async {
    if (_quotation == null || _currentUserId == null) return;

    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Quotation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to decline this quotation? You can specify a reason or request a revision:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Budget too high, scope needs adjustment...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingAction = true);

    try {
      await _repo.rejectQuotation(
        quotation: _quotation!,
        currentUserId: _currentUserId!,
        reason: reasonController.text.trim(),
      );
      await _fetchQuotation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation declined.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining quotation: $e')),
      );
    } finally {
      if (mounted) setState(() => _processingAction = false);
    }
  }

  void _copyQuotationSummary() {
    if (_quotation == null) return;
    final q = _quotation!;
    final summary = '''
═════════════════════════════════════
FINDIPRO OFFICIAL SERVICE QUOTATION
═════════════════════════════════════
Quotation No: ${q.quotationNumber}
Date: ${q.formattedDate}
Status: ${q.statusLabel}

FROM:
Company: ${q.providerName}
Phone: ${q.providerPhone ?? 'N/A'}
Email: ${q.providerEmail ?? 'N/A'}

TO:
Client: ${q.clientName}
Phone: ${q.clientPhone ?? 'N/A'}

SUBJECT: ${q.title}
${q.description}

ITEMIZED BREAKDOWN:
${q.items.map((i) => '• ${i.description} (${i.quantity} x ${q.currency} ${NumberFormat('#,###').format(i.unitPrice)}) = ${q.currency} ${NumberFormat('#,###').format(i.total)}').join('\n')}

Subtotal: ${q.formattedSubtotal}
Grand Total: ${q.formattedTotal}

Terms: ${q.notes ?? 'Standard FindiPro Terms apply.'}
═════════════════════════════════════
Verified through FindiPro Platform
''';

    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quotation details copied to clipboard!')),
    );
  }

  Future<void> _openChat() async {
    if (_quotation == null || _currentUserId == null) return;
    final otherId = _isClient ? _quotation!.providerId : _quotation!.clientId;
    final otherName = _isClient ? _quotation!.providerName : _quotation!.clientName;

    UserModel? otherUser;
    try {
      otherUser = await _userRepo.getUser(otherId);
    } catch (_) {}

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: _currentUserId!,
          otherUserId: otherId,
          otherUserName: otherName,
          otherUserPhotoUrl: otherUser?.photoUrl,
          conversationId: _quotation!.conversationId,
          bookingId: _quotation!.bookingId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat('#,###', 'en_US');

    if (_loading && _quotation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quotation Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quotation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quotation Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Quotation not found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _fetchQuotation, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final q = _quotation!;

    return Scaffold(
      appBar: AppBar(
        title: Text(q.quotationNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy Summary',
            onPressed: _copyQuotationSummary,
          ),
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Chat',
            onPressed: _openChat,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Standard Official Invoice Container
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withAlpha(40)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Official Document Ribbon
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0891B2),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SERVICE QUOTATION',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2),
                            ),
                            Text(
                              q.quotationNumber,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: q.statusColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            q.statusLabel,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Company & Issuer Details
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (q.providerLogoUrl != null && q.providerLogoUrl!.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: q.providerLogoUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(Icons.business, size: 36, color: Color(0xFF06B6D4)),
                                ),
                              ),
                              const SizedBox(width: 14),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          q.providerName,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified, size: 16, color: Color(0xFF10B981)),
                                    ],
                                  ),
                                  if (q.providerPhone != null && q.providerPhone!.isNotEmpty)
                                    Text('Tel: ${q.providerPhone}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(160))),
                                  if (q.providerEmail != null && q.providerEmail!.isNotEmpty)
                                    Text('Email: ${q.providerEmail}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(160))),
                                  if (q.providerAddress != null && q.providerAddress!.isNotEmpty)
                                    Text('Address: ${q.providerAddress}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(160))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        // Bill To & Dates Block
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('BILL TO (CLIENT)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(q.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (q.clientPhone != null)
                                    Text(q.clientPhone!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(160))),
                                  if (q.clientAddress != null)
                                    Text(q.clientAddress!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(160))),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('ISSUED DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(q.formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 8),
                                if (q.formattedValidUntil != null) ...[
                                  const Text('VALID UNTIL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(q.formattedValidUntil!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF59E0B))),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Subject & Scope
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              if (q.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(q.description, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withAlpha(180))),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // If Uploaded Document / Scan
                        if (q.isUploadedDocument && q.attachmentUrl != null && q.attachmentUrl!.isNotEmpty) ...[
                          const Text('ATTACHED QUOTATION DOCUMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _viewFullAttachment(q.attachmentUrl!),
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: q.attachmentUrl!,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  height: 220,
                                  color: Colors.grey.withAlpha(30),
                                  child: const Center(child: CircularProgressIndicator()),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  height: 120,
                                  color: Colors.grey.withAlpha(30),
                                  child: const Center(child: Icon(Icons.picture_as_pdf, size: 48, color: Color(0xFF06B6D4))),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Standard Items Table (if any)
                        if (q.items.isNotEmpty) ...[
                          const Text('ITEMIZED BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.dividerColor.withAlpha(30)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      Expanded(child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      Expanded(flex: 2, child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    ],
                                  ),
                                ),
                                for (int i = 0; i < q.items.length; i++) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 3, child: Text(q.items[i].description, style: const TextStyle(fontSize: 13))),
                                        Expanded(child: Text('${q.items[i].quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            currencyFormatter.format(q.items[i].unitPrice),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            currencyFormatter.format(q.items[i].total),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (i < q.items.length - 1) const Divider(height: 1),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Financial Totals Block
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildRow('Subtotal', q.formattedSubtotal),
                              if (q.tax > 0) ...[
                                const SizedBox(height: 6),
                                _buildRow('Tax / VAT', '${q.currency} ${currencyFormatter.format(q.tax)}'),
                              ],
                              if (q.discount > 0) ...[
                                const SizedBox(height: 6),
                                _buildRow('Discount', '- ${q.currency} ${currencyFormatter.format(q.discount)}', isDiscount: true),
                              ],
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                  Text(
                                    q.formattedTotal,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0891B2)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Terms / Guarantee Notes
                        if (q.notes != null && q.notes!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text('TERMS & PAYMENT CONDITIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Text(q.notes!, style: TextStyle(fontSize: 12, height: 1.4, color: theme.colorScheme.onSurface.withAlpha(160))),
                        ],

                        const SizedBox(height: 24),
                        // FindiPro Trust watermark
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF06B6D4)),
                              const SizedBox(width: 6),
                              Text(
                                'FindiPro Verified Standard Document',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withAlpha(120)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Provider Action: If requested, provide button to make invoice
            if (_isProvider && q.isRequested) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Prepare & Send Quotation / Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuotationMakerScreen(
                          existingQuotation: q,
                          clientId: q.clientId,
                          clientName: q.clientName,
                          conversationId: q.conversationId,
                          bookingId: q.bookingId,
                        ),
                      ),
                    );
                    if (res == true) _fetchQuotation();
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Client Action: Accept or Decline
            if (_isClient && q.isSent) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Decline'),
                      onPressed: _processingAction ? null : _declineQuotation,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _processingAction
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Accept Quotation', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _processingAction ? null : _acceptQuotation,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Chat button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(_isClient ? 'Chat with ${q.providerName}' : 'Chat with ${q.clientName}'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _openChat,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _viewFullAttachment(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Document Preview')),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Center(child: Text('Could not load image preview')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDiscount ? Colors.redAccent : null,
          ),
        ),
      ],
    );
  }
}
