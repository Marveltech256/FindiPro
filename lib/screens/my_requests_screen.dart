import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/empty_state.dart';
class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Please login to view your requests.')));
    return Scaffold(
        appBar: AppBar(title: const Text('My Requests')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('hire_requests').where('clientId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, s) {
              if (s.hasError) return const Center(child: Text('Could not load your requests.'));
              if (s.connectionState == ConnectionState.waiting || !s.hasData) return const Center(child: CircularProgressIndicator());
              final docs = s.data!.docs;
              if (docs.isEmpty) return const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No Requests Yet',
                subtitle: 'When you request a service from a provider, it will appear here.',
              );
              return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final status = d['status'] as String? ?? 'pending';
                    return Card(
                      child: ListTile(
                        title: Text(d['providerName'] ?? 'Provider', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(d['serviceNeeded'] ?? 'Service'),
                        trailing: statusChip(status),
                        onTap: () {
                          // TODO: Navigate to a request detail screen
                        },
                      ),
                    );
                  });
            }));
  }
}

Widget statusChip(String status) {
  Color color;
  switch (status.toLowerCase()) {
    case 'accepted':
      color = Colors.green;
      break;
    case 'in_progress':
      color = Colors.orange;
      break;
    case 'completed':
      color = Colors.blue;
      break;
    case 'cancelled':
    case 'declined':
      color = Colors.red;
      break;
    default: // 'pending'
      color = Colors.grey;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status.replaceAll('_', ' ').toUpperCase(),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    ),
  );
}

/*
@override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Please login to view your requests.')));
    return Scaffold(
        appBar: AppBar(title: const Text('My Requests')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('hire_requests').where('clientId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, s) {
              if (s.hasError) return const Center(child: Text('Could not load your requests.'));
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final docs = s.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('You have not made any hire requests yet.'));
              return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final ts = d['createdAt'] as Timestamp?;
                    return Card(child: ListTile(title: Text(d['providerName'] ?? 'Provider', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${d['serviceNeeded'] ?? 'Service'}\nStatus: ${d['status'] ?? 'pending'}'), isThreeLine: true, trailing: Text(ts == null ? '' : '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}')));
                  });
            }));
  }
}*/
