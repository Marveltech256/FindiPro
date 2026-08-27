import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/utils/uuid_utils.dart';
import '../models/chat_message.dart';
import '../repositories/message_repository.dart';
import '../repositories/user_repository.dart';
import 'auth/login_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String currentUserId;
  final String otherUserId;
  final String? otherUserName;
  final String? otherUserPhotoUrl;
  final String? bookingId;

  const ChatScreen({
    super.key,
    this.conversationId,
    required this.currentUserId,
    required this.otherUserId,
    this.otherUserName,
    this.otherUserPhotoUrl,
    this.bookingId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scrollController = ScrollController();
  final _repo = MessageRepository();
  final _userRepo = UserRepository();

  String? _displayName;
  String? _photoUrl;
  String? _category;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _displayName = widget.otherUserName;
    _photoUrl = widget.otherUserPhotoUrl;
    _loadOtherUser();
    _markRead();
  }

  Future<void> _loadOtherUser() async {
    final user = await _userRepo.getUser(widget.otherUserId);
    if (user != null && mounted) {
      setState(() {
        _displayName = user.name.isNotEmpty ? user.name : _displayName;
        _photoUrl = user.photoUrl ?? _photoUrl;
        _category = user.category;
      });
    }
  }

  void _markRead() {
    _repo.markMessagesAsRead(
      currentUserId: widget.currentUserId,
      otherUserId: widget.otherUserId,
      conversationId: widget.conversationId,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send messages.')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    setState(() => _sending = true);

    try {
      await _repo.sendMessage(
        senderId: currentUser.uid,
        receiverId: widget.otherUserId,
        text: text,
        conversationId: widget.conversationId,
        bookingId: widget.bookingId,
      );
      _text.clear();
    } catch (e) {
      debugPrint('>>> [ChatScreen._send] error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message could not be sent. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Login Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'You must be signed in to view and send messages.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(153)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentUuid = UuidUtils.firebaseUidToUuid(widget.currentUserId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 36,
                height: 36,
                child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                    ? Image.network(
                        _photoUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.person, size: 20, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.person, size: 20, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayName ?? 'Chat',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_category != null && _category!.isNotEmpty)
                    Text(
                      _category!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF06B6D4)),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _repo.getMessages(
                currentUserId: widget.currentUserId,
                otherUserId: widget.otherUserId,
                conversationId: widget.conversationId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Could not load messages: ${snapshot.error}'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator.adaptive());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Theme.of(context).colorScheme.onSurface.withAlpha(80)),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withAlpha(153)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Say hello to start the conversation!',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
                        ),
                      ],
                    ),
                  );
                }

                // Trigger read receipt on newly arrived messages
                _markRead();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == widget.currentUserId ||
                        message.senderId == currentUuid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF06B6D4) : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                fontSize: 15,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(message.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withAlpha(110),
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    message.isRead ? Icons.done_all : Icons.done,
                                    size: 13,
                                    color: message.isRead ? Colors.white : Colors.white70,
                                  ),
                                ],
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
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    offset: const Offset(0, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF06B6D4),
                    child: IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sending ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
