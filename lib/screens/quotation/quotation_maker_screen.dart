import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/quotation_model.dart';
import '../../models/user_model.dart';
import '../../repositories/quotation_repository.dart';
import '../../repositories/user_repository.dart';

class QuotationMakerScreen extends StatefulWidget {
  final QuotationModel? existingQuotation;
  final String? clientId;
  final String? clientName;
  final String? conversationId;
  final String? bookingId;

  const QuotationMakerScreen({
    super.key,
    this.existingQuotation,
    this.clientId,
    this.clientName,
    this.conversationId,
    this.bookingId,
  });

  @override
  State<QuotationMakerScreen> createState() => _QuotationMakerScreenState();
}

class _LineItemEntry {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(text: '1');
  final TextEditingController unitPriceController = TextEditingController(text: '0');

  double get quantity => double.tryParse(quantityController.text) ?? 1.0;
  double get unitPrice => double.tryParse(unitPriceController.text.replaceAll(',', '')) ?? 0.0;
  double get total => quantity * unitPrice;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
  }
}

class _QuotationMakerScreenState extends State<QuotationMakerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _repo = QuotationRepository();
  final _userRepo = UserRepository();
  final _picker = ImagePicker();

  // Company / Provider Details
  final _companyNameController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyAddressController = TextEditingController();

  // Client Details
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientAddressController = TextEditingController();

  // Quote Metadata
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController(
    text: 'Payment terms: 50% advance deposit upon acceptance, balance upon completion. Valid for 14 days.',
  );
  final _taxPercentController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');

  // Uploaded Document mode
  File? _uploadedFile;
  final _directAmountController = TextEditingController();

  final List<_LineItemEntry> _lineItems = [];
  DateTime _validUntil = DateTime.now().add(const Duration(days: 14));
  bool _submitting = false;
  String _currency = 'UGX';
  UserModel? _providerUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      _providerUser = await _userRepo.getUser(currentUid);
      if (_providerUser != null && mounted) {
        setState(() {
          _companyNameController.text = _providerUser!.name;
          _companyPhoneController.text = _providerUser!.phone;
          _companyEmailController.text = _providerUser!.email;
          _companyAddressController.text = _providerUser!.location ?? '';
        });
      }
    }

    if (widget.existingQuotation != null) {
      final q = widget.existingQuotation!;
      _titleController.text = q.title;
      _descriptionController.text = q.description;
      _clientNameController.text = q.clientName;
      _clientPhoneController.text = q.clientPhone ?? '';
      _clientAddressController.text = q.clientAddress ?? '';
      _currency = q.currency;
      if (q.validUntil != null) _validUntil = q.validUntil!;
      if (q.notes != null) _notesController.text = q.notes!;

      if (q.items.isNotEmpty) {
        for (final item in q.items) {
          final entry = _LineItemEntry();
          entry.descriptionController.text = item.description;
          entry.quantityController.text = item.quantity.toString();
          entry.unitPriceController.text = item.unitPrice.toStringAsFixed(0);
          _lineItems.add(entry);
        }
      }
    } else {
      _clientNameController.text = widget.clientName ?? 'Valued Client';
      _titleController.text = 'Professional Service Quotation';
      _descriptionController.text = 'Quotation for requested service and materials.';
    }

    if (_lineItems.isEmpty) {
      _addItemRow();
    }

    setState(() {});
  }

  void _addItemRow() {
    final item = _LineItemEntry();
    item.quantityController.addListener(() => setState(() {}));
    item.unitPriceController.addListener(() => setState(() {}));
    setState(() => _lineItems.add(item));
  }

  void _removeItemRow(int index) {
    if (_lineItems.length <= 1) return;
    final item = _lineItems.removeAt(index);
    item.dispose();
    setState(() {});
  }

  double get _subtotal {
    return _lineItems.fold(0.0, (acc, item) => acc + item.total);
  }

  double get _taxAmount {
    final percent = double.tryParse(_taxPercentController.text) ?? 0.0;
    return _subtotal * (percent / 100.0);
  }

  double get _discountAmount {
    return double.tryParse(_discountController.text.replaceAll(',', '')) ?? 0.0;
  }

  double get _grandTotal {
    final total = _subtotal + _taxAmount - _discountAmount;
    return total > 0 ? total : 0.0;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _companyAddressController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _clientAddressController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _taxPercentController.dispose();
    _discountController.dispose();
    _directAmountController.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => _uploadedFile = File(picked.path));
    }
  }

  Future<void> _submitQuotation() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in as a service provider.')),
      );
      return;
    }

    final isUploadMode = _tabController.index == 1;

    if (!isUploadMode && _lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item.')),
      );
      return;
    }

    if (isUploadMode && _uploadedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or photograph the quotation document.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final quotationId = widget.existingQuotation?.id ??
          (await _repo.requestQuotation(
            clientId: widget.clientId ?? 'unknown',
            clientName: _clientNameController.text.trim(),
            providerId: currentUid,
            providerName: _companyNameController.text.trim(),
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            conversationId: widget.conversationId,
            bookingId: widget.bookingId,
          ))
              .id;

      String? uploadedUrl;
      if (isUploadMode && _uploadedFile != null) {
        uploadedUrl = await _repo.uploadQuotationDocument(_uploadedFile!, quotationId: quotationId);
      }

      final List<QuotationItem> finalItems = isUploadMode
          ? [
              QuotationItem(
                description: _descriptionController.text.trim().isNotEmpty
                    ? _descriptionController.text.trim()
                    : 'Full Service Package (As per attached document)',
                quantity: 1,
                unitPrice: double.tryParse(_directAmountController.text.replaceAll(',', '')) ?? 0.0,
              )
            ]
          : _lineItems
              .map((e) => QuotationItem(
                    description: e.descriptionController.text.trim(),
                    quantity: e.quantity,
                    unitPrice: e.unitPrice,
                  ))
              .toList();

      final double finalSubtotal = isUploadMode
          ? (double.tryParse(_directAmountController.text.replaceAll(',', '')) ?? 0.0)
          : _subtotal;

      final double finalTotal = isUploadMode ? finalSubtotal : _grandTotal;

      await _repo.sendQuotation(
        quotationId: quotationId,
        providerId: currentUid,
        providerName: _companyNameController.text.trim(),
        providerPhone: _companyPhoneController.text.trim(),
        providerEmail: _companyEmailController.text.trim(),
        providerAddress: _companyAddressController.text.trim(),
        providerLogoUrl: _providerUser?.photoUrl,
        clientId: widget.clientId ?? widget.existingQuotation?.clientId ?? 'unknown',
        clientName: _clientNameController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        currency: _currency,
        items: finalItems,
        subtotal: finalSubtotal,
        tax: isUploadMode ? 0.0 : _taxAmount,
        discount: isUploadMode ? 0.0 : _discountAmount,
        totalAmount: finalTotal,
        notes: _notesController.text.trim(),
        attachmentUrl: uploadedUrl,
        isUploadedDocument: isUploadMode,
        validUntil: _validUntil,
        conversationId: widget.conversationId,
        bookingId: widget.bookingId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Quotation dispatched to client successfully! Instant notification sent.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to dispatch quotation: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat('#,###', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('In-App Invoice / Quotation Maker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF06B6D4),
          labelColor: const Color(0xFF06B6D4),
          unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(150),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Create Standard Invoice'),
            Tab(icon: Icon(Icons.upload_file), text: 'Upload Scanned Doc'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: STANDARD INVOICE BUILDER
            _buildStandardInvoiceTab(theme, currencyFormatter),

            // TAB 2: UPLOAD DOCUMENT INVOICE
            _buildUploadDocumentTab(theme),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: theme.dividerColor.withAlpha(30))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Estimate', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      _tabController.index == 0
                          ? '$_currency ${currencyFormatter.format(_grandTotal)}'
                          : '$_currency ${_directAmountController.text.isEmpty ? "0" : _directAmountController.text}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0891B2)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _submitting ? 'Dispatching...' : 'Send to Client',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _submitting ? null : _submitQuotation,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardInvoiceTab(ThemeData theme, NumberFormat formatter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Company details section
          _buildCard(
            title: 'Your Business / Company Details',
            icon: Icons.business,
            child: Column(
              children: [
                TextFormField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(labelText: 'Company / Business Name *', prefixIcon: Icon(Icons.badge_outlined, size: 20)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _companyPhoneController,
                        decoration: const InputDecoration(labelText: 'Business Phone', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _companyEmailController,
                        decoration: const InputDecoration(labelText: 'Business Email', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _companyAddressController,
                  decoration: const InputDecoration(labelText: 'Business Address / City', prefixIcon: Icon(Icons.location_on_outlined, size: 20)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bill To Section
          _buildCard(
            title: 'Bill To (Client)',
            icon: Icons.person_outline,
            child: Column(
              children: [
                TextFormField(
                  controller: _clientNameController,
                  decoration: const InputDecoration(labelText: 'Client Name *', prefixIcon: Icon(Icons.person, size: 20)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _clientPhoneController,
                  decoration: const InputDecoration(labelText: 'Client Phone', prefixIcon: Icon(Icons.phone, size: 20)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quote title
          _buildCard(
            title: 'Quotation Subject & Scope',
            icon: Icons.description_outlined,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Job Title / Service *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Scope Overview'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Itemized Line Items
          _buildCard(
            title: 'Itemized Breakdown (Labor & Materials)',
            icon: Icons.list_alt,
            action: TextButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _addItemRow,
            ),
            child: Column(
              children: [
                for (int i = 0; i < _lineItems.length; i++) ...[
                  _buildLineItemRow(i, formatter),
                  if (i < _lineItems.length - 1) const Divider(height: 24),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary Card
          _buildCard(
            title: 'Financial Summary',
            icon: Icons.calculate_outlined,
            child: Column(
              children: [
                _buildSummaryRow('Subtotal', '$_currency ${formatter.format(_subtotal)}'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Tax / VAT (%)', style: TextStyle(fontSize: 14)),
                    const Spacer(),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: _taxPercentController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('($_currency ${formatter.format(_taxAmount)})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Discount ($_currency)', style: const TextStyle(fontSize: 14)),
                    const Spacer(),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        controller: _discountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, thickness: 1.2),
                _buildSummaryRow('Grand Total', '$_currency ${formatter.format(_grandTotal)}', isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Terms & Notes
          _buildCard(
            title: 'Terms & Payment Conditions',
            icon: Icons.note_outlined,
            child: TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Enter warranty, payment terms, or validity notes...'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLineItemRow(int index, NumberFormat formatter) {
    final item = _lineItems[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: item.descriptionController,
                decoration: InputDecoration(
                  labelText: 'Item ${index + 1} Description *',
                  hintText: 'e.g. Copper pipes, Labor fee...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter item description' : null,
              ),
            ),
            if (_lineItems.length > 1)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _removeItemRow(index),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 90,
              child: TextFormField(
                controller: item.quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Qty', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: item.unitPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Rate ($_currency)', contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Total', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text('$_currency ${formatter.format(item.total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadDocumentTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF06B6D4).withAlpha(50)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF06B6D4)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Upload your existing paper invoice, printed estimate, or PDF quotation. The client will be able to review and accept it directly in the app.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Upload box
          InkWell(
            onTap: () => _showImageSourcePicker(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF06B6D4), style: BorderStyle.solid, width: 1.5),
                borderRadius: BorderRadius.circular(16),
                color: theme.colorScheme.surface,
              ),
              child: _uploadedFile != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(_uploadedFile!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                              onPressed: () => _showImageSourcePicker(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 56, color: Color(0xFF06B6D4)),
                        SizedBox(height: 12),
                        Text('Tap to photograph or upload invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Supports Camera scan, JPG, PNG, PDF', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _directAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Total Quotation Amount ($_currency) *',
              hintText: 'e.g. 450,000',
              prefixIcon: const Icon(Icons.payments_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              if (_tabController.index == 1 && (v == null || v.trim().isEmpty)) {
                return 'Please enter total amount';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Quotation Title *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description / Scope Summary',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Color(0xFF06B6D4)),
              title: const Text('Take Photo / Scan Document'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF06B6D4)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child, Widget? action}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withAlpha(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF06B6D4)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: isBold ? const Color(0xFF0891B2) : null,
          ),
        ),
      ],
    );
  }
}
