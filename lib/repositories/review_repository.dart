import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../models/review_model.dart';
import '../repositories/user_repository.dart';

class ReviewRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  final UserRepository _userRepo = UserRepository();

  // ============================================================
  // ID HELPERS
  // ============================================================

  String _toUuid(String id) {
    final value = id.trim();

    if (value.isEmpty) {
      return '';
    }

    if (UuidUtils.isValidUuid(value)) {
      return value;
    }

    return UuidUtils.firebaseUidToUuid(value);
  }

  // ============================================================
  // CHECK WHETHER CUSTOMER ALREADY REVIEWED A JOB
  // ============================================================

  Future<bool> hasReviewed({
    required String customerId,
    String? jobId,
    String? bookingId,
    String? providerId,
  }) async {
    final customerUuid = _toUuid(customerId);

    if (customerUuid.isEmpty && customerId.trim().isEmpty) {
      return false;
    }

    final Set<String> customerKeys = {};
    if (customerUuid.isNotEmpty) customerKeys.add(customerUuid.toLowerCase());
    if (customerId.trim().isNotEmpty) customerKeys.add(customerId.trim().toLowerCase());

    // 1. Primary rule: Check by job_id (1 review per job)
    if (jobId != null && jobId.trim().isNotEmpty) {
      final jobUuid = _toUuid(jobId);

      if (jobUuid.isNotEmpty) {
        try {
          final result = await _supabase
              .from('reviews')
              .select('id, customer_id')
              .eq('job_id', jobUuid)
              .limit(5);

          for (final row in result) {
            final rowCustId = (row['customer_id'] ?? '').toString().toLowerCase();
            if (rowCustId.isEmpty || customerKeys.contains(rowCustId)) {
              return true;
            }
          }
        } catch (e) {
          debugPrint('>>> [ReviewRepository.hasReviewed] job check error: $e');
        }
      }
    }

    // 2. Check by booking_id
    if (bookingId != null && bookingId.trim().isNotEmpty) {
      final bookingUuid = _toUuid(bookingId);

      if (bookingUuid.isNotEmpty) {
        try {
          final result = await _supabase
              .from('reviews')
              .select('id, customer_id')
              .eq('booking_id', bookingUuid)
              .limit(5);

          for (final row in result) {
            final rowCustId = (row['customer_id'] ?? '').toString().toLowerCase();
            if (rowCustId.isEmpty || customerKeys.contains(rowCustId)) {
              return true;
            }
          }
        } catch (e) {
          debugPrint('>>> [ReviewRepository.hasReviewed] booking check error: $e');
        }
      }
    }

    // 3. Check by direct provider_id (for reviews without job_id)
    if (providerId != null && providerId.trim().isNotEmpty) {
      final providerUuid = _toUuid(providerId);
      final Set<String> providerKeys = {};
      if (providerUuid.isNotEmpty) providerKeys.add(providerUuid.toLowerCase());
      if (providerId.trim().isNotEmpty) providerKeys.add(providerId.trim().toLowerCase());

      for (final cKey in customerKeys) {
        for (final pKey in providerKeys) {
          try {
            final result = await _supabase
                .from('reviews')
                .select('id')
                .eq('customer_id', cKey)
                .eq('provider_id', pKey)
                .isFilter('job_id', null)
                .limit(1);

            if (result.isNotEmpty) return true;
          } catch (e) {
            debugPrint('>>> [ReviewRepository.hasReviewed] provider check error: $e');
          }
        }
      }
    }

    return false;
  }

  // ============================================================
  // ADD REVIEW
  // ============================================================

  Future<void> addReview({
    required String customerId,
    required int rating,
    String? comment,
    String? jobId,
    String? bookingId,
    String? providerId,
  }) async {
    debugPrint('==============================================');
    debugPrint('>>> ADD REVIEW START');
    debugPrint('customerId: $customerId');
    debugPrint('providerId: $providerId');
    debugPrint('jobId: $jobId');
    debugPrint('bookingId: $bookingId');
    debugPrint('rating: $rating');
    debugPrint('==============================================');

    // ----------------------------------------------------------
    // BASIC VALIDATION
    // ----------------------------------------------------------

    if (rating < 1 || rating > 5) {
      throw Exception(
        'Please select a rating between 1 and 5 stars.',
      );
    }

    if (customerId.trim().isEmpty) {
      throw Exception(
        'Your account could not be identified.',
      );
    }

    if (providerId == null || providerId.trim().isEmpty) {
      throw Exception(
        'This service is not linked to a service provider.',
      );
    }

    final customerUuid = _toUuid(customerId);
    var providerUuid = _toUuid(providerId);

    if (customerUuid.isEmpty) {
      throw Exception(
        'Invalid customer account.',
      );
    }

    if (providerUuid.isEmpty) {
      throw Exception(
        'Invalid service provider.',
      );
    }

    // ----------------------------------------------------------
    // SELF REVIEW PROTECTION
    // ----------------------------------------------------------

    if (customerUuid.toLowerCase() ==
        providerUuid.toLowerCase()) {
      throw Exception(
        'You cannot review your own service.',
      );
    }

    // ----------------------------------------------------------
    // RESOLVE JOB
    // ----------------------------------------------------------

    String? jobUuid;

    if (jobId != null && jobId.trim().isNotEmpty) {
      jobUuid = _toUuid(jobId);

      if (jobUuid.isEmpty) {
        throw Exception(
          'Invalid service/job.',
        );
      }
    }

    // ----------------------------------------------------------
    // RESOLVE BOOKING
    // ----------------------------------------------------------

    String? bookingUuid;

    if (bookingId != null && bookingId.trim().isNotEmpty) {
      bookingUuid = _toUuid(bookingId);

      if (bookingUuid.isEmpty) {
        bookingUuid = null;
      }
    }

    // ----------------------------------------------------------
    // VERIFY JOB
    // ----------------------------------------------------------

    Map<String, dynamic>? jobData;

    if (jobUuid != null) {
      try {
        jobData = await _supabase
            .from('jobs')
            .select()
            .eq('id', jobUuid)
            .maybeSingle();
      } catch (e) {
        debugPrint(
          '>>> [ReviewRepository.addReview] '
          'job lookup error: $e',
        );
      }

      if (jobData == null) {
        throw Exception(
          'The service could not be found.',
        );
      }

      final jobCustomerId =
          (jobData['customer_id'] ?? '').toString();

      if (jobCustomerId.isNotEmpty) {
        final jobCustomerUuid = _toUuid(jobCustomerId);

        if (jobCustomerUuid.toLowerCase() !=
            customerUuid.toLowerCase()) {
          throw Exception(
            'You can only review your own completed service.',
          );
        }
      }

      final jobStatus =
          (jobData['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      debugPrint(
        '>>> Job status: $jobStatus',
      );

      if (jobStatus != 'completed') {
        throw Exception(
          'Only completed services can be reviewed.',
        );
      }
    }

    // ----------------------------------------------------------
    // VERIFY PROVIDER THROUGH JOB ASSIGNMENT
    // ----------------------------------------------------------

    if (jobUuid != null) {
      try {
        final assignments = await _supabase
            .from('job_assignments')
            .select()
            .eq('job_id', jobUuid);

        if (assignments.isNotEmpty) {
          // Use the first assignment's technician/provider as the canonical provider.
          // We trust the assignment record — the caller's providerId is a hint only.
          final first = Map<String, dynamic>.from(assignments.first);
          final techId = (first['technician_id'] ?? '').toString();
          final aProvId = (first['provider_id'] ?? '').toString();
          final canonicalUuid = techId.isNotEmpty ? _toUuid(techId) : _toUuid(aProvId);

          if (canonicalUuid.isNotEmpty) {
            // Override providerUuid with the canonical assigned value.
            // This corrects Firebase-UID vs Supabase-UUID mismatches.
            providerUuid = canonicalUuid;
          }

          // Self-review protection: assigned provider must not be the reviewer.
          if (providerUuid.toLowerCase() == customerUuid.toLowerCase()) {
            throw Exception('You cannot review your own service.');
          }
        }
        // If no assignment exists, we still allow the review using the
        // providerId supplied by the caller (already validated above).
      } catch (e) {
        if (e is Exception) rethrow;
        debugPrint('>>> [ReviewRepository.addReview] assignment lookup note: $e');
      }
    }

    // ----------------------------------------------------------
    // DUPLICATE REVIEW CHECK
    // ----------------------------------------------------------

    final alreadyReviewed = await hasReviewed(
      customerId: customerId,
      jobId: jobId,
      bookingId: bookingId,
      providerId: providerId,
    );

    if (alreadyReviewed) {
      throw Exception(
        'You have already reviewed this service.',
      );
    }

    // ----------------------------------------------------------
    // FIND BUSINESS
    // ----------------------------------------------------------

    String? businessUuid;

    try {
      final businessResult = await _supabase
          .from('businesses')
          .select('id')
          .or(
            'owner_id.eq.$providerUuid,'
            'user_id.eq.$providerUuid,'
            'id.eq.$providerUuid',
          )
          .limit(1)
          .maybeSingle();

      if (businessResult != null &&
          businessResult['id'] != null) {
        businessUuid =
            businessResult['id'].toString();
      }
    } catch (e) {
      debugPrint(
        '>>> Business lookup note: $e',
      );
    }

    // ----------------------------------------------------------
    // CREATE REVIEW PAYLOAD
    // ----------------------------------------------------------

    final payload = <String, dynamic>{
      'customer_id': customerUuid,
      'provider_id': providerUuid,
      'rating': rating,
      'created_at':
          DateTime.now().toUtc().toIso8601String(),
    };

    if (jobUuid != null) {
      payload['job_id'] = jobUuid;
    }

    if (bookingUuid != null) {
      payload['booking_id'] = bookingUuid;
    }

    if (businessUuid != null &&
        businessUuid.isNotEmpty) {
      payload['business_id'] = businessUuid;
    }

    if (comment != null &&
        comment.trim().isNotEmpty) {
      payload['comment'] = comment.trim();
    }

    debugPrint(
      '>>> REVIEW PAYLOAD: $payload',
    );

    // ----------------------------------------------------------
    // INSERT
    // ----------------------------------------------------------

    String? reviewId;

    try {
      final result = await _supabase
          .from('reviews')
          .insert(payload)
          .select()
          .single();

      reviewId =
          result['id']?.toString();

      debugPrint(
        '>>> REVIEW INSERT SUCCESS: $reviewId',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '>>> REVIEW INSERT FAILED',
      );
      debugPrint('code: ${e.code}');
      debugPrint('message: ${e.message}');
      debugPrint('details: ${e.details}');
      debugPrint('hint: ${e.hint}');

      // PostgreSQL unique constraint
      // means this customer already reviewed this job.
      if (e.code == '23505') {
        throw Exception(
          'You have already reviewed this service.',
        );
      }

      throw Exception(
        'Unable to submit review: ${e.message}',
      );
    } catch (e) {
      debugPrint(
        '>>> REVIEW INSERT ERROR: $e',
      );
      rethrow;
    }

    // ----------------------------------------------------------
    // PROVIDER NOTIFICATION
    // ----------------------------------------------------------

    try {
      String customerName = 'A customer';

      try {
        final customer =
            await _userRepo.getUser(customerId);

        if (customer != null &&
            customer.name.trim().isNotEmpty) {
          customerName =
              customer.name.trim();
        }
      } catch (_) {}

      await _supabase
          .from('notifications')
          .insert({
        'user_id': providerUuid,
        'title': 'New Review Received',
        'body':
            '$customerName left you a $rating-star review.',
        'type': 'review',
        'data': {
          if (reviewId != null)
            'review_id': reviewId,
          if (jobUuid != null)
            'job_id': jobUuid,
          if (businessUuid != null)
            'business_id': businessUuid,
          'customer_id': customerUuid,
          'provider_id': providerUuid,
          'rating': rating,
        },
        'created_at':
            DateTime.now().toUtc().toIso8601String(),
      });

      debugPrint(
        '>>> Provider review notification created.',
      );
    } catch (e) {
      // Notification failure must NOT make a successful
      // review appear to fail.
      debugPrint(
        '>>> Review notification failed: $e',
      );
    }

    // ----------------------------------------------------------
    // REFRESH PROVIDER RATING
    // ----------------------------------------------------------

    try {
      await _updateProviderAggregateRating(
        providerUuid,
      );
    } catch (e) {
      debugPrint(
        '>>> Provider rating refresh note: $e',
      );
    }

    debugPrint('==============================================');
    debugPrint('>>> REVIEW COMPLETED SUCCESSFULLY');
    debugPrint('==============================================');
  }

  // ============================================================
  // UPDATE PROVIDER AGGREGATE
  // ============================================================

  Future<void> _updateProviderAggregateRating(
    String providerId,
  ) async {
    final providerUuid = _toUuid(providerId);

    if (providerUuid.isEmpty) {
      return;
    }

    final summary =
        await getProviderRatingSummary(providerUuid);

    final average =
        summary['average'] as double;

    final count =
        summary['count'] as int;

    debugPrint(
      '>>> Provider aggregate: '
      'rating=$average count=$count',
    );

    // Update providers table.
    try {
      await _supabase
          .from('providers')
          .update({
        'rating': average,
        'review_count': count,
        'updated_at':
            DateTime.now().toUtc().toIso8601String(),
      })
          .or(
            'id.eq.$providerUuid,'
            'user_id.eq.$providerUuid',
          );
    } catch (e) {
      debugPrint(
        '>>> providers aggregate update error: $e',
      );
    }

    // Update profiles table where those columns exist.
    try {
      await _supabase
          .from('profiles')
          .update({
        'rating': average,
        'review_count': count,
        'updated_at':
            DateTime.now().toUtc().toIso8601String(),
      })
          .or(
            'id.eq.$providerUuid,'
            'firebase_uid.eq.$providerId',
          );
    } catch (e) {
      debugPrint(
        '>>> profiles aggregate update note: $e',
      );
    }
  }

  // ============================================================
  // GET PROVIDER RATING SUMMARY
  // ============================================================

  Future<Map<String, dynamic>>
      getProviderRatingSummary(
    String providerId,
  ) async {
    final reviews =
        await getProviderReviews(providerId);

    if (reviews.isEmpty) {
      return {
        'average': 0.0,
        'count': 0,
      };
    }

    double total = 0;

    for (final review in reviews) {
      total += review.rating;
    }

    final average =
        double.parse(
      (total / reviews.length)
          .toStringAsFixed(1),
    );

    return {
      'average': average,
      'count': reviews.length,
    };
  }

  // ============================================================
  // GET PROVIDER REVIEWS
  // ============================================================

  Future<List<ReviewModel>>
      getProviderReviews(
    String providerId,
  ) async {
    if (providerId.trim().isEmpty) {
      return [];
    }

    final targetUuids = <String>{};

    final directUuid = _toUuid(providerId);

    if (directUuid.isNotEmpty) {
      targetUuids.add(
        directUuid.toLowerCase(),
      );
    }

    // ----------------------------------------------------------
    // Resolve provider/profile UUID
    // ----------------------------------------------------------

    try {
      final convertedUuid =
          _toUuid(providerId);

      final profile = await _supabase
          .from('profiles')
          .select('id')
          .or(
            'id.eq.$convertedUuid,'
            'firebase_uid.eq.$providerId',
          )
          .limit(1)
          .maybeSingle();

      if (profile != null &&
          profile['id'] != null) {
        final profileId =
            profile['id'].toString();

        if (UuidUtils.isValidUuid(profileId)) {
          targetUuids.add(
            profileId.toLowerCase(),
          );
        }
      }
    } catch (e) {
      debugPrint(
        '>>> profile provider lookup note: $e',
      );
    }

    // ----------------------------------------------------------
    // Resolve provider record IDs
    // ----------------------------------------------------------

    try {
      final providerResult =
          await _supabase
              .from('providers')
              .select('id,user_id')
              .or(
                'id.eq.${_toUuid(providerId)},'
                'user_id.eq.${_toUuid(providerId)},'
                'firebase_uid.eq.$providerId,'
                'uid.eq.$providerId',
              );

      for (final row in providerResult) {
        final id =
            row['id']?.toString();

        final userId =
            row['user_id']?.toString();

        if (id != null &&
            UuidUtils.isValidUuid(id)) {
          targetUuids.add(
            id.toLowerCase(),
          );
        }

        if (userId != null &&
            UuidUtils.isValidUuid(userId)) {
          targetUuids.add(
            userId.toLowerCase(),
          );
        }
      }
    } catch (e) {
      debugPrint(
        '>>> provider lookup note: $e',
      );
    }

    // ----------------------------------------------------------
    // DIRECT reviews.provider_id
    // ----------------------------------------------------------

    final rows =
        <String, Map<String, dynamic>>{};

    for (final uuid in targetUuids) {
      try {
        final result =
            await _supabase
                .from('reviews')
                .select()
                .eq('provider_id', uuid)
                .order(
                  'created_at',
                  ascending: false,
                );

        for (final item in result) {
          final map =
              Map<String, dynamic>.from(item);

          final id =
              (map['id'] ?? '').toString();

          if (id.isNotEmpty) {
            rows[id] = map;
          }
        }
      } catch (e) {
        debugPrint(
          '>>> direct provider review lookup: $e',
        );
      }
    }

    // ----------------------------------------------------------
    // JOB ASSIGNMENT FALLBACK
    // ----------------------------------------------------------

    final jobIds = <String>{};

    for (final uuid in targetUuids) {
      try {
        final assignments =
            await _supabase
                .from('job_assignments')
                .select('job_id')
                .or(
                  'technician_id.eq.$uuid,'
                  'provider_id.eq.$uuid',
                );

        for (final assignment in assignments) {
          final jobId =
              assignment['job_id']
                  ?.toString();

          if (jobId != null &&
              UuidUtils.isValidUuid(jobId)) {
            jobIds.add(
              jobId.toLowerCase(),
            );
          }
        }
      } catch (e) {
        debugPrint(
          '>>> assignment lookup note: $e',
        );
      }
    }

    if (jobIds.isNotEmpty) {
      try {
        final result =
            await _supabase
                .from('reviews')
                .select()
                .inFilter(
                  'job_id',
                  jobIds.toList(),
                )
                .order(
                  'created_at',
                  ascending: false,
                );

        for (final item in result) {
          final map =
              Map<String, dynamic>.from(item);

          final id =
              (map['id'] ?? '').toString();

          if (id.isNotEmpty) {
            rows[id] = map;
          }
        }
      } catch (e) {
        debugPrint(
          '>>> job review lookup note: $e',
        );
      }
    }

    // ----------------------------------------------------------
    // BUSINESS FALLBACK
    // ----------------------------------------------------------

    final businessIds = <String>{};

    for (final uuid in targetUuids) {
      try {
        final businesses =
            await _supabase
                .from('businesses')
                .select('id')
                .or(
                  'owner_id.eq.$uuid,'
                  'user_id.eq.$uuid,'
                  'id.eq.$uuid',
                );

        for (final business in businesses) {
          final id =
              business['id']?.toString();

          if (id != null &&
              UuidUtils.isValidUuid(id)) {
            businessIds.add(
              id.toLowerCase(),
            );
          }
        }
      } catch (e) {
        debugPrint(
          '>>> business lookup note: $e',
        );
      }
    }

    if (businessIds.isNotEmpty) {
      try {
        final result =
            await _supabase
                .from('reviews')
                .select()
                .inFilter(
                  'business_id',
                  businessIds.toList(),
                )
                .order(
                  'created_at',
                  ascending: false,
                );

        for (final item in result) {
          final map =
              Map<String, dynamic>.from(item);

          final id =
              (map['id'] ?? '').toString();

          if (id.isNotEmpty) {
            rows[id] = map;
          }
        }
      } catch (e) {
        debugPrint(
          '>>> business review lookup note: $e',
        );
      }
    }

    // ----------------------------------------------------------
    // SORT REVIEWS
    // ----------------------------------------------------------

    final sortedRows =
        rows.values.toList()
          ..sort((a, b) {
            final dateA =
                DateTime.tryParse(
                      a['created_at']
                              ?.toString() ??
                          '',
                    ) ??
                    DateTime(1970);

            final dateB =
                DateTime.tryParse(
                      b['created_at']
                              ?.toString() ??
                          '',
                    ) ??
                    DateTime(1970);

            return dateB.compareTo(dateA);
          });

    // ----------------------------------------------------------
    // ENRICH CUSTOMER DETAILS
    // ----------------------------------------------------------

    final enriched =
        <ReviewModel>[];

    for (final row in sortedRows) {
      final review =
          ReviewModel.fromMap(row);

      String? customerName =
          row['customer_name']
              ?.toString();

      String? customerPhoto =
          row['customer_photo_url']
              ?.toString();

      if (customerName == null ||
          customerName.trim().isEmpty ||
          customerPhoto == null ||
          customerPhoto.trim().isEmpty) {
        try {
          final customer =
              await _userRepo.getUser(
            review.customerId,
          );

          if (customer != null) {
            if (customerName == null ||
                customerName.trim().isEmpty) {
              customerName =
                  customer.name.trim();
            }

            if (customerPhoto == null ||
                customerPhoto.trim().isEmpty) {
              customerPhoto =
                  customer.photoUrl;
            }
          }
        } catch (_) {}
      }

      enriched.add(
        ReviewModel(
          id: review.id,
          customerId:
              review.customerId,
          customerName:
              customerName == null ||
                      customerName.trim().isEmpty
                  ? 'Customer'
                  : customerName,
          customerPhotoUrl:
              customerPhoto,
          jobId:
              review.jobId,
          bookingId:
              review.bookingId,
          businessId:
              review.businessId,
          rating:
              review.rating,
          comment:
              review.comment,
          createdAt:
              review.createdAt,
        ),
      );
    }

    debugPrint(
      '==============================================',
    );
    debugPrint(
      '>>> PROVIDER REVIEW RESULT',
    );
    debugPrint(
      'Provider: $providerId',
    );
    debugPrint(
      'Resolved UUIDs: $targetUuids',
    );
    debugPrint(
      'Jobs found: ${jobIds.length}',
    );
    debugPrint(
      'Reviews found: ${enriched.length}',
    );
    debugPrint(
      '==============================================',
    );

    return enriched;
  }
}