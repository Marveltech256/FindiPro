import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final user = docs[index];
              final data = user.data() as Map<String, dynamic>;

              return ListTile(
                title: Text(data['name'] ?? 'User'),
                subtitle: Text(data['email'] ?? ''),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'block') {
                      await user.reference.update({
                        'isBlocked': true,
                      });
                    }

                    if (value == 'unblock') {
                      await user.reference.update({
                        'isBlocked': false,
                      });
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'block',
                      child: Text('Block'),
                    ),
                    PopupMenuItem(
                      value: 'unblock',
                      child: Text('Unblock'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}