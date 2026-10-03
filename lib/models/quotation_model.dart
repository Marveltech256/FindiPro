import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Represents a single itemized line in a quotation or invoice.
class QuotationItem {
  final String description;
  final double quantity;
  final double unitPrice;

  const QuotationItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total': total,
      };

  factory QuotationItem.fromMap(Map<String, dynamic> map) {
    return QuotationItem(
      description: (map['description'] ?? '').toString(),
      quantity: (map['quantity'] is num) ? (map['quantity'] as num).toDouble() : 1.0,
      unitPrice: (map['unit_price'] is num) ? (map['unit_price'] as num).toDouble() : 0.0,
    );
  }
}

/// Complete Quotation and In-App Invoice Model.
class QuotationModel {
  final String id;
  final String quotationNumber;
  final String clientId;
  final String clientName;
  final String? clientPhone;
  final String? clientAddress;
  final String providerId;
  final String providerName;
  final String? providerPhone;
  final String? providerEmail;
  final String? providerAddress;
  final String? providerLogoUrl;
  final String? conversationId;
  final String? bookingId;
  final String title;
  final String description;
  final String status; // 'requested', 'sent', 'accepted', 'rejected', 'expired'
  final String currency;
  final List<QuotationItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double totalAmount;
  final String? notes;
  final String? attachmentUrl;
  final bool isUploadedDocument;
  final DateTime? validUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuotationModel({
    required this.id,
    required this.quotationNumber,
    required this.clientId,
    required this.clientName,
    this.clientPhone,
    this.clientAddress,
    required this.providerId,
    required this.providerName,
    this.providerPhone,
    this.providerEmail,
    this.providerAddress,
    this.providerLogoUrl,
    this.conversationId,
    this.bookingId,
    required this.title,
    required this.description,
    required this.status,
    this.currency = 'UGX',
    this.items = const [],
    this.subtotal = 0.0,
    this.tax = 0.0,
    this.discount = 0.0,
    this.totalAmount = 0.0,
    this.notes,
    this.attachmentUrl,
    this.isUploadedDocument = false,
    this.validUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get formattedTotal {
    final formatter = NumberFormat('#,###', 'en_US');
    return '$currency ${formatter.format(totalAmount)}';
  }

  String get formattedSubtotal {
    final formatter = NumberFormat('#,###', 'en_US');
    return '$currency ${formatter.format(subtotal)}';
  }

  String get formattedDate {
    return DateFormat('MMM dd, yyyy').format(createdAt);
  }

  String? get formattedValidUntil {
    if (validUntil == null) return null;
    return DateFormat('MMM dd, yyyy').format(validUntil!);
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFF10B981); // Emerald green
      case 'sent':
        return const Color(0xFF06B6D4); // Cyan
      case 'requested':
        return const Color(0xFFF59E0B); // Amber
      case 'rejected':
        return const Color(0xFFEF4444); // Red
      case 'expired':
        return const Color(0xFF6B7280); // Gray
      default:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Accepted';
      case 'sent':
        return 'Quotation Ready';
      case 'requested':
        return 'Quote Requested';
      case 'rejected':
        return 'Declined';
      case 'expired':
        return 'Expired';
      default:
        return status.toUpperCase();
    }
  }

  bool get isRequested => status.toLowerCase() == 'requested';
  bool get isSent => status.toLowerCase() == 'sent';
  bool get isAccepted => status.toLowerCase() == 'accepted';
  bool get isRejected => status.toLowerCase() == 'rejected';

  Map<String, dynamic> toMap() => {
        'id': id,
        'quotation_number': quotationNumber,
        'client_id': clientId,
        'client_name': clientName,
        'client_phone': clientPhone,
        'client_address': clientAddress,
        'provider_id': providerId,
        'provider_name': providerName,
        'provider_phone': providerPhone,
        'provider_email': providerEmail,
        'provider_address': providerAddress,
        'provider_logo_url': providerLogoUrl,
        'conversation_id': conversationId,
        'booking_id': bookingId,
        'title': title,
        'description': description,
        'status': status,
        'currency': currency,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'tax': tax,
        'discount': discount,
        'total_amount': totalAmount,
        'notes': notes,
        'attachment_url': attachmentUrl,
        'is_uploaded_document': isUploadedDocument,
        'valid_until': validUntil?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory QuotationModel.fromMap(Map<String, dynamic> map) {
    List<QuotationItem> parsedItems = [];
    if (map['items'] is List) {
      parsedItems = (map['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((i) => QuotationItem.fromMap(i))
          .toList();
    }

    return QuotationModel(
      id: (map['id'] ?? '').toString(),
      quotationNumber: (map['quotation_number'] ?? 'Q-${DateTime.now().millisecondsSinceEpoch % 10000}').toString(),
      clientId: (map['client_id'] ?? '').toString(),
      clientName: (map['client_name'] ?? 'Client').toString(),
      clientPhone: map['client_phone']?.toString(),
      clientAddress: map['client_address']?.toString(),
      providerId: (map['provider_id'] ?? '').toString(),
      providerName: (map['provider_name'] ?? 'Service Provider').toString(),
      providerPhone: map['provider_phone']?.toString(),
      providerEmail: map['provider_email']?.toString(),
      providerAddress: map['provider_address']?.toString(),
      providerLogoUrl: map['provider_logo_url']?.toString(),
      conversationId: map['conversation_id']?.toString(),
      bookingId: map['booking_id']?.toString(),
      title: (map['title'] ?? 'Service Quotation').toString(),
      description: (map['description'] ?? '').toString(),
      status: (map['status'] ?? 'requested').toString(),
      currency: (map['currency'] ?? 'UGX').toString(),
      items: parsedItems,
      subtotal: (map['subtotal'] is num) ? (map['subtotal'] as num).toDouble() : 0.0,
      tax: (map['tax'] is num) ? (map['tax'] as num).toDouble() : 0.0,
      discount: (map['discount'] is num) ? (map['discount'] as num).toDouble() : 0.0,
      totalAmount: (map['total_amount'] is num) ? (map['total_amount'] as num).toDouble() : 0.0,
      notes: map['notes']?.toString(),
      attachmentUrl: map['attachment_url']?.toString(),
      isUploadedDocument: map['is_uploaded_document'] == true,
      validUntil: map['valid_until'] != null ? DateTime.tryParse(map['valid_until'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
