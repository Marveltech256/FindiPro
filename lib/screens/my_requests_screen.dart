import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:findipro/repositories/booking_repository.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final BookingRepository _bookingRepository = BookingRepository();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_currentUser == null) {
      return const Center(
        child: Text('Please log in to see your requests.'),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _bookingRepository.getUserBookings(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('MyRequestsScreen Error: ${snapshot.error}');
          return const Center(
            child: Text('An error occurred while fetching your requests.'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'You have not made any hire requests yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();

            final service = data['serviceNeeded'] ?? 'Service Request';
            final status = data['status'] ?? 'Pending';
            final providerName = data['providerName'] ?? 'Provider';

            DateTime createdAt = DateTime.now();
            final timestamp = data['createdAt'];
            if (timestamp is Timestamp) {
              createdAt = timestamp.toDate();
            }

            return Card(
              child: ListTile(
                title: Text(
                  service,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Provider: $providerName'),
                    Text('Status: $status'),
                  ],
                ),
                trailing: Text(
                  '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          },
        );
      },
    );
  }
}