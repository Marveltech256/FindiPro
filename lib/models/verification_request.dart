class VerificationRequest {
  final String id;
  final String providerId;
  final String providerName;
  final String? nationalIdNumber;
  final String? idFrontUrl;
  final String? idBackUrl;
  final String? businessDocUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final String? notes; // rejection feedback or admin notes
  final DateTime createdAt;
  final DateTime? updatedAt;

  VerificationRequest({
    required this.id,
    required this.providerId,
    required this.providerName,
    this.nationalIdNumber,
    this.idFrontUrl,
    this.idBackUrl,
    this.businessDocUrl,
    required this.status,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory VerificationRequest.fromMap(Map<String, dynamic> data, [String? fallbackId]) {
    DateTime parseDate(dynamic d) {
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return VerificationRequest(
      id: (data['id'] ?? fallbackId ?? '').toString(),
      providerId: (data['provider_id'] ?? data['providerId'] ?? '').toString(),
      providerName: (data['provider_name'] ?? data['providerName'] ?? '').toString(),
      nationalIdNumber: data['national_id_number'] ?? data['nationalIdNumber'] ?? data['id_number'],
      idFrontUrl: data['id_front_url'] ?? data['idFrontUrl'],
      idBackUrl: data['id_back_url'] ?? data['idBackUrl'],
      businessDocUrl: data['business_doc_url'] ?? data['businessDocUrl'],
      status: (data['status'] ?? 'pending').toString().toLowerCase(),
      notes: data['notes'] ?? data['rejection_reason'] ?? data['reason'],
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
      updatedAt: parseNullableDate(data['updated_at'] ?? data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider_id': providerId,
      'provider_name': providerName,
      if (nationalIdNumber != null) 'national_id_number': nationalIdNumber,
      if (idFrontUrl != null) 'id_front_url': idFrontUrl,
      if (idBackUrl != null) 'id_back_url': idBackUrl,
      if (businessDocUrl != null) 'business_doc_url': businessDocUrl,
      'status': status,
      if (notes != null) 'notes': notes,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}