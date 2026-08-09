import 'package:findipro/models/notification_model.dart';
import 'package:findipro/repositories/notification_repository.dart';
import 'package:findipro/services/auth_service.dart';
import 'package:findipro/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// A screen that displays a list of notifications for the authenticated user.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final notificationRepo = context.read<NotificationRepository>();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: uid == null // If user is not authenticated
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('You must be logged in to see your notifications.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
                      },
                      child: const Text('Login to View Notifications'),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<List<NotificationModel>>(
              stream: notificationRepo.getNotificationsStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('You have no notifications yet.', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  );
                }

                final notifications = snapshot.data!;

                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationTile(
                      notification: notification,
                      onTap: () {
                        if (!notification.isRead) {
                          notificationRepo.markAsRead(notification.id);
                        }
                        // TODO: Add navigation logic based on notification.type and notification.referenceId
                        // Example: if (notification.type == NotificationType.message) {
                        //   Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: notification.referenceId)));
                        // }
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return Container(
      color: isUnread ? theme.primaryColor.withValues(alpha: 0.05) : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isUnread ? theme.colorScheme.secondary : Colors.transparent,
          radius: isUnread ? 5 : 0,
        ),
        title: Text(
          notification.title,
          style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
        ),
        subtitle: Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(
          _formatTimestamp(notification.createdAt),
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    final dt = (timestamp as Timestamp).toDate();
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat.yMMMd().format(dt);
    }
  }
}