import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../repositories/notification_repository.dart';
import '../repositories/user_repository.dart';

class MessageRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;
  final UserRepository _userRepo = UserRepository();
  final NotificationRepository _notifRepo = NotificationRepository();

  /// Stream all conversations for the given user directly from public.messages.
  Stream<List<Conversation>> getUserConversations(String currentUserId) {
    final currentUuid = UuidUtils.firebaseUidToUuid(currentUserId);

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          final myMessages = rows.where((r) {
            final s = (r['sender_id'] ?? '').toString();
            final rec = (r['receiver_id'] ?? '').toString();
            return s == currentUserId || s == currentUuid || rec == currentUserId || rec == currentUuid;
          }).toList();

          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final msg in myMessages) {
            final s = (msg['sender_id'] ?? '').toString();
            final rec = (msg['receiver_id'] ?? '').toString();
            final otherId = (s == currentUserId || s == currentUuid) ? rec : s;
            if (otherId.isEmpty) continue;
            grouped.putIfAbsent(otherId, () => []).add(msg);
          }

          final List<Conversation> conversations = [];
          for (final entry in grouped.entries) {
            final otherId = entry.key;
            final msgs = entry.value;

            msgs.sort((a, b) {
              final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
              final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
              return db.compareTo(da);
            });

            final latest = msgs.first;
            final unreadCount = msgs.where((m) {
              final rec = (m['receiver_id'] ?? '').toString();
              final isReceiver = rec == currentUserId || rec == currentUuid;
              final isUnread = m['read_at'] == null && m['is_read'] != true;
              return isReceiver && isUnread;
            }).length;

            final otherUser = await _userRepo.getUser(otherId);

            final conv = Conversation(
              id: '${currentUuid}_$otherId',
              bookingId: (latest['booking_id'] ?? '').toString(),
              clientId: currentUserId,
              providerId: otherId,
              participants: [currentUserId, otherId],
              lastMessage: (latest['message'] ?? latest['text'] ?? '').toString(),
              lastMessageSenderId: (latest['sender_id'] ?? '').toString(),
              lastMessageAt: DateTime.tryParse(latest['created_at']?.toString() ?? '') ?? DateTime.now(),
              clientUnreadCount: unreadCount,
              providerUnreadCount: 0,
              isBlocked: false,
              createdAt: DateTime.tryParse(latest['created_at']?.toString() ?? '') ?? DateTime.now(),
            );
            conv.otherParticipantName = otherUser?.name ?? 'User';
            conv.otherParticipantPhotoUrl = otherUser?.photoUrl ?? '';
            conversations.add(conv);
          }

          conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
          return conversations;
        })
        .handleError((error) {
          debugPrint('>>> [MessageRepository.getUserConversations] Error: $error');
          return <Conversation>[];
        });
  }

  /// Realtime stream of messages between two users using Supabase public.messages.
  Stream<List<ChatMessage>> getMessages({
    required String currentUserId,
    required String otherUserId,
    String? conversationId,
  }) {
    final currentUuid = UuidUtils.firebaseUidToUuid(currentUserId);
    final otherUuid = UuidUtils.firebaseUidToUuid(otherUserId);

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) {
          final Set<String> seenIds = {};
          final List<ChatMessage> list = [];

          for (final r in rows) {
            final s = (r['sender_id'] ?? '').toString();
            final rec = (r['receiver_id'] ?? '').toString();

            final isMeToOther = (s == currentUserId || s == currentUuid) &&
                (rec == otherUserId || rec == otherUuid);
            final isOtherToMe = (s == otherUserId || s == otherUuid) &&
                (rec == currentUserId || rec == currentUuid);

            if (isMeToOther || isOtherToMe) {
              final msg = ChatMessage.fromMap(r);
              if (!seenIds.contains(msg.id)) {
                seenIds.add(msg.id);
                list.add(msg);
              }
            }
          }

          return list;
        })
        .handleError((error) {
          debugPrint('>>> [MessageRepository.getMessages] Stream error: $error');
          return <ChatMessage>[];
        });
  }

  /// Send a message into public.messages in Supabase and notify recipient (Phase 33).
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? conversationId,
    String? bookingId,
    String? jobId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final senderUuid = UuidUtils.firebaseUidToUuid(senderId);
    final receiverUuid = UuidUtils.firebaseUidToUuid(receiverId);

    // Self-message protection: sender cannot message themselves
    if (senderUuid == receiverUuid ||
        senderId == receiverId ||
        senderUuid == receiverId ||
        senderId == receiverUuid) {
      throw Exception('You cannot message yourself.');
    }

    final messageData = <String, dynamic>{
      'sender_id': senderUuid,
      'receiver_id': receiverUuid,
      'message': trimmed,
      if (bookingId != null && bookingId.isNotEmpty && UuidUtils.isValidUuid(bookingId))
        'booking_id': bookingId,
      if (jobId != null && jobId.isNotEmpty && UuidUtils.isValidUuid(jobId))
        'job_id': jobId,
    };

    debugPrint('[FindiPro Chat] sender=$senderUuid receiver=$receiverUuid');
    debugPrint('[FindiPro Chat] inserting: $messageData');

    String? messageId;
    try {
      final insertRes = await _supabase.from('messages').insert(messageData).select();
      if (insertRes.isNotEmpty) {
        messageId = insertRes.first['id']?.toString();
      }
      debugPrint('[FindiPro Chat] Message inserted successfully. ID: $messageId');
    } on PostgrestException catch (e, st) {
      debugPrint('[FindiPro Chat] Supabase insert failed: code=${e.code}, message=${e.message}');
      debugPrintStack(stackTrace: st);
      rethrow;
    } catch (e, st) {
      debugPrint('[FindiPro Chat] Message insert failed: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }

    // Send notification to recipient (Phase 33)
    try {
      String senderDisplayName = 'Someone';
      final senderUser = await _userRepo.getUser(senderId);
      if (senderUser != null && senderUser.name.trim().isNotEmpty) {
        senderDisplayName = senderUser.name.trim();
      }

      await _notifRepo.createNotification(
        userId: receiverId,
        title: 'New Message',
        body: 'You have a new message from $senderDisplayName.',
        type: 'message',
        data: {
          if (messageId != null) 'message_id': messageId,
          'sender_id': senderId,
          'receiver_id': receiverId,
          if (bookingId != null) 'booking_id': bookingId,
          if (jobId != null) 'job_id': jobId,
        },
      );
    } catch (e) {
      debugPrint('>>> [MessageRepository.sendMessage] Notification note (non-fatal): $e');
    }
  }

  /// Mark messages as read when the receiver views the chat.
  Future<void> markMessagesAsRead({
    required String currentUserId,
    required String otherUserId,
    String? conversationId,
  }) async {
    final currentUuid = UuidUtils.firebaseUidToUuid(currentUserId);
    final otherUuid = UuidUtils.firebaseUidToUuid(otherUserId);

    try {
      await _supabase
          .from('messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('receiver_id', currentUuid)
          .eq('sender_id', otherUuid)
          .isFilter('read_at', null);
    } catch (e, st) {
      debugPrint('[FindiPro Chat] markMessagesAsRead failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}
