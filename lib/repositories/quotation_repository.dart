import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../models/quotation_model.dart';
import '../repositories/message_repository.dart';
import '../repositories/notification_repository.dart';
import '../services/push_notification_service.dart';

/// Repository handling Quotation Requests, In-App Invoices, and Instant Notifications.
class QuotationRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;
  final NotificationRepository _notifRepo = NotificationRepository();
  final MessageRepository _msgRepo = MessageRepository();

  /// Generates a standardized professional quotation / invoice number.
  String generateQuotationNumber({bool isInvoice = false}) {
    final year = DateTime.now().year;
    final randomDigits = (1000 + Random().nextInt(9000)).toString();
    final prefix = isInvoice ? 'INV' : 'QT';
    return '$prefix-$year-$randomDigits';
  }

  /// Client requests a formal quotation from a service provider.
  Future<QuotationModel> requestQuotation({
    required String clientId,
    required String clientName,
    String? clientPhone,
    String? clientAddress,
    required String providerId,
    required String providerName,
    String? providerPhone,
    String? providerEmail,
    String? providerAddress,
    String? providerLogoUrl,
    String? conversationId,
    String? bookingId,
    required String title,
    required String description,
    String currency = 'UGX',
    DateTime? preferredDate,
  }) async {
    final clientUuid = UuidUtils.firebaseUidToUuid(clientId);
    final providerUuid = UuidUtils.firebaseUidToUuid(providerId);
    final quotationNumber = generateQuotationNumber(isInvoice: false);
    final now = DateTime.now().toUtc();

    final data = {
      'quotation_number': quotationNumber,
      'client_id': clientUuid,
      'client_name': clientName,
      'client_phone': clientPhone,
      'client_address': clientAddress,
      'provider_id': providerUuid,
      'provider_name': providerName,
      'provider_phone': providerPhone,
      'provider_email': providerEmail,
      'provider_address': providerAddress,
      'provider_logo_url': providerLogoUrl,
      'conversation_id': conversationId,
      'booking_id': (bookingId != null && UuidUtils.isValidUuid(bookingId)) ? bookingId : null,
      'title': title,
      'description': description,
      'status': 'requested',
      'currency': currency,
      'items': [],
      'subtotal': 0.0,
      'tax': 0.0,
      'discount': 0.0,
      'total_amount': 0.0,
      'valid_until': preferredDate?.toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    debugPrint('>>> [QuotationRepository.requestQuotation] Inserting quotation request: $data');

    final insertRes = await _supabase.from('quotations').insert(data).select().single();
    final createdQuotation = QuotationModel.fromMap(insertRes);

    // 1. Dispatch Instant Push Notification to Service Provider
    try {
      await PushNotificationService().sendPushNotificationToUser(
        recipientUserId: providerId,
        senderUserId: clientId,
        senderName: clientName,
        title: 'New Quotation Request',
        body: '$clientName requested a quotation for "$title"',
        type: 'quotation_request',
        conversationId: conversationId,
        extraData: {
          'quotation_id': createdQuotation.id,
          'quotation_number': quotationNumber,
        },
      );
    } catch (e) {
      debugPrint('>>> [QuotationRepository.requestQuotation] Push notification note: $e');
    }

    // 2. Save in-app notification record
    try {
      await _notifRepo.createNotification(
        userId: providerId,
        title: 'New Quotation Request',
        body: '$clientName requested a formal quotation for "$title"',
        type: 'quotation_request',
        data: {
          'quotation_id': createdQuotation.id,
          'quotation_number': quotationNumber,
          'client_id': clientId,
        },
      );
    } catch (_) {}

    // 3. Post a message to the direct chat thread so it appears in the conversation
    try {
      await _msgRepo.sendMessage(
        senderId: clientId,
        receiverId: providerId,
        text: '📋 [Quotation Request: $quotationNumber]\nTitle: $title\nScope: $description',
        conversationId: conversationId,
        bookingId: bookingId,
      );
    } catch (e) {
      debugPrint('>>> [QuotationRepository.requestQuotation] Chat message note: $e');
    }

    return createdQuotation;
  }

  /// Service provider sends the formal Quotation / In-App Invoice to the client.
  Future<QuotationModel> sendQuotation({
    required String quotationId,
    required String providerId,
    required String providerName,
    String? providerPhone,
    String? providerEmail,
    String? providerAddress,
    String? providerLogoUrl,
    required String clientId,
    required String clientName,
    required String title,
    required String description,
    required String currency,
    required List<QuotationItem> items,
    required double subtotal,
    double tax = 0.0,
    double discount = 0.0,
    required double totalAmount,
    String? notes,
    String? attachmentUrl,
    bool isUploadedDocument = false,
    DateTime? validUntil,
    String? conversationId,
    String? bookingId,
  }) async {
    final now = DateTime.now().toUtc();
    final itemsJson = items.map((i) => i.toMap()).toList();

    final updatePayload = {
      'provider_name': providerName,
      if (providerPhone != null) 'provider_phone': providerPhone,
      if (providerEmail != null) 'provider_email': providerEmail,
      if (providerAddress != null) 'provider_address': providerAddress,
      if (providerLogoUrl != null) 'provider_logo_url': providerLogoUrl,
      'title': title,
      'description': description,
      'status': 'sent',
      'currency': currency,
      'items': itemsJson,
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total_amount': totalAmount,
      'notes': notes,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      'is_uploaded_document': isUploadedDocument,
      if (validUntil != null) 'valid_until': validUntil.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    debugPrint('>>> [QuotationRepository.sendQuotation] Updating quotation ($quotationId): $updatePayload');

    final updatedRes = await _supabase
        .from('quotations')
        .update(updatePayload)
        .eq('id', quotationId)
        .select()
        .single();

    final updatedQuotation = QuotationModel.fromMap(updatedRes);

    // 1. Dispatch Instant Push Notification to Client
    try {
      await PushNotificationService().sendPushNotificationToUser(
        recipientUserId: clientId,
        senderUserId: providerId,
        senderName: providerName,
        title: 'Official Quotation / Invoice',
        body: '$providerName sent you a quotation for "$title" (${updatedQuotation.formattedTotal})',
        type: 'quotation_received',
        conversationId: conversationId,
        extraData: {
          'quotation_id': updatedQuotation.id,
          'quotation_number': updatedQuotation.quotationNumber,
          'total': updatedQuotation.formattedTotal,
        },
      );
    } catch (e) {
      debugPrint('>>> [QuotationRepository.sendQuotation] Push notification note: $e');
    }

    // 2. Save in-app notification
    try {
      await _notifRepo.createNotification(
        userId: clientId,
        title: 'Official Quotation / Invoice',
        body: '$providerName sent you a quotation for "$title" (${updatedQuotation.formattedTotal})',
        type: 'quotation_received',
        data: {
          'quotation_id': updatedQuotation.id,
          'quotation_number': updatedQuotation.quotationNumber,
          'provider_id': providerId,
        },
      );
    } catch (_) {}

    // 3. Post notification card in Chat thread
    try {
      final docNote = isUploadedDocument ? ' (Attached Document)' : '';
      await _msgRepo.sendMessage(
        senderId: providerId,
        receiverId: clientId,
        text: '🧾 [Official Quotation: ${updatedQuotation.quotationNumber}]$docNote\nTotal: ${updatedQuotation.formattedTotal}\nTap to view full itemized breakdown.',
        conversationId: conversationId,
        bookingId: bookingId,
      );
    } catch (e) {
      debugPrint('>>> [QuotationRepository.sendQuotation] Chat message note: $e');
    }

    return updatedQuotation;
  }

  /// Client accepts the quotation.
  Future<void> acceptQuotation({
    required QuotationModel quotation,
    required String currentUserId,
  }) async {
    final now = DateTime.now().toUtc();
    await _supabase
        .from('quotations')
        .update({
          'status': 'accepted',
          'updated_at': now.toIso8601String(),
        })
        .eq('id', quotation.id);

    // Notify the provider immediately
    try {
      await PushNotificationService().sendPushNotificationToUser(
        recipientUserId: quotation.providerId,
        senderUserId: currentUserId,
        senderName: quotation.clientName,
        title: 'Quotation Accepted! 🎉',
        body: '${quotation.clientName} accepted quotation ${quotation.quotationNumber} (${quotation.formattedTotal})',
        type: 'quotation_accepted',
        conversationId: quotation.conversationId,
        extraData: {
          'quotation_id': quotation.id,
          'quotation_number': quotation.quotationNumber,
        },
      );
    } catch (_) {}

    // Post to chat thread
    try {
      await _msgRepo.sendMessage(
        senderId: currentUserId,
        receiverId: quotation.providerId,
        text: '✅ [Quotation Accepted]\nClient accepted quotation ${quotation.quotationNumber} (${quotation.formattedTotal}). Ready to proceed!',
        conversationId: quotation.conversationId,
        bookingId: quotation.bookingId,
      );
    } catch (_) {}
  }

  /// Client rejects the quotation.
  Future<void> rejectQuotation({
    required QuotationModel quotation,
    required String currentUserId,
    String? reason,
  }) async {
    final now = DateTime.now().toUtc();
    await _supabase
        .from('quotations')
        .update({
          'status': 'rejected',
          'updated_at': now.toIso8601String(),
        })
        .eq('id', quotation.id);

    // Notify provider
    try {
      await PushNotificationService().sendPushNotificationToUser(
        recipientUserId: quotation.providerId,
        senderUserId: currentUserId,
        senderName: quotation.clientName,
        title: 'Quotation Declined',
        body: '${quotation.clientName} declined quotation ${quotation.quotationNumber}',
        type: 'quotation_rejected',
        conversationId: quotation.conversationId,
      );
    } catch (_) {}

    try {
      final reasonText = (reason != null && reason.trim().isNotEmpty) ? '\nReason: $reason' : '';
      await _msgRepo.sendMessage(
        senderId: currentUserId,
        receiverId: quotation.providerId,
        text: '❌ [Quotation Declined]\nClient declined quotation ${quotation.quotationNumber}.$reasonText',
        conversationId: quotation.conversationId,
        bookingId: quotation.bookingId,
      );
    } catch (_) {}
  }

  /// Uploads a quotation document or scanned invoice directly to Supabase storage.
  Future<String?> uploadQuotationDocument(File file, {required String quotationId}) async {
    try {
      final fileName = 'quote_${quotationId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'quotations/$fileName';

      final bytes = await file.readAsBytes();
      await _supabase.storage.from('quotations').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final publicUrl = _supabase.storage.from('quotations').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('>>> [QuotationRepository.uploadQuotationDocument] Storage error: $e');
      return null;
    }
  }

  /// Stream of all quotations involving the current user.
  Stream<List<QuotationModel>> streamQuotationsForUser(String userId) {
    final userUuid = UuidUtils.firebaseUidToUuid(userId);

    return _supabase
        .from('quotations')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) {
          return rows
              .where((r) {
                final c = (r['client_id'] ?? '').toString();
                final p = (r['provider_id'] ?? '').toString();
                return c == userId || c == userUuid || p == userId || p == userUuid;
              })
              .map((r) => QuotationModel.fromMap(r))
              .toList();
        })
        .handleError((error) {
          debugPrint('>>> [QuotationRepository.streamQuotationsForUser] Stream error: $error');
          return <QuotationModel>[];
        });
  }

  /// Fetches a single quotation by ID.
  Future<QuotationModel?> getQuotationById(String quotationId) async {
    try {
      final res = await _supabase
          .from('quotations')
          .select()
          .eq('id', quotationId)
          .maybeSingle();

      if (res == null) return null;
      return QuotationModel.fromMap(res);
    } catch (e) {
      debugPrint('>>> [QuotationRepository.getQuotationById] Error: $e');
      return null;
    }
  }
}
