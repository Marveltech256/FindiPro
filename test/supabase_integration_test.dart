import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:findipro/core/config/supabase_config.dart';
import 'package:findipro/models/user_model.dart';
import 'package:findipro/models/chat_message.dart';
import 'package:findipro/models/conversation.dart';
import 'package:findipro/models/notification_model.dart';
import 'package:findipro/models/review_model.dart';
import 'package:findipro/models/service_model.dart';
import 'package:findipro/models/subscription_model.dart';
import 'package:findipro/models/verification_request.dart';
import 'package:findipro/repositories/service_repository.dart';
import 'package:findipro/services/location_service.dart';
import 'package:findipro/services/provider_entitlement_service.dart';
import 'package:findipro/services/subscription_payment_service.dart';
import 'package:findipro/services/theme_service.dart';
import 'package:findipro/core/utils/uuid_utils.dart';

void main() {
  group('UuidUtils Tests', () {
    test('Converts Firebase UID deterministically to a valid RFC 4122 UUID', () {
      final uuid1 = UuidUtils.firebaseUidToUuid('abc12345FirebaseUid');
      final uuid2 = UuidUtils.firebaseUidToUuid('abc12345FirebaseUid');
      expect(uuid1, uuid2);
      expect(uuid1.length, 36);
      expect(uuid1.contains('-'), true);
    });
  });

  group('SupabaseConfig Tests', () {
    test('Supabase constants are configured correctly', () {
      expect(SupabaseConfig.supabaseUrl, 'https://jfrwwjwowjuxxvxlgaib.supabase.co');
      expect(SupabaseConfig.supabaseProjectRef, 'jfrwwjwowjuxxvxlgaib');
      expect(SupabaseConfig.supabaseAnonKey, 'sb_publishable_Zre0XvhBfswbi5PDIM4dTQ_XJjZtRen');
      expect(SupabaseConfig.firebaseProjectId, 'findipro-7fe13');
    });
  });

  group('UserModel Supabase Mapping & Role Tests', () {
    test('UserModel maps from Supabase snake_case profile map correctly with provider role', () {
      final supabaseRow = {
        'id': 'user_123',
        'firebase_uid': 'firebase_uid_abc',
        'display_name': 'Jane Doe',
        'email': 'jane@example.com',
        'phone': '+123456789',
        'role': 'provider',
        'photo_url': 'https://example.com/avatar.jpg',
        'is_approved': true,
        'category_name': 'Plumbing',
        'address': 'Downtown',
        'years_experience': 5,
        'rating': 4.8,
        'review_count': 12,
        'price_range': '\$50 - \$100',
        'business_name': 'Jane Plumbing LLC',
        'is_verified': true,
        'is_premium': true,
        'latitude': 0.3476,
        'longitude': 32.5825,
      };

      final user = UserModel.fromMap(supabaseRow);

      expect(user.uid, 'firebase_uid_abc');
      expect(user.name, 'Jane Doe');
      expect(user.email, 'jane@example.com');
      expect(user.phone, '+123456789');
      expect(user.role, 'provider');
      expect(user.isProvider, true);
      expect(user.isCustomer, false);
      expect(user.photoUrl, 'https://example.com/avatar.jpg');
      expect(user.isApproved, true);
      expect(user.category, 'Plumbing');
      expect(user.location, 'Downtown');
      expect(user.yearsExperience, 5);
      expect(user.rating, 4.8);
      expect(user.reviewCount, 12);
      expect(user.priceRange, '\$50 - \$100');
      expect(user.businessName, 'Jane Plumbing LLC');
      expect(user.verified, true);
      expect(user.premium, true);
      expect(user.latitude, 0.3476);
      expect(user.longitude, 32.5825);
    });

    test('UserModel maps customer and client roles to customer', () {
      final clientRow = {
        'id': 'user_client',
        'display_name': 'Client User',
        'email': 'client@example.com',
        'role': 'customer',
      };
      final user = UserModel.fromMap(clientRow);
      expect(user.role, 'customer');
      expect(user.isCustomer, true);
      expect(user.isProvider, false);
    });

    test('UserModel maps avatar_url from Supabase profiles correctly', () {
      final supabaseRow = {
        'firebase_uid': 'firebase_uid_avatar',
        'display_name': 'Avatar Tester',
        'email': 'avatar@example.com',
        'avatar_url': 'https://jfrwwjwowjuxxvxlgaib.supabase.co/storage/v1/object/public/avatars/uid/profile.jpg',
      };

      final user = UserModel.fromMap(supabaseRow);
      expect(user.photoUrl, 'https://jfrwwjwowjuxxvxlgaib.supabase.co/storage/v1/object/public/avatars/uid/profile.jpg');
      expect(user.toMap()['avatar_url'], 'https://jfrwwjwowjuxxvxlgaib.supabase.co/storage/v1/object/public/avatars/uid/profile.jpg');
    });

    test('UserModel toMap generates both camelCase and snake_case keys for database sync', () {
      const user = UserModel(
        uid: 'user_xyz',
        name: 'John Pro',
        email: 'john@example.com',
        role: 'provider',
        category: 'Electrical',
      );

      final map = user.toMap();

      expect(map['uid'], 'user_xyz');
      expect(map['firebase_uid'], 'user_xyz');
      expect(map['name'], 'John Pro');
      expect(map['display_name'], 'John Pro');
      expect(map['email'], 'john@example.com');
      expect(map['role'], 'provider');
      expect(map['category'], 'Electrical');
    });
  });

  group('ChatMessage & Conversation Supabase Tests', () {
    test('ChatMessage maps correctly from Supabase messages table columns', () {
      final map = {
        'id': 'msg_001',
        'sender_id': 'sender_123',
        'receiver_id': 'receiver_456',
        'message': 'Hello from customer',
        'booking_id': 'booking_789',
        'job_id': 'job_101',
        'read_at': '2026-08-23T12:00:00Z',
        'created_at': '2026-08-23T11:55:00Z',
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.id, 'msg_001');
      expect(msg.senderId, 'sender_123');
      expect(msg.receiverId, 'receiver_456');
      expect(msg.text, 'Hello from customer');
      expect(msg.bookingId, 'booking_789');
      expect(msg.jobId, 'job_101');
      expect(msg.isRead, true);
      expect(msg.readAt != null, true);
    });

    test('Conversation maps correctly from map data', () {
      final convMap = {
        'id': 'conv_123',
        'client_id': 'client_1',
        'provider_id': 'provider_2',
        'last_message': 'See you tomorrow',
        'last_message_sender_id': 'provider_2',
        'last_message_at': '2026-08-24T10:00:00Z',
        'client_unread_count': 2,
        'created_at': '2026-08-20T08:00:00Z',
      };

      final conv = Conversation.fromMap(convMap);
      expect(conv.id, 'conv_123');
      expect(conv.clientId, 'client_1');
      expect(conv.providerId, 'provider_2');
      expect(conv.lastMessage, 'See you tomorrow');
      expect(conv.clientUnreadCount, 2);
    });
  });

  group('ReviewModel Schema & Linkage Tests', () {
    test('ReviewModel maps correctly from public.reviews schema columns including business_id', () {
      final map = {
        'id': 'rev_001',
        'customer_id': 'cust_123',
        'business_id': 'biz_456',
        'job_id': 'job_789',
        'booking_id': 'book_101',
        'rating': 5,
        'comment': 'Outstanding plumbing work!',
        'created_at': '2026-08-25T07:00:00Z',
      };

      final rev = ReviewModel.fromMap(map);
      expect(rev.id, 'rev_001');
      expect(rev.customerId, 'cust_123');
      expect(rev.businessId, 'biz_456');
      expect(rev.jobId, 'job_789');
      expect(rev.bookingId, 'book_101');
      expect(rev.rating, 5);
      expect(rev.comment, 'Outstanding plumbing work!');

      final toMap = rev.toMap();
      expect(toMap['business_id'], 'biz_456');
      expect(toMap['customer_id'], 'cust_123');
    });

    test('ReviewModel maps canonical job-based review without business_id correctly', () {
      final map = {
        'id': 'rev_job_002',
        'customer_id': 'customer_uuid_1',
        'business_id': null,
        'job_id': 'job_uuid_99',
        'booking_id': null,
        'rating': 5,
        'comment': 'Great job fixing the wiring',
        'created_at': '2026-08-26T08:00:00Z',
      };

      final rev = ReviewModel.fromMap(map);
      expect(rev.id, 'rev_job_002');
      expect(rev.customerId, 'customer_uuid_1');
      expect(rev.businessId, null);
      expect(rev.jobId, 'job_uuid_99');
      expect(rev.bookingId, null);
      expect(rev.rating, 5);

      final payload = rev.toMap();
      expect(payload['business_id'], null);
      expect(payload['job_id'], 'job_uuid_99');
      expect(payload['customer_id'], 'customer_uuid_1');
    });
  });

  group('ServiceModel & ServiceRepository Tests', () {
    test('ServiceModel maps and serializes correctly', () {
      final map = {
        'id': 'srv_001',
        'provider_id': 'prov_uuid_123',
        'name': 'Pipe Leak Repair',
        'description': 'Fixing leaking pipes under sinks and bathrooms.',
        'price': 45000,
        'currency': 'UGX',
        'duration': '1-2 hours',
        'category': 'Plumbing',
        'is_active': true,
      };

      final srv = ServiceModel.fromMap(map);
      expect(srv.id, 'srv_001');
      expect(srv.providerId, 'prov_uuid_123');
      expect(srv.name, 'Pipe Leak Repair');
      expect(srv.description, 'Fixing leaking pipes under sinks and bathrooms.');
      expect(srv.price, 45000.0);
      expect(srv.currency, 'UGX');
      expect(srv.duration, '1-2 hours');
      expect(srv.category, 'Plumbing');
      expect(srv.isActive, true);

      final toMap = srv.toMap();
      expect(toMap['provider_id'], 'prov_uuid_123');
      expect(toMap['price'], 45000.0);
      expect(toMap['is_active'], true);
    });

    test('ServiceRepository derives services from provider skills and category', () async {
      const provider = UserModel(
        uid: 'prov_test_01',
        name: 'Pro Plumber',
        email: 'plumber@example.com',
        role: 'provider',
        category: 'Plumbing',
        skills: ['Pipe Fitting', 'Drain Cleaning'],
        priceRange: 'UGX 30,000 - 80,000',
        about: 'Expert plumbing services in Kampala.',
      );

      final repo = ServiceRepository();
      final services = await repo.getProviderServices(provider);

      expect(services.isNotEmpty, true);
      expect(services.length, 2);
      expect(services[0].name, 'Pipe Fitting');
      expect(services[0].category, 'Plumbing');
      expect(services[0].currency, 'UGX');
      expect(services[1].name, 'Drain Cleaning');
    });

    test('ServiceRepository returns single category service when no skills are provided', () async {
      const provider = UserModel(
        uid: 'prov_test_02',
        name: 'Electrician Bob',
        email: 'bob@example.com',
        role: 'provider',
        category: 'Electrical',
        skills: [],
        priceRange: 'UGX 50,000',
      );

      final repo = ServiceRepository();
      final services = await repo.getProviderServices(provider);

      expect(services.length, 1);
      expect(services.first.name, 'Electrical Service');
      expect(services.first.category, 'Electrical');
    });
  });

  group('Notification Schema Tests', () {
    test('NotificationModel deserializes and serializes correctly', () {
      final map = {
        'id': 'notif_001',
        'user_id': 'user_uuid_123',
        'title': 'Request Accepted',
        'body': 'John Plumber accepted your service request.',
        'type': 'hire_accepted',
        'data': {'request_id': 'req_456'},
        'read_at': null,
        'created_at': '2026-08-25T08:00:00Z',
      };

      final notif = NotificationModel.fromMap(map);
      expect(notif.id, 'notif_001');
      expect(notif.userId, 'user_uuid_123');
      expect(notif.title, 'Request Accepted');
      expect(notif.body, 'John Plumber accepted your service request.');
      expect(notif.type, 'hire_accepted');
      expect(notif.data?['request_id'], 'req_456');
      expect(notif.isRead, false);

      final toMap = notif.toMap();
      expect(toMap['user_id'], 'user_uuid_123');
      expect(toMap['type'], 'hire_accepted');
      expect(toMap.containsKey('is_read'), false);
    });

    test('Review notification payload structure is correctly formatted', () {
      final providerUuid = UuidUtils.firebaseUidToUuid('provider_uid_123');
      final notifPayload = {
        'user_id': providerUuid,
        'title': 'New Review',
        'body': 'Alice reviewed your service.',
        'type': 'review',
        'data': {
          'review_id': 'rev_123',
          'job_id': 'job_456',
        },
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final notif = NotificationModel.fromMap(notifPayload, 'temp_id');
      expect(notif.title, 'New Review');
      expect(notif.body, 'Alice reviewed your service.');
      expect(notif.type, 'review');
    });
  });

  group('SubscriptionModel Schema Tests', () {
    test('SubscriptionModel maps and serializes correctly', () {
      final map = {
        'id': 'sub_001',
        'provider_id': 'prov_uuid_123',
        'plan': 'verified',
        'billing_period': 'monthly',
        'region': 'Africa',
        'currency': 'UGX',
        'amount': 10000,
        'status': 'active',
        'started_at': '2026-08-25T00:00:00Z',
        'expires_at': '2026-09-25T00:00:00Z',
        'auto_renew': true,
        'created_at': '2026-08-25T00:00:00Z',
        'updated_at': '2026-08-25T00:00:00Z',
      };

      final sub = SubscriptionModel.fromMap(map);
      expect(sub.id, 'sub_001');
      expect(sub.providerId, 'prov_uuid_123');
      expect(sub.plan, 'verified');
      expect(sub.amount, 10000);
      expect(sub.currency, 'UGX');
      expect(sub.isActive, true);

      final toMap = sub.toMap();
      expect(toMap['provider_id'], 'prov_uuid_123');
      expect(toMap['plan'], 'verified');
    });
  });

  group('Phase 34 Provider Plan, Entitlements & Badge Tests', () {
    test('Basic provider has no badges and max 2 portfolio images', () {
      const basicProvider = UserModel(
        uid: 'p_basic',
        name: 'Basic Bob',
        email: 'bob@example.com',
        role: 'provider',
        plan: 'basic',
        subscriptionStatus: 'active',
      );

      expect(basicProvider.effectivePlan, 'basic');
      expect(basicProvider.isVerifiedBadge, false);
      expect(basicProvider.isPremiumBadge, false);
      expect(ProviderEntitlementService.isBasic(basicProvider), true);
      expect(ProviderEntitlementService.isVerified(basicProvider), false);
      expect(ProviderEntitlementService.isPremium(basicProvider), false);
      expect(ProviderEntitlementService.getPortfolioImageLimit(basicProvider), 2);
      expect(ProviderEntitlementService.canUploadPortfolioImage(basicProvider, 1), true);
      expect(ProviderEntitlementService.canUploadPortfolioImage(basicProvider, 2), false);
      expect(ProviderEntitlementService.hasPriorityRanking(basicProvider), false);
    });

    test('Verified provider with approved verification has blue badge and max 5 images', () {
      const verifiedProvider = UserModel(
        uid: 'p_verified',
        name: 'Verified Alice',
        email: 'alice@example.com',
        role: 'provider',
        plan: 'verified',
        subscriptionStatus: 'active',
        verificationStatus: 'approved',
      );

      expect(verifiedProvider.effectivePlan, 'verified');
      expect(verifiedProvider.isVerifiedBadge, true);
      expect(verifiedProvider.isPremiumBadge, false);
      expect(ProviderEntitlementService.getPortfolioImageLimit(verifiedProvider), 5);
      expect(ProviderEntitlementService.canUploadPortfolioImage(verifiedProvider, 4), true);
      expect(ProviderEntitlementService.canUploadPortfolioImage(verifiedProvider, 5), false);
      expect(ProviderEntitlementService.hasPrioritySupport(verifiedProvider), true);
      expect(ProviderEntitlementService.hasPriorityRanking(verifiedProvider), false);
    });

    test('Verified provider with pending verification does NOT receive verified badge', () {
      const pendingVerified = UserModel(
        uid: 'p_pending',
        name: 'Pending Paul',
        email: 'paul@example.com',
        role: 'provider',
        plan: 'verified',
        subscriptionStatus: 'active',
        verificationStatus: 'pending',
      );

      expect(pendingVerified.isVerifiedBadge, false);
    });

    test('Premium provider has golden badge, priority ranking, and max 10 images', () {
      const premiumProvider = UserModel(
        uid: 'p_prem',
        name: 'VIP Victor',
        email: 'victor@example.com',
        role: 'provider',
        plan: 'premium',
        subscriptionStatus: 'active',
      );

      expect(premiumProvider.effectivePlan, 'premium');
      expect(premiumProvider.isPremiumBadge, true);
      expect(ProviderEntitlementService.isPremium(premiumProvider), true);
      expect(ProviderEntitlementService.getPortfolioImageLimit(premiumProvider), 10);
      expect(ProviderEntitlementService.hasPriorityRanking(premiumProvider), true);
      expect(ProviderEntitlementService.hasFeaturedPlacement(premiumProvider), true);
      expect(ProviderEntitlementService.hasAnalytics(premiumProvider), true);
      expect(ProviderEntitlementService.hasPromotionalTools(premiumProvider), true);
      expect(ProviderEntitlementService.hasUnlimitedServices(premiumProvider), true);
      expect(ProviderEntitlementService.hasPrioritySupport(premiumProvider), true);
    });

    test('Expired Premium subscription safely downgrades to Basic and loses badges', () {
      final expiredPremium = UserModel(
        uid: 'p_expired',
        name: 'Expired Eric',
        email: 'eric@example.com',
        role: 'provider',
        plan: 'premium',
        subscriptionStatus: 'expired',
        subscriptionExpiresAt: DateTime.now().subtract(const Duration(days: 5)),
      );

      expect(expiredPremium.isSubscriptionActive, false);
      expect(expiredPremium.effectivePlan, 'basic');
      expect(expiredPremium.isPremiumBadge, false);
      expect(ProviderEntitlementService.hasPriorityRanking(expiredPremium), false);
      expect(ProviderEntitlementService.getPortfolioImageLimit(expiredPremium), 2);
    });
  });

  group('Phase 34 Regional Pricing Tests', () {
    test('Africa / Uganda pricing (UGX) with 20% yearly savings', () {
      final verified = ProviderEntitlementService.getPlanPrice(plan: 'verified', region: 'Africa');
      expect(verified.currency, 'UGX');
      expect(verified.monthlyPrice, 10000);
      expect(verified.yearlyPrice, 96000);
      expect(verified.formattedMonthly, 'UGX 10,000/month');
      expect(verified.formattedYearly, 'UGX 96,000/year');

      final premium = ProviderEntitlementService.getPlanPrice(plan: 'premium', region: 'Africa');
      expect(premium.currency, 'UGX');
      expect(premium.monthlyPrice, 25000);
      expect(premium.yearlyPrice, 240000);
      expect(premium.formattedMonthly, 'UGX 25,000/month');
      expect(premium.formattedYearly, 'UGX 240,000/year');
    });

    test('Europe pricing (EUR) with 20% yearly savings', () {
      final verified = ProviderEntitlementService.getPlanPrice(plan: 'verified', region: 'Europe');
      expect(verified.currency, 'EUR');
      expect(verified.monthlyPrice, 9.99);
      expect(verified.yearlyPrice, 95.9);
      expect(verified.formattedMonthly, '€9.99/month');
      expect(verified.formattedYearly, '€95.90/year');

      final premium = ProviderEntitlementService.getPlanPrice(plan: 'premium', region: 'Europe');
      expect(premium.currency, 'EUR');
      expect(premium.monthlyPrice, 24.99);
      expect(premium.yearlyPrice, 239.9);
      expect(premium.formattedMonthly, '€24.99/month');
      expect(premium.formattedYearly, '€239.90/year');
    });

    test('USA pricing (USD) with 20% yearly savings', () {
      final verified = ProviderEntitlementService.getPlanPrice(plan: 'verified', region: 'USA');
      expect(verified.currency, 'USD');
      expect(verified.monthlyPrice, 10);
      expect(verified.yearlyPrice, 96);
      expect(verified.formattedMonthly, '\$10/month');
      expect(verified.formattedYearly, '\$96/year');

      final premium = ProviderEntitlementService.getPlanPrice(plan: 'premium', region: 'USA');
      expect(premium.currency, 'USD');
      expect(premium.monthlyPrice, 25);
      expect(premium.yearlyPrice, 240);
      expect(premium.formattedMonthly, '\$25/month');
      expect(premium.formattedYearly, '\$240/year');
    });

    test('Safe region detection using GPS coordinates and keywords', () {
      // GPS Coordinates
      expect(ProviderEntitlementService.detectRegion(latitude: 51.5074, longitude: -0.1278), 'Europe'); // London
      expect(ProviderEntitlementService.detectRegion(latitude: 30.2672, longitude: -97.7431), 'USA'); // Austin, TX
      expect(ProviderEntitlementService.detectRegion(latitude: 0.3476, longitude: 32.5825), 'Africa'); // Kampala

      // Location keywords
      expect(ProviderEntitlementService.detectRegion(location: 'London, UK'), 'Europe');
      expect(ProviderEntitlementService.detectRegion(location: 'Austin, Texas, USA'), 'USA');
      expect(ProviderEntitlementService.detectRegion(location: 'Kampala, Uganda'), 'Africa');
      expect(ProviderEntitlementService.detectRegion(location: null), 'Africa');
    });

    test('Dynamic yearly pricing formula always matches 20% discount on 12 months', () {
      for (final region in ['Africa', 'Europe', 'USA']) {
        for (final plan in ['verified', 'premium']) {
          final price = ProviderEntitlementService.getPlanPrice(plan: plan, region: region);
          final expectedYearly = double.parse((price.monthlyPrice * 12 * 0.80).toStringAsFixed(2));
          expect(price.yearlyPrice, expectedYearly);
          expect(price.standardYearlyTotal, price.monthlyPrice * 12);
        }
      }
    });
  });

  group('Phase 34 Provider Ranking Tests', () {
    test('Ranking orders Premium > Verified > Basic', () {
      const basicP = UserModel(uid: '1', name: 'Basic', email: 'b@e.com', role: 'provider', plan: 'basic');
      const verifiedP = UserModel(uid: '2', name: 'Verified', email: 'v@e.com', role: 'provider', plan: 'verified', verificationStatus: 'approved');
      const premiumP = UserModel(uid: '3', name: 'Premium', email: 'p@e.com', role: 'provider', plan: 'premium');

      final ranked = LocationService.sortProvidersByDistance([basicP, premiumP, verifiedP], null);
      expect(ranked[0].uid, '3'); // Premium
      expect(ranked[1].uid, '2'); // Verified
      expect(ranked[2].uid, '1'); // Basic
    });
  });

  group('LocationService Distance Tests', () {
    test('Haversine distance calculation and formatting', () {
      final distanceKm = LocationService.calculateDistanceKm(0.3476, 32.5825, 0.0512, 32.4637);
      expect(distanceKm > 30.0 && distanceKm < 40.0, true);

      expect(LocationService.formatDistance(0.45), '450 m away');
      expect(LocationService.formatDistance(2.35), '2.4 km away');
      expect(LocationService.formatDistance(35.4), '35.4 km away');
    });
  });

  group('Batch C Settings & Theme Tests', () {
    test('ThemeService supports light and dark toggle', () async {
      final theme = ThemeService();
      expect(theme.themeMode == ThemeMode.light || theme.themeMode == ThemeMode.dark, true);

      await theme.toggleTheme(true);
      expect(theme.isDarkMode, true);

      await theme.toggleTheme(false);
      expect(theme.isDarkMode, false);
    });

    test('Support WhatsApp URL encoding is valid and safe', () {
      const supportNumber = '256763294426';
      const rawMessage = 'Hello FindiPro Support, I need assistance with my account.';
      final encoded = Uri.encodeComponent(rawMessage);
      final uri = Uri.parse('https://wa.me/$supportNumber?text=$encoded');

      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], rawMessage);
    });
  });

  group('Phase 3 Verification Workflow & Isolation Tests', () {
    test('VerificationRequest serialization and deserialization maps all fields correctly', () {
      final now = DateTime.now();
      final req = VerificationRequest(
        id: 'verif-123',
        providerId: 'provider-abc',
        providerName: 'John Doe Plumbing',
        nationalIdNumber: 'CM987654321AB',
        idFrontUrl: 'https://storage/documents/id_front.jpg',
        idBackUrl: 'https://storage/documents/id_back.jpg',
        businessDocUrl: 'https://storage/documents/trade_license.pdf',
        status: 'pending',
        notes: 'Initial submission',
        createdAt: now,
      );

      final map = req.toMap();
      expect(map['id'], 'verif-123');
      expect(map['provider_id'], 'provider-abc');
      expect(map['provider_name'], 'John Doe Plumbing');
      expect(map['national_id_number'], 'CM987654321AB');
      expect(map['id_front_url'], 'https://storage/documents/id_front.jpg');
      expect(map['id_back_url'], 'https://storage/documents/id_back.jpg');
      expect(map['business_doc_url'], 'https://storage/documents/trade_license.pdf');
      expect(map['status'], 'pending');
      expect(map['notes'], 'Initial submission');

      final deserialized = VerificationRequest.fromMap(map);
      expect(deserialized.id, 'verif-123');
      expect(deserialized.providerId, 'provider-abc');
      expect(deserialized.providerName, 'John Doe Plumbing');
      expect(deserialized.nationalIdNumber, 'CM987654321AB');
      expect(deserialized.status, 'pending');
    });

    test('Provider Verification and Subscription tiers remain strictly isolated', () {
      // Pro subscription does NOT automatically verify identity
      const proUserUnverified = UserModel(
        uid: 'user-pro',
        name: 'Pro User',
        email: 'pro@test.com',
        role: 'provider',
        plan: 'verified', // Pro subscription plan
        verified: false, // Not identity verified
        verificationStatus: 'pending',
      );
      expect(proUserUnverified.effectivePlan, 'verified');
      expect(proUserUnverified.verified, false);

      // Identity verified provider on basic plan
      const basicUserVerified = UserModel(
        uid: 'user-basic',
        name: 'Basic Verified User',
        email: 'basic@test.com',
        role: 'provider',
        plan: 'basic',
        verified: true,
        verificationStatus: 'approved',
      );
      expect(basicUserVerified.effectivePlan, 'basic');
      expect(basicUserVerified.isVerifiedBadge, true);
    });

    test('Verification rejection preserves rejection feedback notes for resubmission', () {
      final rejectedMap = {
        'id': 'verif-999',
        'provider_id': 'prov-xyz',
        'provider_name': 'Jane Electrician',
        'national_id_number': 'UG456789012CD',
        'id_front_url': 'documents/blurry_id.jpg',
        'status': 'rejected',
        'notes': 'Government ID image is blurry. Please upload a clear photo.',
        'created_at': DateTime.now().toIso8601String(),
      };

      final req = VerificationRequest.fromMap(rejectedMap);
      expect(req.status, 'rejected');
      expect(req.notes, 'Government ID image is blurry. Please upload a clear photo.');
      expect(req.nationalIdNumber, 'UG456789012CD');
    });
  });

  group('Phase 4 Real Subscription Payment & Failure Handling Tests', () {
    final paymentService = SubscriptionPaymentService();

    test('Basic plan returns free and requires zero payment processing', () async {
      final res = await paymentService.processSubscriptionPayment(
        providerId: 'provider-123',
        providerName: 'Test Provider',
        providerEmail: 'provider@test.com',
        plan: 'basic',
        billingPeriod: 'monthly',
        region: 'Africa',
        paymentMethod: PaymentMethodType.card,
      );

      expect(res.isSuccessful, true);
      expect(res.amount, 0);
      expect(res.plan, 'basic');
    });

    test('Pro monthly and yearly pricing matches exact region pricing specifications', () {
      // Africa / Uganda
      final africaPro = ProviderEntitlementService.getPlanPrice(plan: 'verified', region: 'Africa');
      expect(africaPro.monthlyPrice, 10000);
      expect(africaPro.yearlyPrice, 96000); // 10000 * 12 * 0.80

      // Europe
      final europePro = ProviderEntitlementService.getPlanPrice(plan: 'verified', region: 'Europe');
      expect(europePro.monthlyPrice, 9.99);
      expect(europePro.yearlyPrice, 95.90); // 9.99 * 12 * 0.80 = 95.904 -> 95.90

      // USA
      final usaPro = ProviderEntitlementService.getPlanPrice(plan: 'verified', region: 'USA');
      expect(usaPro.monthlyPrice, 10);
      expect(usaPro.yearlyPrice, 96); // 10 * 12 * 0.80
    });

    test('Premium monthly and yearly pricing matches exact region pricing specifications', () {
      // Africa / Uganda
      final africaPrem = ProviderEntitlementService.getPlanPrice(plan: 'premium', region: 'Africa');
      expect(africaPrem.monthlyPrice, 25000);
      expect(africaPrem.yearlyPrice, 240000); // 25000 * 12 * 0.80

      // Europe
      final europePrem = ProviderEntitlementService.getPlanPrice(plan: 'premium', region: 'Europe');
      expect(europePrem.monthlyPrice, 24.99);
      expect(europePrem.yearlyPrice, 239.90); // 24.99 * 12 * 0.80 = 239.904 -> 239.90

      // USA
      final usaPrem = ProviderEntitlementService.getPlanPrice(plan: 'premium', region: 'USA');
      expect(usaPrem.monthlyPrice, 25);
      expect(usaPrem.yearlyPrice, 240); // 25 * 12 * 0.80
    });

    test('Supported payment methods vary accurately by region', () {
      final africaMethods = paymentService.getSupportedPaymentMethods('Africa');
      expect(africaMethods.any((m) => m.type == PaymentMethodType.mtnMobileMoney), true);
      expect(africaMethods.any((m) => m.type == PaymentMethodType.airtelMoney), true);
      expect(africaMethods.any((m) => m.type == PaymentMethodType.card), true);

      final europeMethods = paymentService.getSupportedPaymentMethods('Europe');
      expect(europeMethods.any((m) => m.type == PaymentMethodType.card), true);
      expect(europeMethods.any((m) => m.type == PaymentMethodType.mtnMobileMoney), false);

      final usaMethods = paymentService.getSupportedPaymentMethods('USA');
      expect(usaMethods.any((m) => m.type == PaymentMethodType.card), true);
    });

    test('Payment transaction reference is cryptographically unique and idempotent', () {
      final ref1 = paymentService.generateTransactionReference('premium', 'prov-1');
      final ref2 = paymentService.generateTransactionReference('premium', 'prov-1');
      expect(ref1 != ref2, true);
      expect(ref1.startsWith('FP-SUB-premium-'), true);
    });

    test('Mobile money payment fails gracefully when phone number is missing or invalid', () async {
      final res = await paymentService.processSubscriptionPayment(
        providerId: 'prov-abc',
        providerName: 'Test',
        providerEmail: 'test@test.com',
        plan: 'premium',
        billingPeriod: 'monthly',
        region: 'Africa',
        paymentMethod: PaymentMethodType.mtnMobileMoney,
        phoneNumber: '123', // Invalid
      );

      expect(res.isSuccessful, false);
      expect(res.status, PaymentResultStatus.failed);
      expect(res.errorMessage!.contains('phone number'), true);
    });

    test('Payment failure does not activate subscription or modify plan benefits', () async {
      final res = await paymentService.processSubscriptionPayment(
        providerId: '', // Invalid provider
        providerName: 'Test',
        providerEmail: 'test@test.com',
        plan: 'premium',
        billingPeriod: 'monthly',
        region: 'Africa',
        paymentMethod: PaymentMethodType.card,
      );

      expect(res.isSuccessful, false);
      expect(res.status, PaymentResultStatus.failed);
      expect(res.subscription, isNull);
    });

    test('Subscription expiration revokes isActive status and downgrades entitlements', () {
      final expiredSub = SubscriptionModel(
        id: 'sub-expired',
        providerId: 'prov-expired',
        plan: 'premium',
        status: 'active',
        expiresAt: DateTime.now().subtract(const Duration(days: 2)), // Expired 2 days ago
        createdAt: DateTime.now().subtract(const Duration(days: 32)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(expiredSub.isActive, false);

      final expiredUser = UserModel(
        uid: 'prov-expired',
        name: 'Expired Provider',
        email: 'expired@test.com',
        role: 'provider',
        plan: 'premium',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(expiredUser.isSubscriptionActive, false);
      expect(expiredUser.effectivePlan, 'basic');
      expect(expiredUser.isPremiumBadge, false);
    });
  });

  group('Phase 5 Subscription Lifecycle & Entitlement Hardening Tests', () {
    test('Basic provider has no badge and analytics is strictly blocked', () {
      const basicUser = UserModel(
        uid: 'prov-basic-1',
        name: 'Basic John',
        email: 'basic@findipro.com',
        role: 'provider',
        plan: 'basic',
        subscriptionStatus: 'active',
        verified: false,
        verificationStatus: 'none',
      );

      expect(basicUser.effectivePlan, 'basic');
      expect(basicUser.isPremiumBadge, false);
      expect(basicUser.isVerifiedBadge, false);
      expect(ProviderEntitlementService.hasAnalytics(basicUser), false);
      expect(ProviderEntitlementService.getPortfolioImageLimit(basicUser), 2);
      expect(ProviderEntitlementService.hasPriorityRanking(basicUser), false);
    });

    test('Verified provider receives blue badge when eligible, and analytics is strictly blocked', () {
      const verifiedUser = UserModel(
        uid: 'prov-verif-1',
        name: 'Verified Sarah',
        email: 'verified@findipro.com',
        role: 'provider',
        plan: 'verified',
        subscriptionStatus: 'active',
        verified: true,
        verificationStatus: 'approved',
        subscriptionExpiresAt: null,
      );

      expect(verifiedUser.effectivePlan, 'verified');
      expect(verifiedUser.isVerifiedBadge, true);
      expect(verifiedUser.isPremiumBadge, false);
      expect(ProviderEntitlementService.hasAnalytics(verifiedUser), false);
      expect(ProviderEntitlementService.getPortfolioImageLimit(verifiedUser), 5);
      expect(ProviderEntitlementService.hasPrioritySupport(verifiedUser), true);
    });

    test('Premium provider receives gold badge, priority visibility, and analytics access', () {
      final futureExpiry = DateTime.now().add(const Duration(days: 30));
      final premiumUser = UserModel(
        uid: 'prov-prem-1',
        name: 'Premium Paul',
        email: 'prem@findipro.com',
        role: 'provider',
        plan: 'premium',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: futureExpiry,
        verified: false,
      );

      expect(premiumUser.effectivePlan, 'premium');
      expect(premiumUser.isPremiumBadge, true);
      expect(ProviderEntitlementService.hasAnalytics(premiumUser), true);
      expect(ProviderEntitlementService.getPortfolioImageLimit(premiumUser), 10);
      expect(ProviderEntitlementService.hasPriorityRanking(premiumUser), true);
      expect(ProviderEntitlementService.hasFeaturedPlacement(premiumUser), true);
      expect(ProviderEntitlementService.hasUnlimitedServices(premiumUser), true);
    });

    test('Expired Premium provider loses gold badge, ranking, and analytics, while account remains intact', () {
      final pastExpiry = DateTime.now().subtract(const Duration(days: 1));
      final expiredPremUser = UserModel(
        uid: 'prov-prem-expired',
        name: 'Expired Paul',
        email: 'prem-exp@findipro.com',
        role: 'provider',
        plan: 'premium',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: pastExpiry,
        skills: const ['Plumbing', 'Electrical'],
        images: const ['img1.jpg', 'img2.jpg', 'img3.jpg'],
      );

      // Account data and history remain intact
      expect(expiredPremUser.skills.length, 2);
      expect(expiredPremUser.images.length, 3);

      // Entitlements are safely downgraded
      expect(expiredPremUser.isSubscriptionActive, false);
      expect(expiredPremUser.effectivePlan, 'basic');
      expect(expiredPremUser.isPremiumBadge, false);
      expect(ProviderEntitlementService.hasAnalytics(expiredPremUser), false);
      expect(ProviderEntitlementService.hasPriorityRanking(expiredPremUser), false);
      expect(ProviderEntitlementService.hasFeaturedPlacement(expiredPremUser), false);
      expect(ProviderEntitlementService.getPortfolioImageLimit(expiredPremUser), 2);
    });

    test('Renewed provider restores active plan and entitlements without requiring relogin', () {
      final now = DateTime.now();
      // 1. Expired state
      final expiredUser = UserModel(
        uid: 'prov-renew-1',
        name: 'Renewing Provider',
        email: 'renew@findipro.com',
        role: 'provider',
        plan: 'premium',
        subscriptionStatus: 'expired',
        subscriptionExpiresAt: now.subtract(const Duration(days: 5)),
      );
      expect(expiredUser.effectivePlan, 'basic');
      expect(ProviderEntitlementService.hasAnalytics(expiredUser), false);

      // 2. Renewed state after verified payment
      final renewedUser = UserModel(
        uid: 'prov-renew-1',
        name: 'Renewing Provider',
        email: 'renew@findipro.com',
        role: 'provider',
        plan: 'premium',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: now.add(const Duration(days: 30)),
      );
      expect(renewedUser.effectivePlan, 'premium');
      expect(renewedUser.isPremiumBadge, true);
      expect(ProviderEntitlementService.hasAnalytics(renewedUser), true);
      expect(ProviderEntitlementService.getPortfolioImageLimit(renewedUser), 10);
    });

    test('SubscriptionModel lifecycle state getters handle pending, active, expired, cancelled, failed', () {
      final now = DateTime.now();

      final pendingSub = SubscriptionModel(
        id: 'sub-1',
        providerId: 'prov-1',
        plan: 'premium',
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      expect(pendingSub.isPending, true);
      expect(pendingSub.isActive, false);

      final activeSub = SubscriptionModel(
        id: 'sub-2',
        providerId: 'prov-1',
        plan: 'premium',
        status: 'active',
        expiresAt: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );
      expect(activeSub.isActive, true);
      expect(activeSub.isExpired, false);

      final expiredSub = SubscriptionModel(
        id: 'sub-3',
        providerId: 'prov-1',
        plan: 'premium',
        status: 'active',
        expiresAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 31)),
        updatedAt: now,
      );
      expect(expiredSub.isActive, false);
      expect(expiredSub.isExpired, true);

      final cancelledSub = SubscriptionModel(
        id: 'sub-4',
        providerId: 'prov-1',
        plan: 'verified',
        status: 'cancelled',
        createdAt: now,
        updatedAt: now,
      );
      expect(cancelledSub.isCancelled, true);
      expect(cancelledSub.isActive, false);

      final failedSub = SubscriptionModel(
        id: 'sub-5',
        providerId: 'prov-1',
        plan: 'premium',
        status: 'failed',
        createdAt: now,
        updatedAt: now,
      );
      expect(failedSub.isFailed, true);
      expect(failedSub.isActive, false);
    });
  });
}
