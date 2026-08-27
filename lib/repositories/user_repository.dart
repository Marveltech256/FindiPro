import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../models/user_model.dart';

class UserRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  Stream<UserModel?> watchUser(String uid) {
    final userUuid = UuidUtils.firebaseUidToUuid(uid);
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userUuid)
        .asyncMap((rows) async {
          if (rows.isEmpty) return null;
          final profileRow = Map<String, dynamic>.from(rows.first);
          final authoritativeRole = (rows.first['role'] ?? '').toString();
          try {
            final prov = await _supabase
                .from('providers')
                .select()
                .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid')
                .maybeSingle();
            if (prov != null) {
              profileRow.addAll(prov);
              // profiles.role is authoritative for any explicit role
              // (admin, etc). Only let a providers row promote the
              // default 'customer' role to 'provider' -- it must never
              // silently overwrite something like 'admin'.
              if (authoritativeRole.isNotEmpty && authoritativeRole != 'customer') {
                profileRow['role'] = authoritativeRole;
              } else {
                profileRow['role'] = 'provider';
              }
            }
          } catch (_) {}
          return UserModel.fromMap(profileRow, uid);
        })
        .handleError((error) {
          debugPrint('>>> [UserRepository.watchUser] Stream error: $error');
          return null;
        });
  }

  Future<UserModel?> getUser(String uid) async {
    final userUuid = UuidUtils.firebaseUidToUuid(uid);
    debugPrint('>>> [UserRepository.getUser] Fetching user UID: $uid (UUID: $userUuid)');

    Map<String, dynamic>? mergedData;

    try {
      final profileRes = await _supabase
          .from('profiles')
          .select()
          .eq('id', userUuid)
          .maybeSingle();

      if (profileRes != null) {
        debugPrint('>>> [UserRepository.getUser] Supabase profiles query SUCCESS: $profileRes');
        mergedData = Map<String, dynamic>.from(profileRes);
      }
    } on PostgrestException catch (e) {
      debugPrint('>>> [UserRepository.getUser] PostgrestException in profiles: code=${e.code}, message=${e.message}');
    } catch (e) {
      debugPrint('>>> [UserRepository.getUser] Supabase profiles query error: $e');
    }

    try {
      final providerRes = await _supabase
          .from('providers')
          .select()
          .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid')
          .maybeSingle();

      if (providerRes != null) {
        debugPrint('>>> [UserRepository.getUser] Supabase providers query SUCCESS: $providerRes');
        if (mergedData != null) {
          final authoritativeRole = (mergedData['role'] ?? '').toString();
          mergedData.addAll(providerRes);
          // profiles.role is authoritative for any explicit role (admin,
          // etc). Only let a providers row promote the default
          // 'customer' role to 'provider' -- never silently overwrite
          // something like 'admin'.
          if (authoritativeRole.isNotEmpty && authoritativeRole != 'customer') {
            mergedData['role'] = authoritativeRole;
          } else {
            mergedData['role'] = 'provider';
          }
        } else {
          mergedData = Map<String, dynamic>.from(providerRes);
          mergedData['role'] = 'provider';
        }
      }
    } catch (e) {
      debugPrint('>>> [UserRepository.getUser] Supabase providers query note: $e');
    }

    if (mergedData != null) {
      return UserModel.fromMap(mergedData, uid);
    }

    return null;
  }

  Stream<List<UserModel>> getProvidersStream() {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('role', 'provider')
        .asyncMap((rows) async {
          final List<UserModel> list = [];
          for (final row in rows) {
            final uid = (row['firebase_uid'] ?? row['uid'] ?? row['id'] ?? '').toString();
            final uuid = (row['id'] ?? '').toString();
            final map = Map<String, dynamic>.from(row);
            try {
              final prov = await _supabase
                  .from('providers')
                  .select()
                  .or('id.eq.$uuid,user_id.eq.$uuid,firebase_uid.eq.$uid,uid.eq.$uid')
                  .maybeSingle();
              if (prov != null) {
                map.addAll(prov);
                map['role'] = 'provider';
              }
            } catch (_) {}
            list.add(UserModel.fromMap(map, uid));
          }
          return list;
        })
        .handleError((error) {
          debugPrint('>>> [UserRepository.getProvidersStream] Stream error: $error');
          return <UserModel>[];
        });
  }

  Future<List<UserModel>> getApprovedProviders() async {
    debugPrint('>>> [UserRepository.getApprovedProviders] Fetching approved providers from Supabase...');
    
    // 1. Try querying profiles table for role = 'provider'
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'provider');
      if (res.isNotEmpty) {
        debugPrint('>>> [UserRepository.getApprovedProviders] Found ${res.length} providers in profiles table');
        final List<UserModel> list = [];
        for (final row in (res as List)) {
          final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
          final uuid = (map['id'] ?? '').toString();
          final uid = (map['firebase_uid'] ?? map['uid'] ?? uuid).toString();
          try {
            final prov = await _supabase
                .from('providers')
                .select()
                .or('id.eq.$uuid,user_id.eq.$uuid,firebase_uid.eq.$uid,uid.eq.$uid')
                .maybeSingle();
            if (prov != null) {
              map.addAll(prov);
              map['role'] = 'provider';
            }
          } catch (_) {}
          list.add(UserModel.fromMap(map, uid));
        }
        return list;
      }
    } on PostgrestException catch (e) {
      debugPrint('>>> [UserRepository.getApprovedProviders] PostgrestException in profiles: code=${e.code}, message=${e.message}');
    } catch (e) {
      debugPrint('>>> [UserRepository.getApprovedProviders] Supabase profiles query error: $e');
    }

    // 2. Try querying providers table
    try {
      final res = await _supabase
          .from('providers')
          .select();
      if (res.isNotEmpty) {
        debugPrint('>>> [UserRepository.getApprovedProviders] Found ${res.length} providers in providers table');
        return (res as List).map((row) {
          final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
          map['role'] = 'provider';
          return UserModel.fromMap(map);
        }).toList();
      }
    } on PostgrestException catch (e) {
      debugPrint('>>> [UserRepository.getApprovedProviders] PostgrestException in providers: code=${e.code}, message=${e.message}');
    } catch (e) {
      debugPrint('>>> [UserRepository.getApprovedProviders] Supabase providers query error: $e');
    }

    // 3. Try querying businesses joined/associated
    try {
      final res = await _supabase
          .from('businesses')
          .select();
      if (res.isNotEmpty) {
        debugPrint('>>> [UserRepository.getApprovedProviders] Found ${res.length} businesses in businesses table');
        return (res as List).map((row) {
          final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
          map['role'] = 'provider';
          return UserModel.fromMap(map);
        }).toList();
      }
    } catch (e) {
      debugPrint('>>> [UserRepository.getApprovedProviders] Supabase businesses query error: $e');
    }

    return [];
  }

  Future<void> createClient({
    required String uid,
    required String name,
    required String email,
    required String phone,
    String? photoUrl,
  }) async {
    final userUuid = UuidUtils.firebaseUidToUuid(uid);
    debugPrint('>>> [UserRepository.createClient] Firebase UID: $uid -> UUID: $userUuid');

    final profileData = {
      'id': userUuid,
      'firebase_uid': uid,
      'full_name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'avatar_url': photoUrl,
      'role': 'customer',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    debugPrint('>>> [UserRepository.createClient] Supabase profiles payload: $profileData');

    try {
      final res = await _supabase.from('profiles').upsert(profileData).select();
      debugPrint('>>> [UserRepository.createClient] Supabase profiles upsert SUCCESS: $res');
    } on PostgrestException catch (e) {
      debugPrint('>>> [UserRepository.createClient] PostgrestException: code=${e.code}, message=${e.message}');
    } catch (e) {
      debugPrint('>>> [UserRepository.createClient] General error inserting profile: $e');
    }
  }

  Future<void> createProvider({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String category,
    required String location,
    required int yearsExperience,
    String? about,
    required String bio,
    required List<String> skills,
    required String priceRange,
    required bool available,
    required double? latitude,
    required double? longitude,
    String? photoUrl,
    String? businessName,
  }) async {
    final userUuid = UuidUtils.firebaseUidToUuid(uid);
    debugPrint('>>> [UserRepository.createProvider] Firebase UID: $uid -> UUID: $userUuid, role: provider');

    final profileData = {
      'id': userUuid,
      'firebase_uid': uid,
      'full_name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'avatar_url': photoUrl,
      'role': 'provider',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    debugPrint('>>> [UserRepository.createProvider] Supabase profiles payload: $profileData');

    try {
      final res = await _supabase.from('profiles').upsert(profileData).select();
      debugPrint('>>> [UserRepository.createProvider] Supabase profiles upsert SUCCESS: $res');
    } on PostgrestException catch (e) {
      debugPrint('>>> [UserRepository.createProvider] PostgrestException in profiles: code=${e.code}, message=${e.message}');
    } catch (e) {
      debugPrint('>>> [UserRepository.createProvider] General error inserting profiles: $e');
    }

    final providerData = {
      'id': userUuid,
      'user_id': userUuid,
      'firebase_uid': uid,
      'uid': uid,
      'full_name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': 'provider',
      'category': category,
      'location': location,
      'about': about,
      'years_experience': yearsExperience,
      'bio': bio,
      'skills': skills,
      'price_range': priceRange,
      'available': true,
      'latitude': latitude,
      'longitude': longitude,
      'avatar_url': photoUrl,
      'business_name': businessName,
      'rating': 0,
      'review_count': 0,
      'plan': 'basic',
      'verified': true,
      'premium': false,
      'verification_status': 'none',
      'is_blocked': false,
      'is_admin': false,
      'is_approved': true,
      'images': <String>[],
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final res = await _supabase.from('providers').upsert(providerData).select();
      debugPrint('>>> [UserRepository.createProvider] Supabase providers upsert SUCCESS: $res');
    } catch (e) {
      debugPrint('>>> [UserRepository.createProvider] Supabase providers table upsert error: $e');
    }
  }

  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phone,
    String? location,
    String? avatarUrl,
  }) async {
    final userUuid = UuidUtils.firebaseUidToUuid(uid);
    debugPrint('>>> [UserRepository.updateProfile] UID: $uid, UUID: $userUuid');

    final profilePayload = {
      'full_name': fullName,
      'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    debugPrint('>>> [UserRepository.updateProfile] Updating profiles table with payload: $profilePayload');

    try {
      await _supabase
          .from('profiles')
          .update(profilePayload)
          .eq('id', userUuid);
      debugPrint('>>> [UserRepository.updateProfile] Supabase profiles update SUCCESS');

      if (avatarUrl != null || fullName.isNotEmpty || phone.isNotEmpty) {
        try {
          final providerSyncPayload = {
            'full_name': fullName,
            'phone': phone,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
          await _supabase
              .from('providers')
              .update(providerSyncPayload)
              .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
          debugPrint('>>> [UserRepository.updateProfile] Supabase providers sync SUCCESS');
        } catch (e) {
          debugPrint('>>> [UserRepository.updateProfile] Providers sync note (ok if not a provider): $e');
        }
      }
    } on PostgrestException catch (e) {
      debugPrint('>>> [UserRepository.updateProfile] PostgrestException in profiles: code=${e.code}, message=${e.message}');
      try {
        await _supabase
            .from('profiles')
            .update(profilePayload)
            .eq('id', userUuid);
      } catch (_) {}
    } catch (e) {
      debugPrint('>>> [UserRepository.updateProfile] General error in profiles update: $e');
      rethrow;
    }

    if (location != null && location.isNotEmpty) {
      try {
        await _supabase
            .from('locations')
            .upsert({
              'user_id': userUuid,
              'address': location,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            });
      } catch (_) {}
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final userUuid = UuidUtils.firebaseUidToUuid(uid);
    debugPrint('>>> [UserRepository.updateUser] Updating user data for UID: $uid');

    // Extract only valid profile fields
    final profilePayload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (data.containsKey('name')) profilePayload['full_name'] = data['name'];
    if (data.containsKey('full_name')) profilePayload['full_name'] = data['full_name'];
    if (data.containsKey('display_name')) profilePayload['full_name'] = data['display_name'];
    if (data.containsKey('phone')) profilePayload['phone'] = data['phone'];
    if (data.containsKey('email')) profilePayload['email'] = data['email'];
    if (data.containsKey('avatar_url')) profilePayload['avatar_url'] = data['avatar_url'];
    if (data.containsKey('photo_url')) profilePayload['avatar_url'] = data['photo_url'];
    if (data.containsKey('photoUrl')) profilePayload['avatar_url'] = data['photoUrl'];
    if (data.containsKey('role')) profilePayload['role'] = data['role'];

    try {
      await _supabase
          .from('profiles')
          .update(profilePayload)
          .eq('id', userUuid);
      debugPrint('>>> [UserRepository.updateUser] Supabase profiles update SUCCESS');
    } on PostgrestException catch (e) {
      debugPrint('>>> [UserRepository.updateUser] PostgrestException in profiles: code=${e.code}, message=${e.message}');
    } catch (e) {
      debugPrint('>>> [UserRepository.updateUser] Supabase profiles update error: $e');
    }

    try {
      await _supabase
          .from('providers')
          .update(data)
          .eq('id', userUuid);
    } catch (_) {}
  }

  Future<void> addPortfolioImage(String uid, String imageUrl) async {
    try {
      final user = await getUser(uid);
      if (user != null) {
        final updatedImages = [...user.images, imageUrl];
        await updateUser(uid, {'images': updatedImages, 'portfolio_images': updatedImages});
      }
    } catch (e) {
      debugPrint('Supabase addPortfolioImage error: $e');
    }
  }

  Future<void> removePortfolioImage(String uid, String imageUrl) async {
    try {
      final user = await getUser(uid);
      if (user != null) {
        final updatedImages = user.images.where((img) => img != imageUrl).toList();
        await updateUser(uid, {'images': updatedImages, 'portfolio_images': updatedImages});
      }
    } catch (e) {
      debugPrint('Supabase removePortfolioImage error: $e');
    }
  }

  /// Deactivates or anonymizes a user account safely according to Supabase foreign-key architecture.
  Future<void> deactivateOrDeleteAccount(String uid) async {
    final userUuid = UuidUtils.isValidUuid(uid) ? uid : UuidUtils.firebaseUidToUuid(uid);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    debugPrint('>>> [UserRepository.deactivateOrDeleteAccount] Deactivating user $uid ($userUuid)');

    // 1. Anonymize/deactivate profiles row
    try {
      final anonymizedProfile = {
        'full_name': 'Deleted User',
        'phone': '',
        'avatar_url': null,
        'role': 'deleted',
        'updated_at': nowIso,
      };
      await _supabase.from('profiles').update(anonymizedProfile).eq('id', userUuid);
      debugPrint('>>> [UserRepository.deactivateOrDeleteAccount] profiles deactivation SUCCESS');
    } catch (e) {
      debugPrint('>>> [UserRepository.deactivateOrDeleteAccount] profiles deactivation note: $e');
    }

    // 2. Deactivate provider record if exists
    try {
      final deactivatedProvider = {
        'available': false,
        'is_approved': false,
        'is_blocked': true,
        'business_name': 'Closed Provider',
        'about': null,
        'bio': null,
        'skills': <String>[],
        'images': <String>[],
        'portfolio_images': <String>[],
        'updated_at': nowIso,
      };
      await _supabase
          .from('providers')
          .update(deactivatedProvider)
          .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
      debugPrint('>>> [UserRepository.deactivateOrDeleteAccount] providers deactivation SUCCESS');
    } catch (e) {
      debugPrint('>>> [UserRepository.deactivateOrDeleteAccount] providers deactivation note: $e');
    }

    // 3. Remove location entry
    try {
      await _supabase.from('locations').delete().eq('user_id', userUuid);
      debugPrint('>>> [UserRepository.deactivateOrDeleteAccount] locations removal SUCCESS');
    } catch (_) {}
  }

  /// Updates a provider's complete business profile across `profiles`, `providers`, and `locations`.
  Future<void> updateProviderBusinessProfile({
    required String uid,
    required String fullName,
    required String phone,
    String? email,
    String? businessName,
    String? category,
    String? location,
    double? latitude,
    double? longitude,
    String? about,
    String? bio,
    List<String>? skills,
    int? yearsExperience,
    String? priceRange,
    bool? available,
    String? avatarUrl,
  }) async {
    final userUuid = UuidUtils.isValidUuid(uid) ? uid : UuidUtils.firebaseUidToUuid(uid);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    debugPrint('>>> [UserRepository.updateProviderBusinessProfile] Updating provider business profile for $uid ($userUuid)');

    // 1. Sync to public.profiles
    final profilePayload = <String, dynamic>{
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      if (email != null && email.isNotEmpty) 'email': email.trim(),
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'updated_at': nowIso,
    };
    try {
      await _supabase.from('profiles').update(profilePayload).eq('id', userUuid);
      debugPrint('>>> [UserRepository.updateProviderBusinessProfile] profiles update SUCCESS');
    } catch (e) {
      debugPrint('>>> [UserRepository.updateProviderBusinessProfile] profiles update note: $e');
    }

    // 2. Sync to public.providers
    final providerPayload = <String, dynamic>{
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      if (email != null && email.isNotEmpty) 'email': email.trim(),
      if (businessName != null) 'business_name': businessName.trim(),
      if (category != null) 'category': category.trim(),
      if (location != null) 'location': location.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (about != null) 'about': about.trim(),
      if (bio != null) 'bio': bio.trim(),
      if (skills != null) 'skills': skills,
      if (yearsExperience != null) 'years_experience': yearsExperience,
      if (priceRange != null) 'price_range': priceRange.trim(),
      if (available != null) 'available': available,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'updated_at': nowIso,
    };
    try {
      await _supabase
          .from('providers')
          .update(providerPayload)
          .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
      debugPrint('>>> [UserRepository.updateProviderBusinessProfile] providers update SUCCESS');
    } catch (e) {
      debugPrint('>>> [UserRepository.updateProviderBusinessProfile] providers update note: $e');
    }

    // 3. Sync to public.locations
    if (location != null && location.isNotEmpty) {
      final locPayload = <String, dynamic>{
        'user_id': userUuid,
        'address': location.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'updated_at': nowIso,
      };
      try {
        await _supabase.from('locations').upsert(locPayload);
        debugPrint('>>> [UserRepository.updateProviderBusinessProfile] locations upsert SUCCESS');
      } catch (e) {
        debugPrint('>>> [UserRepository.updateProviderBusinessProfile] locations upsert note: $e');
      }
    }
  }
}