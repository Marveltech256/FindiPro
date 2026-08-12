import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/user_model.dart';

class MessageRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Conversation>> getUserConversations(String uid) {
    return _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final conversations = snapshot.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .toList();

      for (final conversation in conversations) {
        final otherUserId = conversation.clientId == uid ? conversation.providerId : conversation.clientId;
        final userDoc = await _db.collection('users').doc(otherUserId).get();
        if (userDoc.exists) {
          final user = UserModel.fromFirestore(userDoc);
          conversation.otherParticipantName = user.name;
          conversation.otherParticipantPhotoUrl = user.photoUrl ?? '';
        }
      }
      return conversations;
      });
  }

  Stream<List<ChatMessage>> getMessages(String id) => _db.collection('conversations').doc(id).collection('messages').orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(ChatMessage.fromFirestore).toList());
  Future<String> createConversation({required String bookingId, required String clientId, required String providerId}) async {
    final existing = await _db.collection('conversations').where('bookingId', isEqualTo: bookingId).limit(1).get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;
    final ref = _db.collection('conversations').doc();
    await ref.set({
      'bookingId': bookingId,
      'clientId': clientId,
      'providerId': providerId,
      'participants': [clientId, providerId],
      'lastMessage': 'Conversation started',
      'lastMessageSenderId': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'clientUnreadCount': 0,
      'providerUnreadCount': 0,
      'isBlocked': false,
      'blockedBy': null,
      'createdAt': FieldValue.serverTimestamp()
    });
    return ref.id;
  }

  Future<void> sendMessage({required String conversationId, required String senderId, required String receiverId, required String text}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw Exception('Empty message');
    final ref = _db.collection('conversations').doc(conversationId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Conversation not found');
      final c = Conversation.fromFirestore(snap);
      if (!c.participants.contains(senderId) || !c.participants.contains(receiverId) || c.isBlocked) throw Exception('Not authorized');
      final message = ref.collection('messages').doc();
      final receiverField = receiverId == c.clientId ? 'clientUnreadCount' : 'providerUnreadCount';
      tx.set(message, {'senderId': senderId, 'receiverId': receiverId, 'text': trimmed, 'type': 'text', 'isRead': false, 'createdAt': FieldValue.serverTimestamp()});
      tx.update(ref, {'lastMessage': trimmed, 'lastMessageSenderId': senderId, 'lastMessageAt': FieldValue.serverTimestamp(), receiverField: FieldValue.increment(1)});
    });
  }

  Future<void> markMessagesAsRead({required String conversationId, required String currentUserId}) async {
    final ref = _db.collection('conversations').doc(conversationId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final c = Conversation.fromFirestore(snap);
    if (!c.participants.contains(currentUserId)) return;
    final field = currentUserId == c.clientId ? 'clientUnreadCount' : 'providerUnreadCount';
    final unread = await ref.collection('messages').where('receiverId', isEqualTo: currentUserId).where('isRead', isEqualTo: false).get();
    final batch = _db.batch();
    batch.update(ref, {field: 0});
    for (final doc in unread.docs) batch.update(doc.reference, {'isRead': true});
    await batch.commit();
  }
}
