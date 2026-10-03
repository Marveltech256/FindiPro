import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/utils/uuid_utils.dart';
import '../core/widgets/report_dialog.dart';
import '../models/chat_message.dart';
import '../models/user_model.dart';
import '../repositories/message_repository.dart';
import '../repositories/user_repository.dart';
import '../services/presence_service.dart';
import 'auth/login_screen.dart';
import 'quotation/quotation_maker_screen.dart';
import 'quotation/quotations_list_screen.dart';
import 'quotation/request_quotation_screen.dart';

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

  void _showQuotationActions() async {
    final otherUser = await _userRepo.getUser(widget.otherUserId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 10),
                  Text('Quotations & Invoices', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.request_quote_outlined, color: Color(0xFF06B6D4)),
              title: const Text('Request Quotation from Partner'),
              subtitle: const Text('Ask for a formal price estimate for a job'),
              onTap: () {
                Navigator.pop(ctx);
                if (otherUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestQuotationScreen(
                        provider: otherUser,
                        conversationId: widget.conversationId,
                        bookingId: widget.bookingId,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not load user details.')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.post_add, color: Color(0xFF10B981)),
              title: const Text('Create & Send Invoice / Quotation'),
              subtitle: const Text('Use standard invoice maker or upload document'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuotationMakerScreen(
                      clientId: widget.otherUserId,
                      clientName: _displayName ?? 'Client',
                      conversationId: widget.conversationId,
                      bookingId: widget.bookingId,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.amber),
              title: const Text('View Quotations & Invoices History'),
              subtitle: const Text('All pending, accepted and sent invoices'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QuotationsListScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
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
        title: StreamBuilder<Map<String, dynamic>>(
          stream: PresenceService().watchPresence(widget.otherUserId),
          builder: (context, presenceSnap) {
            final isOnline = presenceSnap.data?['is_online'] == true;
            final lastSeen = presenceSnap.data?['last_seen'] as DateTime?;
            final presenceText = UserModel.formatPresence(isOnline: isOnline, lastSeen: lastSeen);

            return Row(
              children: [
                Stack(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                            ? Image.network(
                                _photoUrl!,
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.person, size: 22, color: Colors.grey),
                                ),
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.person, size: 22, color: Colors.grey),
                              ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
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
                      Row(
                        children: [
                          if (isOnline) ...[
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              'Online',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else ...[
                            Text(
                              presenceText,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (_category != null && _category!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• $_category',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF06B6D4)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'quotations') {
                _showQuotationActions();
              } else if (val == 'report') {
                showReportUserDialog(
                  context,
                  reportedUserId: widget.otherUserId,
                  reportedUserName: _displayName ?? 'User',
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'quotations',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Color(0xFF06B6D4), size: 20),
                    SizedBox(width: 8),
                    Text('Quotations & Invoices'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Report User', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<Map<String, dynamic>>(
            stream: PresenceService().watchPresence(widget.otherUserId),
            builder: (context, presenceSnap) {
              final isOnline = presenceSnap.data?['is_online'] == true;
              final lastSeen = presenceSnap.data?['last_seen'] as DateTime?;
              if (!isOnline && lastSeen != null) {
                final diffDays = DateTime.now().difference(lastSeen).inDays;
                if (diffDays >= 14) {
                  return Container(
                    width: double.infinity,
                    color: const Color(0xFFFEF3C7),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notice: This user has been inactive for $diffDays days and may take longer to respond.',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
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
                          color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                color: isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
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
                                    color: isMe ? Theme.of(context).colorScheme.onPrimary.withAlpha(200) : Theme.of(context).colorScheme.onSurface.withAlpha(110),
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    message.isRead ? Icons.done_all : Icons.done,
                                    size: 13,
                                    color: message.isRead ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onPrimary.withAlpha(180),
                                  ),
                                ],
                              ],
                            ),
                            if (message.text.contains('[Official Quotation:') ||
                                message.text.contains('[Quotation Request:') ||
                                message.text.contains('[Quotation Accepted]')) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const QuotationsListScreen()),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.white.withAlpha(40) : const Color(0xFF06B6D4).withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.visibility_outlined, size: 14, color: isMe ? Colors.white : const Color(0xFF06B6D4)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'View Quotation / Invoice',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isMe ? Colors.white : const Color(0xFF06B6D4),
                                        ),
                                      ),
                                    ],
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
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withAlpha(30),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.receipt_long, color: Color(0xFF06B6D4), size: 24),
                    tooltip: 'Quotations & Invoices',
                    onPressed: _showQuotationActions,
                  ),
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
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
