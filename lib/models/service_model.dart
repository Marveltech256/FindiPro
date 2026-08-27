/// Represents a service offered by a provider in FindiPro.
class ServiceModel {
  final String id;
  final String providerId;
  final String name;
  final String? description;
  final double? price;
  final String currency;
  final String? duration;
  final String? category;
  final bool isActive;

  const ServiceModel({
    required this.id,
    required this.providerId,
    required this.name,
    this.description,
    this.price,
    this.currency = 'UGX',
    this.duration,
    this.category,
    this.isActive = true,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> data, [String? fallbackId]) {
    double? parsePrice(dynamic p) {
      if (p == null) return null;
      if (p is num) return p.toDouble();
      if (p is String) {
        final cleaned = p.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.tryParse(cleaned);
      }
      return null;
    }

    final rawActive = data['is_active'] ?? data['isActive'] ?? data['active'] ?? data['available'];
    bool active = true;
    if (rawActive is bool) {
      active = rawActive;
    } else if (rawActive is String) {
      active = rawActive.toLowerCase() != 'false' && rawActive.toLowerCase() != 'inactive';
    }

    return ServiceModel(
      id: (data['id'] ?? fallbackId ?? '').toString(),
      providerId: (data['provider_id'] ?? data['providerId'] ?? data['user_id'] ?? data['userId'] ?? '').toString(),
      name: (data['name'] ?? data['title'] ?? data['service_name'] ?? data['serviceName'] ?? 'Service').toString(),
      description: (data['description'] ?? data['about'] ?? data['bio'])?.toString(),
      price: parsePrice(data['price'] ?? data['amount'] ?? data['rate']),
      currency: (data['currency'] ?? 'UGX').toString(),
      duration: (data['duration'] ?? data['estimated_duration'] ?? data['time_estimate'])?.toString(),
      category: (data['category'] ?? data['category_name'] ?? data['categoryName'])?.toString(),
      isActive: active,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider_id': providerId,
      'name': name,
      if (description != null) 'description': description,
      if (price != null) 'price': price,
      'currency': currency,
      if (duration != null) 'duration': duration,
      if (category != null) 'category': category,
      'is_active': isActive,
    };
  }
}

