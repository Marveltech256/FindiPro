import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/empty_state.dart';
import '../chat_screen.dart';
import '../my_requests_screen.dart';
import '../provider/provider_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notifRepo = NotificationRepository();
  final _userRepo = UserRepository();

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'hire_request':
        return Icons.work_outline;
      case 'hire_accepted':
        return Icons.check_circle_outline;
      case 'hire_declined':
        return Icons.cancel_outlined;
      case 'hire_cancelled':
        return Icons.highlight_off_outlined;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'review':
        return Icons.star_outline;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'hire_request':
        return const Color(0xFF06B6D4);
      case 'hire_accepted':
        return Colors.green;
      case 'hire_declined':
      case 'hire_cancelled':
        return Colors.redAccent;
      case 'message':
        return Colors.blue;
      case 'review':
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    // Mark as read
    if (!notification.isRead) {
      await _notifRepo.markAsRead(notification.id);
    }

    if (!mounted) return;

    final data = notification.data ?? {};
    final type = notification.type.toLowerCase();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (type == 'message' && uid != null) {
      final senderId = (data['sender_id'] ?? '').toString();
      final receiverId = (data['receiver_id'] ?? '').toString();
      final otherUserId = (senderId == uid) ? receiverId : senderId;

      if (otherUserId.isNotEmpty) {
        UserModel? otherUser;
        try {
          otherUser = await _userRepo.getUser(otherUserId);
        } catch (_) {}

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                currentUserId: uid,
                otherUserId: otherUserId,
                otherUserName: otherUser?.name ?? 'User',
                otherUserPhotoUrl: otherUser?.photoUrl,
              ),
            ),
          );
          return;
        }
      }
    }

    if (type.startsWith('hire_')) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
        );
      }
      return;
    }

    if (type == 'review') {
      final providerId = (data['provider_id'] ?? '').toString();
      if (providerId.isNotEmpty) {
        UserModel? providerUser;
        try {
          providerUser = await _userRepo.getUser(providerId);
        } catch (_) {}

        if (providerUser != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProviderDetailScreen(provider: providerUser!),
            ),
          );
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to view notifications.')),
      );
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              await _notifRepo.markAllAsRead(uid);
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notifRepo.getNotificationsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Could not load notifications.'));
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'No Notifications Yet',
              subtitle: 'When you receive updates about requests, messages, or reviews, they will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = notifications[index];
              final isUnread = !n.isRead;
              final iconColor = _getNotificationColor(n.type);

              return InkWell(
                onTap: () => _handleNotificationTap(n),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: isUnread ? const Color(0xFF06B6D4).withAlpha(15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: iconColor.withAlpha(25),
                        child: Icon(_getNotificationIcon(n.type), color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: TextStyle(
                                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatRelativeTime(n.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isUnread ? const Color(0xFF06B6D4) : Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.body,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF06B6D4),
                              shape: BoxShape.circle,
                            ),
                          ),
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
    );
  }
}

