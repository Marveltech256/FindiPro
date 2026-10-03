import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../models/user_model.dart';

class UserRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  // In-memory cache for ultra-fast instant UI rendering (5-min TTL)
  static final Map<String, (UserModel?, DateTime)> _userCache = {};
  static (List<UserModel>, DateTime)? _providersCache;

  static void invalidateCache([String? uid]) {
    if (uid != null) {
      _userCache.remove(uid);
    } else {
      _userCache.clear();
    }
    _providersCache = null;
  }

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
              if (authoritativeRole.isNotEmpty && authoritativeRole != 'customer') {
                profileRow['role'] = authoritativeRole;
              } else {
                profileRow['role'] = 'provider';
              }
            }
          } catch (_) {}
          final user = UserModel.fromMap(profileRow, uid);
          _userCache[uid] = (user, DateTime.now());
          return user;
        })
        .handleError((error) {
          debugPrint('>>> [UserRepository.watchUser] Stream error: $error');
          return null;
        });
  }

  Future<UserModel?> getUser(String uid, {bool forceRefresh = false}) async {
    // Check in-memory cache first (5-minute TTL)
    if (!forceRefresh && _userCache.containsKey(uid)) {
      final (cachedUser, cacheTime) = _userCache[uid]!;
      if (DateTime.now().difference(cacheTime).inMinutes < 5) {
        return cachedUser;
      }
    }

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
      } else {
        // Fallback: search by firebase_uid, uid, or current user email
        final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
        final emailFilter = (currentUserEmail != null && currentUserEmail.isNotEmpty)
            ? ',email.eq.$currentUserEmail'
            : '';
        final fallbackRes = await _supabase
            .from('profiles')
            .select()
            .or('id.eq.$userUuid,id.eq.$uid,firebase_uid.eq.$uid,uid.eq.$uid$emailFilter')
            .maybeSingle();
        if (fallbackRes != null) {
          debugPrint('>>> [UserRepository.getUser] Supabase profiles fallback query SUCCESS: $fallbackRes');
          mergedData = Map<String, dynamic>.from(fallbackRes);
        }
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
      final user = UserModel.fromMap(mergedData, uid);
      _userCache[uid] = (user, DateTime.now());
      return user;
    }

    _userCache[uid] = (null, DateTime.now());
    return null;
  }

  Stream<List<UserModel>> getProvidersStream() async* {
    // 1. Immediately yield approved providers from REST query for instant display
    try {
      final initial = await getApprovedProviders();
      if (initial.isNotEmpty) {
        yield initial;
      }
    } catch (e) {
      debugPrint('>>> [UserRepository.getProvidersStream] Initial REST query note: $e');
    }

    // 2. Stream realtime updates from Supabase
    try {
      yield* _supabase
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
            if (list.isNotEmpty) {
              return list;
            }
            return await getApprovedProviders();
          })
          .handleError((error) async {
            debugPrint('>>> [UserRepository.getProvidersStream] Stream error fallback: $error');
            return await getApprovedProviders();
          });
    } catch (e) {
      debugPrint('>>> [UserRepository.getProvidersStream] Stream initialization note: $e');
      yield await getApprovedProviders();
    }
  }

  Future<List<UserModel>> getApprovedProviders({bool forceRefresh = false}) async {
    // Check in-memory cache (5-minute TTL)
    if (!forceRefresh && _providersCache != null) {
      final (cachedList, cacheTime) = _providersCache!;
      if (DateTime.now().difference(cacheTime).inMinutes < 5) {
        return cachedList;
      }
    }

    debugPrint('>>> [UserRepository.getApprovedProviders] Fetching approved providers in bulk from Supabase...');
    
    // Bulk fetch providers metadata map first
    final Map<String, Map<String, dynamic>> providerLookup = {};
    try {
      final provRes = await _supabase.from('providers').select();
      for (final p in (provRes as List)) {
        final pMap = Map<String, dynamic>.from(p as Map<String, dynamic>);
        for (final k in ['id', 'user_id', 'firebase_uid', 'uid']) {
          final val = (pMap[k] ?? '').toString();
          if (val.isNotEmpty) providerLookup[val] = pMap;
        }
      }
    } catch (e) {
      debugPrint('>>> [UserRepository.getApprovedProviders] Bulk providers query note: $e');
    }

    // Query profiles table for role = 'provider'
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
          
          // In-memory O(1) join instead of sequential network calls
          final prov = providerLookup[uuid] ?? providerLookup[uid];
          if (prov != null) {
            map.addAll(prov);
            map['role'] = 'provider';
          }
          list.add(UserModel.fromMap(map, uid));
        }
        _providersCache = (list, DateTime.now());
        return list;
      }
    } on PostgrestException catch (e) {
      debugPrint('>>> [UserRepository.getApprovedProviders] PostgrestException in profiles: code=${e.code}, message=${e.message}');
    } catch (e) {
      debugPrint('>>> [UserRepository.getApprovedProviders] Supabase profiles query error: $e');
    }

    // Fallback: Query providers table directly if profiles returned empty
    if (providerLookup.isNotEmpty) {
      final list = providerLookup.values.toSet().map((pMap) {
        final copy = Map<String, dynamic>.from(pMap);
        copy['role'] = 'provider';
        return UserModel.fromMap(copy);
      }).toList();
      _providersCache = (list, DateTime.now());
      return list;
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
      'plan': 'premium',
      'verified': true,
      'is_verified': true,
      'premium': true,
      'is_premium': true,
      'verification_status': 'approved',
      'subscription_status': 'active',
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
      'plan': 'premium',
      'verified': true,
      'is_verified': true,
      'premium': true,
      'is_premium': true,
      'verification_status': 'approved',
      'subscription_status': 'active',
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
    final userUuid = UuidUtils.isValidUuid(uid) ? uid : UuidUtils.firebaseUidToUuid(uid);
    debugPrint('>>> [UserRepository.updateUser] Updating user data for UID: $uid ($userUuid)');

    // Invalidate caches immediately
    _userCache.remove(uid);
    _userCache.remove(userUuid);
    _providersCache = null;

    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Extract only valid profile fields
    final profilePayload = <String, dynamic>{
      'updated_at': nowIso,
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
          .or('id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
      debugPrint('>>> [UserRepository.updateUser] Supabase profiles update SUCCESS');
    } on PostgrestException catch (e) {
      debugPrint('>>> [UserRepository.updateUser] PostgrestException in profiles: code=${e.code}, message=${e.message}');
    } catch (e) {
      debugPrint('>>> [UserRepository.updateUser] Supabase profiles update error: $e');
    }

    // Try updating images on profiles in a safe isolated try-catch
    if (data.containsKey('images') || data.containsKey('portfolio_images')) {
      final imgList = data['portfolio_images'] ?? data['images'];
      try {
        await _supabase.from('profiles').update({'portfolio_images': imgList}).or('id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
      } catch (_) {
        try {
          await _supabase.from('profiles').update({'images': imgList}).or('id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
        } catch (_) {}
      }
    }

    // Update providers table
    try {
      final provData = Map<String, dynamic>.from(data);
      provData['updated_at'] = nowIso;
      await _supabase
          .from('providers')
          .update(provData)
          .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
      debugPrint('>>> [UserRepository.updateUser] Supabase providers update SUCCESS');
    } catch (e) {
      debugPrint('>>> [UserRepository.updateUser] Supabase providers update note: $e');
      if (data.containsKey('images') || data.containsKey('portfolio_images')) {
        final imgList = data['portfolio_images'] ?? data['images'];
        try {
          await _supabase
              .from('providers')
              .update({'portfolio_images': imgList, 'updated_at': nowIso})
              .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
        } catch (_) {
          try {
            await _supabase
                .from('providers')
                .update({'images': imgList, 'updated_at': nowIso})
                .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
          } catch (_) {}
        }
      }
    }
  }

  Future<void> addPortfolioImage(String uid, String imageUrl) async {
    final userUuid = UuidUtils.isValidUuid(uid) ? uid : UuidUtils.firebaseUidToUuid(uid);
    debugPrint('>>> [UserRepository.addPortfolioImage] Adding portfolio image for UID: $uid ($userUuid): $imageUrl');

    // 1. Fetch current image list
    List<String> currentImages = [];
    try {
      final provRes = await _supabase
          .from('providers')
          .select('portfolio_images, images')
          .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid')
          .maybeSingle();
      if (provRes != null) {
        final raw = provRes['portfolio_images'] ?? provRes['images'];
        if (raw is List) {
          currentImages = raw.map((e) => e?.toString().trim() ?? '').where((s) => s.startsWith('http')).toList();
        }
      }
    } catch (e) {
      debugPrint('>>> [UserRepository.addPortfolioImage] providers query note: $e');
    }

    if (currentImages.isEmpty) {
      final user = await getUser(uid, forceRefresh: true);
      if (user != null && user.images.isNotEmpty) {
        currentImages = List<String>.from(user.images);
      }
    }

    if (!currentImages.contains(imageUrl)) {
      currentImages.add(imageUrl);
    }

    bool updated = false;

    // 2. Try updating providers table with portfolio_images
    try {
      final res = await _supabase
          .from('providers')
          .update({
            'portfolio_images': currentImages,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid')
          .select();
      if ((res as List).isNotEmpty) {
        updated = true;
        debugPrint('>>> [UserRepository.addPortfolioImage] providers.portfolio_images updated SUCCESS');
      }
    } catch (e) {
      debugPrint('>>> [UserRepository.addPortfolioImage] providers.portfolio_images update note: $e');
    }

    // 3. Try updating providers table with images column (for schemas using images)
    try {
      final res = await _supabase
          .from('providers')
          .update({
            'images': currentImages,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid')
          .select();
      if ((res as List).isNotEmpty) {
        updated = true;
        debugPrint('>>> [UserRepository.addPortfolioImage] providers.images updated SUCCESS');
      }
    } catch (e) {
      debugPrint('>>> [UserRepository.addPortfolioImage] providers.images update note: $e');
    }

    // 4. If no providers row existed, upsert it now
    if (!updated) {
      try {
        final currentUser = await getUser(uid, forceRefresh: true);
        await _supabase.from('providers').upsert({
          'id': userUuid,
          'user_id': userUuid,
          'firebase_uid': uid,
          'uid': uid,
          'full_name': currentUser?.name ?? '',
          'email': currentUser?.email ?? '',
          'phone': currentUser?.phone ?? '',
          'category': currentUser?.category ?? 'General',
          'role': 'provider',
          'portfolio_images': currentImages,
          'images': currentImages,
          'is_approved': true,
          'available': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).select();
        updated = true;
        debugPrint('>>> [UserRepository.addPortfolioImage] providers row created with portfolio image!');
      } catch (e) {
        debugPrint('>>> [UserRepository.addPortfolioImage] providers upsert note: $e');
      }
    }

    // 5. Also sync to profiles table (best-effort)
    try {
      await _supabase.from('profiles').update({'portfolio_images': currentImages}).or('id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
    } catch (_) {
      try {
        await _supabase.from('profiles').update({'images': currentImages}).or('id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
      } catch (_) {}
    }

    _userCache.remove(uid);
    _userCache.remove(userUuid);
    _providersCache = null;

    if (!updated) {
      throw Exception('Could not update provider portfolio in database. Please check your connection.');
    }
  }

  Future<void> removePortfolioImage(String uid, String imageUrl) async {
    final userUuid = UuidUtils.isValidUuid(uid) ? uid : UuidUtils.firebaseUidToUuid(uid);
    debugPrint('>>> [UserRepository.removePortfolioImage] Removing portfolio image for UID: $uid ($userUuid): $imageUrl');

    List<String> currentImages = [];
    try {
      final provRes = await _supabase
          .from('providers')
          .select('portfolio_images, images')
          .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid')
          .maybeSingle();
      if (provRes != null) {
        final raw = provRes['portfolio_images'] ?? provRes['images'];
        if (raw is List) {
          currentImages = raw.map((e) => e?.toString().trim() ?? '').where((s) => s.startsWith('http')).toList();
        }
      }
    } catch (e) {
      debugPrint('>>> [UserRepository.removePortfolioImage] providers query note: $e');
    }

    if (currentImages.isEmpty) {
      final user = await getUser(uid, forceRefresh: true);
      if (user != null) {
        currentImages = List<String>.from(user.images);
      }
    }

    currentImages.removeWhere((img) => img == imageUrl);

    try {
      await _supabase
          .from('providers')
          .update({
            'portfolio_images': currentImages,
            'images': currentImages,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
    } catch (_) {
      try {
        await _supabase
            .from('providers')
            .update({
              'portfolio_images': currentImages,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .or('id.eq.$userUuid,user_id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
      } catch (_) {}
    }

    try {
      await _supabase.from('profiles').update({'portfolio_images': currentImages}).or('id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
    } catch (_) {
      try {
        await _supabase.from('profiles').update({'images': currentImages}).or('id.eq.$userUuid,firebase_uid.eq.$uid,uid.eq.$uid');
      } catch (_) {}
    }

    _userCache.remove(uid);
    _userCache.remove(userUuid);
    _providersCache = null;
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

    _userCache.remove(uid);
    _userCache.remove(userUuid);
    _providersCache = null;

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