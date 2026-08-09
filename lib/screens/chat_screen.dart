import 'package:findipro/models/chat_message.dart';
import 'package:findipro/repositories/message_repository.dart';
import 'package:findipro/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherParticipantName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherParticipantName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    // Give a slight delay to ensure the widget is fully built
    Future.delayed(const Duration(milliseconds: 500), () {
      final messageRepo = context.read<MessageRepository>();
      final authService = context.read<AuthService>();
      final uid = authService.currentUser?.uid;
      if (uid != null) {
        messageRepo.markMessagesAsRead(
          conversationId: widget.conversationId,
          currentUserId: uid,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final messageRepo = context.read<MessageRepository>();
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid;
    final text = _messageController.text;

    if (uid != null && text.isNotEmpty) {
      // The receiverId needs to be fetched from the conversation document.
      // This is a simplified approach. A robust solution would fetch the conversation
      // details once and store them in the state.
      // For now, we assume the other participant is the receiver.
      // A full implementation would get the participants list and find the other ID.
      messageRepo.sendMessage(
        conversationId: widget.conversationId,
        senderId: uid,
        receiverId: '', // This needs to be the other participant's ID
        text: text,
      );
      _messageController.clear();
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageRepo = context.read<MessageRepository>();
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherParticipantName),
        // TODO: Add a popup menu for Block/Report actions
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: messageRepo.getMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Say hello!'));
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == uid;
                    return _MessageBubble(message: message, isMe: isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Send a message...',
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: isMe ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}