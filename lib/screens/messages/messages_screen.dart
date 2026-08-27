import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/conversation.dart';
import '../../repositories/message_repository.dart';
import '../../widgets/empty_state.dart';
import '../chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  String _formatConversationTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dt.year, dt.month, dt.day);

    if (messageDate == today) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (today.difference(messageDate).inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // React to auth state instead of checking currentUser once. This
    // screen lives inside an IndexedStack that only builds once at
    // startup, so a one-time synchronous check can permanently miss a
    // session that finishes restoring a moment later.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (user == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.message_outlined,
              title: 'Login Required',
              subtitle: 'Please log in to view your messages.',
            ),
          );
        }

        return _MessagesList(user: user, formatTime: _formatConversationTime);
      },
    );
  }
}

class _MessagesList extends StatelessWidget {
  final User user;
  final String Function(DateTime) formatTime;

  const _MessagesList({required this.user, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: MessageRepository().getUserConversations(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator.adaptive(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 56,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load messages',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No conversations yet',
              subtitle: 'Start a conversation from a hire request or provider profile.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final hasUnread = conversation.clientUnreadCount > 0;
              final hasPhoto = conversation.otherParticipantPhotoUrl.isNotEmpty;

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: ClipOval(
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: hasPhoto
                          ? Image.network(
                              conversation.otherParticipantPhotoUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.person, size: 28, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.person, size: 28, color: Colors.grey),
                            ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.otherParticipantName.isNotEmpty
                              ? conversation.otherParticipantName
                              : 'User',
                          style: TextStyle(
                            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formatTime(conversation.lastMessageAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread ? const Color(0xFF06B6D4) : Colors.grey,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessage.isNotEmpty
                                ? conversation.lastMessage
                                : 'Start a conversation',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${conversation.clientUnreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 20,
                  ),
                  onTap: () {
                    final otherUserId = conversation.clientId == user.uid
                        ? conversation.providerId
                        : conversation.clientId;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: conversation.id,
                          currentUserId: user.uid,
                          otherUserId: otherUserId,
                          otherUserName: conversation.otherParticipantName,
                          otherUserPhotoUrl: conversation.otherParticipantPhotoUrl,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}