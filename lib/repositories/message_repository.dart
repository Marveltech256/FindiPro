import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:findipro/models/chat_message.dart';
import 'package:findipro/models/conversation.dart';
import 'package:findipro/models/user_model.dart';

class MessageRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Retrieves a stream of conversations for a given user.
  /// It also fetches the other participant's details to enrich the conversation data.
  Stream<List<Conversation>> getUserConversations(String uid) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final conversations = snapshot.docs.map((doc) => Conversation.fromFirestore(doc)).toList();

      // Fetch details for the other participant in each conversation
      for (var convo in conversations) {
        final otherParticipantId = convo.participants.firstWhere((id) => id != uid, orElse: () => '');
        if (otherParticipantId.isNotEmpty) {
          final userDoc = await _firestore.collection('users').doc(otherParticipantId).get();
          if (userDoc.exists) {
            final user = UserModel.fromFirestore(userDoc);
            convo.otherParticipantName = user.name;
            convo.otherParticipantPhotoUrl = user.photoUrl ?? '';
          }
        }
      }
      return conversations;
    });
  }

  /// Retrieves a stream of messages for a specific conversation.
  Stream<List<ChatMessage>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }

  /// Creates a new conversation document. Returns the ID of the new conversation.
  Future<String> createConversation({
    required String bookingId,
    required String clientId,
    required String providerId,
  }) async {
    final conversationRef = _firestore.collection('conversations').doc();
    final now = Timestamp.now();

    await conversationRef.set({
      'bookingId': bookingId,
      'clientId': clientId,
      'providerId': providerId,
      'participants': [clientId, providerId],
      'lastMessage': 'Conversation started.',
      'lastMessageSenderId': '', // System message
      'lastMessageAt': now,
      'clientUnreadCount': 0,
      'providerUnreadCount': 0,
      'isBlocked': false,
      'blockedBy': null,
      'createdAt': now,
    });

    return conversationRef.id;
  }

  /// Sends a message and updates the conversation's summary fields atomically.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();
    final now = Timestamp.now();

    // Use a transaction to ensure atomicity
    await _firestore.runTransaction((transaction) async {
      final convoSnapshot = await transaction.get(conversationRef);
      if (!convoSnapshot.exists) {
        throw Exception("Conversation does not exist!");
      }

      final conversation = Conversation.fromFirestore(convoSnapshot);

      // Determine which user's unread count to increment
      String unreadCountField;
      if (senderId == conversation.clientId) {
        unreadCountField = 'providerUnreadCount';
      } else {
        unreadCountField = 'clientUnreadCount';
      }

      // 1. Update the conversation document
      transaction.update(conversationRef, {
        'lastMessage': text,
        'lastMessageSenderId': senderId,
        'lastMessageAt': now,
        unreadCountField: FieldValue.increment(1),
      });

      // 2. Create the new message document
      transaction.set(messageRef, {
        'senderId': senderId,
        'receiverId': receiverId,
        'text': text,
        'type': 'text',
        'isRead': false,
        'createdAt': now,
      });
    });
  }

  /// Marks all unread messages in a conversation as read for the current user.
  Future<void> markMessagesAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    final messagesQuery = conversationRef.collection('messages').where('receiverId', isEqualTo: currentUserId).where('isRead', isEqualTo: false);

    // Use a batched write to update all unread messages and reset the counter
    final writeBatch = _firestore.batch();

    // Reset the unread count for the current user
    final convoDoc = await conversationRef.get();
    if (convoDoc.exists) {
      final conversation = Conversation.fromFirestore(convoDoc);
      final unreadField = currentUserId == conversation.clientId ? 'clientUnreadCount' : 'providerUnreadCount';
      writeBatch.update(conversationRef, {unreadField: 0});
    }

    // Mark individual messages as read
    final unreadMessages = await messagesQuery.get();
    for (final doc in unreadMessages.docs) {
      writeBatch.update(doc.reference, {'isRead': true});
    }

    await writeBatch.commit();
  }
}