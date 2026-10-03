import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/quotation_model.dart';
import '../../repositories/quotation_repository.dart';
import 'quotation_detail_screen.dart';

class QuotationsListScreen extends StatelessWidget {
  const QuotationsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);

    if (currentUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Quotations & Invoices')),
        body: const Center(child: Text('Please log in to view your quotations.')),
      );
    }

    final repo = QuotationRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotations & Invoices', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: StreamBuilder<List<QuotationModel>>(
        stream: repo.streamQuotationsForUser(currentUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final quotations = snapshot.data ?? [];

          if (quotations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_outlined, size: 54, color: Color(0xFF06B6D4)),
                  ),
                  const SizedBox(height: 16),
                  const Text('No Quotations Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'When you request a quotation or receive an invoice from a service provider, it will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(160), fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: quotations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final q = quotations[index];
              final isClient = currentUid == q.clientId;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuotationDetailScreen(
                        quotationId: q.id,
                        initialQuotation: q,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.dividerColor.withAlpha(30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            q.quotationNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0891B2)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: q.statusColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              q.statusLabel,
                              style: TextStyle(
                                color: q.statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isClient ? 'From: ${q.providerName}' : 'To: ${q.clientName}',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withAlpha(160)),
                      ),
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            q.formattedDate,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(140)),
                          ),
                          Text(
                            q.formattedTotal,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0891B2)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
