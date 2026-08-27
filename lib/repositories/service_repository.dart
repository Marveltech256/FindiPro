import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../models/service_model.dart';
import '../models/user_model.dart';

class ServiceRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Fetches services for a given provider.
  /// 1. Tries querying public.services table by provider_id.
  /// 2. If empty, tries querying public.provider_services junction table.
  /// 3. If empty, falls back to generating ServiceModel instances from the provider's skills and category.
  Future<List<ServiceModel>> getProviderServices(UserModel provider) async {
    final providerUuid = UuidUtils.firebaseUidToUuid(provider.uid);
    final List<ServiceModel> services = [];

    // 1. Query public.services table
    try {
      final res = await _supabase
          .from('services')
          .select()
          .or('provider_id.eq.$providerUuid,provider_id.eq.${provider.uid}')
          .eq('is_active', true);

      if (res.isNotEmpty) {
        for (final row in (res as List)) {
          services.add(ServiceModel.fromMap(Map<String, dynamic>.from(row)));
        }
        return services;
      }
    } catch (e) {
      debugPrint('>>> [ServiceRepository.getProviderServices] services table note: $e');
    }

    // 2. Query public.provider_services junction table
    try {
      final res = await _supabase
          .from('provider_services')
          .select('*, services(*)')
          .or('provider_id.eq.$providerUuid,provider_id.eq.${provider.uid}');

      if (res.isNotEmpty) {
        for (final row in (res as List)) {
          final map = Map<String, dynamic>.from(row);
          if (map['services'] != null && map['services'] is Map) {
            final joined = Map<String, dynamic>.from(map['services'] as Map);
            joined['price'] = map['price'] ?? joined['price'];
            joined['currency'] = map['currency'] ?? joined['currency'] ?? 'UGX';
            joined['is_active'] = map['is_active'] ?? joined['is_active'] ?? true;
            services.add(ServiceModel.fromMap(joined));
          } else {
            services.add(ServiceModel.fromMap(map));
          }
        }
        if (services.isNotEmpty) {
          return services;
        }
      }
    } catch (e) {
      debugPrint('>>> [ServiceRepository.getProviderServices] provider_services table note: $e');
    }

    // 3. Fallback: Derive services from provider's skills and category in profile
    if (services.isEmpty) {
      final currency = provider.subscriptionCurrency ?? 'UGX';

      // Parse first numeric price if available in priceRange
      double? parsedPrice;
      if (provider.priceRange.isNotEmpty) {
        final cleanRange = provider.priceRange.replaceAll(',', '');
        final firstMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleanRange);
        if (firstMatch != null) {
          parsedPrice = double.tryParse(firstMatch.group(1)!);
        }
      }

      if (provider.skills.isNotEmpty) {
        for (int i = 0; i < provider.skills.length; i++) {
          final skillName = provider.skills[i].trim();
          if (skillName.isNotEmpty) {
            services.add(
              ServiceModel(
                id: 'skill_${provider.uid}_$i',
                providerId: provider.uid,
                name: skillName,
                description: provider.about?.isNotEmpty == true ? provider.about : provider.bio,
                price: parsedPrice,
                currency: currency,
                duration: '1-3 hours',
                category: provider.category ?? 'General Service',
                isActive: provider.available,
              ),
            );
          }
        }
      } else if (provider.category != null && provider.category!.trim().isNotEmpty) {
        services.add(
          ServiceModel(
            id: 'cat_${provider.uid}',
            providerId: provider.uid,
            name: '${provider.category} Service',
            description: provider.about?.isNotEmpty == true ? provider.about : provider.bio,
            price: parsedPrice,
            currency: currency,
            duration: '1-3 hours',
            category: provider.category,
            isActive: provider.available,
          ),
        );
      }
    }

    return services;
  }

  /// Adds a new service for the provider.
  Future<ServiceModel?> addService(ServiceModel service) async {
    final providerUuid = UuidUtils.isValidUuid(service.providerId)
        ? service.providerId
        : UuidUtils.firebaseUidToUuid(service.providerId);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final payload = {
      'provider_id': providerUuid,
      'name': service.name.trim(),
      'description': service.description?.trim(),
      'price': service.price,
      'currency': service.currency,
      'duration': service.duration?.trim(),
      'category': service.category?.trim(),
      'is_active': service.isActive,
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    try {
      final res = await _supabase.from('services').insert(payload).select().maybeSingle();
      if (res != null) {
        final created = ServiceModel.fromMap(res);
        await _syncServiceToProviderSkills(service.providerId, service.name, isAdd: true);
        return created;
      }
    } catch (e) {
      debugPrint('>>> [ServiceRepository.addService] services insert note: $e');
    }

    // Try provider_services table
    try {
      final res = await _supabase.from('provider_services').insert(payload).select().maybeSingle();
      if (res != null) {
        final created = ServiceModel.fromMap(res);
        await _syncServiceToProviderSkills(service.providerId, service.name, isAdd: true);
        return created;
      }
    } catch (e) {
      debugPrint('>>> [ServiceRepository.addService] provider_services insert note: $e');
    }

    // Fallback sync to provider skills
    await _syncServiceToProviderSkills(service.providerId, service.name, isAdd: true);
    return service;
  }

  /// Updates an existing service.
  Future<bool> updateService(ServiceModel service) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final payload = {
      'name': service.name.trim(),
      'description': service.description?.trim(),
      'price': service.price,
      'currency': service.currency,
      'duration': service.duration?.trim(),
      'category': service.category?.trim(),
      'is_active': service.isActive,
      'updated_at': nowIso,
    };

    bool updated = false;
    try {
      await _supabase.from('services').update(payload).eq('id', service.id);
      updated = true;
    } catch (e) {
      debugPrint('>>> [ServiceRepository.updateService] services update note: $e');
    }

    try {
      await _supabase.from('provider_services').update(payload).eq('id', service.id);
      updated = true;
    } catch (_) {}

    return updated;
  }

  /// Deletes a service.
  Future<bool> deleteService(String serviceId, String providerId, {String? serviceName}) async {
    bool deleted = false;
    try {
      await _supabase.from('services').delete().eq('id', serviceId);
      deleted = true;
    } catch (e) {
      debugPrint('>>> [ServiceRepository.deleteService] services delete note: $e');
    }

    try {
      await _supabase.from('provider_services').delete().eq('id', serviceId);
      deleted = true;
    } catch (_) {}

    if (serviceName != null && serviceName.isNotEmpty) {
      await _syncServiceToProviderSkills(providerId, serviceName, isAdd: false);
    }

    return deleted;
  }

  /// Toggles service active status.
  Future<bool> toggleServiceActive(String serviceId, bool isActive) async {
    try {
      await _supabase.from('services').update({'is_active': isActive}).eq('id', serviceId);
      return true;
    } catch (e) {
      debugPrint('>>> [ServiceRepository.toggleServiceActive] error: $e');
      return false;
    }
  }

  /// Synchronizes skills array in the providers table.
  Future<void> _syncServiceToProviderSkills(String providerId, String serviceName, {required bool isAdd}) async {
    final providerUuid = UuidUtils.isValidUuid(providerId) ? providerId : UuidUtils.firebaseUidToUuid(providerId);
    try {
      final prov = await _supabase.from('providers').select('skills').or('id.eq.$providerUuid,firebase_uid.eq.$providerId').maybeSingle();
      if (prov != null) {
        final List<String> currentSkills = List<String>.from((prov['skills'] as List?) ?? []);
        if (isAdd) {
          if (!currentSkills.contains(serviceName)) {
            currentSkills.add(serviceName);
          }
        } else {
          currentSkills.remove(serviceName);
        }
        await _supabase.from('providers').update({'skills': currentSkills}).or('id.eq.$providerUuid,firebase_uid.eq.$providerId');
      }
    } catch (_) {}
  }
}
