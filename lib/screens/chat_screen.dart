import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../repositories/message_repository.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId; final String currentUserId; final String otherUserId;
  const ChatScreen({super.key,required this.conversationId,required this.currentUserId,required this.otherUserId});
  @override State<ChatScreen> createState()=>_ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen>{
  final _text = TextEditingController();
  final _repo = MessageRepository();

  @override
  void initState() {
    super.initState();
    _repo.markMessagesAsRead(conversationId: widget.conversationId, currentUserId: widget.currentUserId);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    try {
      await _repo.sendMessage(conversationId: widget.conversationId, senderId: widget.currentUserId, receiverId: widget.otherUserId, text: text);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message could not be sent.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Conversation')),
        body: Column(children: [
          Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                  stream: _repo.getMessages(widget.conversationId),
                  builder: (context, s) {
                    if (s.hasError) return const Center(child: Text('Could not load messages.'));
                    if (!s.hasData) return const Center(child: CircularProgressIndicator());
                    final messages = s.data!;
                    if (messages.isEmpty) return const Center(child: Text('Say hello!'));
                    return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (c, i) {
                          final m = messages[i];
                          final me = m.senderId == FirebaseAuth.instance.currentUser?.uid;
                          return Align(
                              alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                  decoration: BoxDecoration(color: me ? const Color(0xFF06B6D4) : Colors.grey.shade200, borderRadius: BorderRadius.circular(18)),
                                  child: Text(m.text, style: TextStyle(color: me ? Colors.white : Colors.black87))));
                        });
                  })),
          SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [Expanded(child: TextField(controller: _text, decoration: const InputDecoration(hintText: 'Send a message...'))), IconButton(onPressed: _send, icon: const Icon(Icons.send))])))
        ]));
  }
}
