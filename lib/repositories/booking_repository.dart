import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/uuid_utils.dart';
import '../models/user_model.dart';
import 'notification_repository.dart';
import 'user_repository.dart';
import '../services/push_notification_service.dart';

class BookingRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;
  final UserRepository _userRepo = UserRepository();
  final NotificationRepository _notifRepo = NotificationRepository();

  /// Creates a hire request / job in Supabase.
  Future<void> createHireRequest(Map<String, dynamic> data) async {
    debugPrint('>>> [BookingRepository.createHireRequest] Creating request: $data');

    final clientId = (data['clientId'] ?? data['client_id'] ?? '').toString();
    final providerId = (data['providerId'] ?? data['provider_id'] ?? '').toString();
    final clientUuid = UuidUtils.firebaseUidToUuid(clientId);
    final providerUuid = UuidUtils.firebaseUidToUuid(providerId);

    // Self-hire protection: customer cannot hire themselves
    if (clientUuid.isNotEmpty && providerUuid.isNotEmpty && clientUuid == providerUuid) {
      throw Exception('You cannot hire yourself.');
    }
    if (clientId.isNotEmpty && providerId.isNotEmpty && clientId == providerId) {
      throw Exception('You cannot hire yourself.');
    }

    final clientName = (data['clientName'] ?? data['client_name'] ?? '').toString();
    final serviceNeeded = (data['serviceNeeded'] ?? data['service_needed'] ?? data['title'] ?? 'Service Request').toString();
    final location = (data['location'] ?? data['address'] ?? '').toString();
    final notes = (data['notes'] ?? data['description'] ?? '').toString();
    final status = (data['status'] ?? 'requested').toString();
    final date = data['requestedDate'] ?? data['requested_date'];
    final preferredTime = (data['preferredTime'] ?? data['preferred_time'] ?? '').toString();
    final budgetRaw = data['estimatedBudget'] ?? data['estimated_budget'] ?? data['budget'];
    final budget = budgetRaw == null ? null : num.tryParse(budgetRaw.toString());

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final requestedDateIso = date == null
        ? null
        : (date is DateTime ? date.toUtc().toIso8601String() : date.toString());

    String? generatedJobId;

    // 1. Insert into jobs table
    final jobPayload = {
      'customer_id': clientUuid,
      'title': serviceNeeded,
      'description': notes.isNotEmpty ? notes : serviceNeeded,
      'status': status,
      'address': location,
      'city': location,
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    try {
      final jobRes = await _supabase.from('jobs').insert(jobPayload).select();
      if (jobRes.isNotEmpty) {
        final jobId = jobRes.first['id'];
        generatedJobId = jobId?.toString();
        debugPrint('>>> [BookingRepository] Inserted into jobs table with ID: $jobId');

        try {
          await _supabase.from('job_assignments').insert({
            'job_id': jobId,
            'technician_id': providerUuid,
            'status': 'assigned',
            'assigned_at': nowIso,
          });
          debugPrint('>>> [BookingRepository] Inserted into job_assignments table SUCCESS');
        } catch (e) {
          debugPrint('>>> [BookingRepository] job_assignments insert note: $e');
        }
      }
    } catch (e) {
      debugPrint('>>> [BookingRepository] jobs table insert note: $e');
    }

    // 2. Also insert into bookings / hire_requests table.
    final bookingPayload = {
      'client_id': clientUuid,
      'client_name': clientName,
      'client_phone': data['clientPhone'] ?? data['client_phone'] ?? '',
      'provider_id': providerUuid,
      'provider_name': data['providerName'] ?? data['provider_name'] ?? '',
      'service_needed': serviceNeeded,
      'description': notes,
      'location': location,
      'notes': notes,
      'status': status,
      if (requestedDateIso != null) 'requested_date': requestedDateIso,
      if (preferredTime.isNotEmpty) 'preferred_time': preferredTime,
      if (budget != null) 'estimated_budget': budget,
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    String? generatedBookingId;
    try {
      final bRes = await _supabase.from('bookings').insert(bookingPayload).select();
      if (bRes.isNotEmpty) {
        generatedBookingId = bRes.first['id']?.toString();
      }
      debugPrint('>>> [BookingRepository] Inserted into bookings table SUCCESS');
    } catch (e) {
      debugPrint('>>> [BookingRepository] bookings table note: $e');
      try {
        final hRes = await _supabase.from('hire_requests').insert(bookingPayload).select();
        if (hRes.isNotEmpty) {
          generatedBookingId = hRes.first['id']?.toString();
        }
        debugPrint('>>> [BookingRepository] Inserted into hire_requests fallback SUCCESS');
      } catch (e2) {
        debugPrint('>>> [BookingRepository] hire_requests table note: $e2');
      }
    }

    // 3. Notify provider of new hire request (Phase 33 & FCM)
    try {
      String customerDisplayName = clientName.trim();
      if (customerDisplayName.isEmpty) {
        final custUser = await _userRepo.getUser(clientId);
        if (custUser != null && custUser.name.trim().isNotEmpty) {
          customerDisplayName = custUser.name.trim();
        } else {
          customerDisplayName = 'A customer';
        }
      }

      final notifTitle = 'New Hire Request';
      final notifBody = '$customerDisplayName sent you a service request for $serviceNeeded.';

      await _notifRepo.createNotification(
        userId: providerId,
        title: notifTitle,
        body: notifBody,
        type: 'hire_request',
        data: {
          'request_id': generatedBookingId ?? generatedJobId ?? '',
          'job_id': generatedJobId ?? '',
          'customer_id': clientUuid,
          'provider_id': providerUuid,
        },
      );

      // Trigger FCM push notification to provider's active devices
      await PushNotificationService().sendPushNotificationToUser(
        recipientUserId: providerId,
        senderUserId: clientId,
        senderName: customerDisplayName,
        title: notifTitle,
        body: notifBody,
        type: 'hire_request',
        requestId: generatedBookingId ?? generatedJobId,
        jobId: generatedJobId,
        bookingId: generatedBookingId,
        extraData: {
          'customer_id': clientUuid,
          'provider_id': providerUuid,
          'service_needed': serviceNeeded,
        },
      );
    } catch (e) {
      debugPrint('>>> [BookingRepository.createHireRequest] Notification note (non-fatal): $e');
    }
  }

  /// Updates status for a job, job_assignment, booking, or hire_request
  /// and sends appropriate notifications (Phase 33 & FCM).
  Future<void> updateStatus(
    String requestId,
    String status, {
    String? currentUserId,
    bool isProviderUpdating = false,
  }) async {
    debugPrint('>>> [BookingRepository.updateStatus] Updating request $requestId to $status');
    final nowIso = DateTime.now().toUtc().toIso8601String();

    Map<String, dynamic>? requestRecord;

    // Look up request details to identify customer & provider for notifications
    try {
      requestRecord = await _supabase.from('bookings').select().eq('id', requestId).maybeSingle();
      requestRecord ??= await _supabase.from('hire_requests').select().eq('id', requestId).maybeSingle();
      requestRecord ??= await _supabase.from('jobs').select().eq('id', requestId).maybeSingle();
    } catch (_) {}

    try {
      await _supabase
          .from('bookings')
          .update({'status': status, 'updated_at': nowIso})
          .eq('id', requestId);
    } catch (_) {}

    try {
      await _supabase
          .from('hire_requests')
          .update({'status': status, 'updated_at': nowIso})
          .eq('id', requestId);
    } catch (_) {}

    try {
      await _supabase
          .from('jobs')
          .update({'status': status, 'updated_at': nowIso})
          .eq('id', requestId);
    } catch (_) {}

    try {
      final assignmentRes = await _supabase
          .from('job_assignments')
          .update({'status': status})
          .eq('id', requestId)
          .select();
      if (assignmentRes.isNotEmpty) {
        final jobId = assignmentRes.first['job_id'];
        if (jobId != null) {
          try {
            await _supabase
                .from('jobs')
                .update({'status': status, 'updated_at': nowIso})
                .eq('id', jobId);
          } catch (_) {}
        }
      }
    } catch (_) {}

    // Send notifications based on status transition (Phase 33 & FCM)
    if (requestRecord != null) {
      final clientId = (requestRecord['client_id'] ?? requestRecord['customer_id'] ?? '').toString();
      final providerId = (requestRecord['provider_id'] ?? '').toString();
      final providerName = (requestRecord['provider_name'] ?? 'Provider').toString();
      final clientName = (requestRecord['client_name'] ?? 'Customer').toString();

      if (status == 'accepted' && clientId.isNotEmpty) {
        // Customer notification: Provider accepted request
        final notifTitle = 'Request Accepted';
        final notifBody = '$providerName accepted your service request.';

        try {
          await _notifRepo.createNotification(
            userId: clientId,
            title: notifTitle,
            body: notifBody,
            type: 'hire_accepted',
            data: {
              'request_id': requestId,
              'provider_id': providerId,
              'customer_id': clientId,
            },
          );

          await PushNotificationService().sendPushNotificationToUser(
            recipientUserId: clientId,
            senderUserId: providerId,
            senderName: providerName,
            title: notifTitle,
            body: notifBody,
            type: 'hire_accepted',
            requestId: requestId,
            extraData: {
              'provider_id': providerId,
              'customer_id': clientId,
            },
          );
        } catch (e) {
          debugPrint('>>> [BookingRepository.updateStatus] accepted notif note (non-fatal): $e');
        }
      } else if ((status == 'cancelled' || status == 'declined' || status == 'rejected') && isProviderUpdating && clientId.isNotEmpty) {
        // Customer notification: Provider declined / rejected request
        final notifTitle = 'Request Declined';
        final notifBody = '$providerName declined your service request.';

        try {
          await _notifRepo.createNotification(
            userId: clientId,
            title: notifTitle,
            body: notifBody,
            type: 'hire_rejected',
            data: {
              'request_id': requestId,
              'provider_id': providerId,
              'customer_id': clientId,
            },
          );

          await PushNotificationService().sendPushNotificationToUser(
            recipientUserId: clientId,
            senderUserId: providerId,
            senderName: providerName,
            title: notifTitle,
            body: notifBody,
            type: 'hire_rejected',
            requestId: requestId,
            extraData: {
              'provider_id': providerId,
              'customer_id': clientId,
            },
          );
        } catch (e) {
          debugPrint('>>> [BookingRepository.updateStatus] declined notif note (non-fatal): $e');
        }
      } else if ((status == 'cancelled' || status == 'declined') && !isProviderUpdating && providerId.isNotEmpty) {
        // Provider notification: Customer cancelled request
        final notifTitle = 'Request Cancelled';
        final notifBody = '$clientName cancelled the service request.';

        try {
          await _notifRepo.createNotification(
            userId: providerId,
            title: notifTitle,
            body: notifBody,
            type: 'hire_cancelled',
            data: {
              'request_id': requestId,
              'provider_id': providerId,
              'customer_id': clientId,
            },
          );

          await PushNotificationService().sendPushNotificationToUser(
            recipientUserId: providerId,
            senderUserId: clientId,
            senderName: clientName,
            title: notifTitle,
            body: notifBody,
            type: 'hire_cancelled',
            requestId: requestId,
            extraData: {
              'provider_id': providerId,
              'customer_id': clientId,
            },
          );
        } catch (e) {
          debugPrint('>>> [BookingRepository.updateStatus] cancelled notif note (non-fatal): $e');
        }
      }
    }
  }

  /// Fetch requests created by a client.
  Future<List<Map<String, dynamic>>> getClientRequests(String clientId) async {
    final clientUuid = UuidUtils.firebaseUidToUuid(clientId);
    final List<Map<String, dynamic>> results = [];
    final Set<String> seenIds = {};

    try {
      final res = await _supabase
          .from('bookings')
          .select()
          .eq('client_id', clientUuid)
          .order('created_at', ascending: false);
      for (final item in res) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          results.add({...Map<String, dynamic>.from(item), 'source_table': 'bookings'});
        }
      }
    } catch (e) {
      debugPrint('>>> [BookingRepository.getClientRequests] bookings query error: $e');
    }

    try {
      final res = await _supabase
          .from('hire_requests')
          .select()
          .eq('client_id', clientUuid)
          .order('created_at', ascending: false);
      for (final item in res) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          results.add({...Map<String, dynamic>.from(item), 'source_table': 'hire_requests'});
        }
      }
    } catch (e) {
      debugPrint('>>> [BookingRepository.getClientRequests] hire_requests query error: $e');
    }

    try {
      final res = await _supabase
          .from('jobs')
          .select()
          .eq('customer_id', clientUuid)
          .order('created_at', ascending: false);
      for (final item in res) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty && !seenIds.contains(id)) {
          // Resolve provider_id from job_assignments (technician_id is canonical)
          String? resolvedProviderId;
          try {
            final assignments = await _supabase
                .from('job_assignments')
                .select('technician_id, provider_id')
                .eq('job_id', id)
                .limit(1);
            if (assignments.isNotEmpty) {
              final a = assignments.first;
              resolvedProviderId = (a['technician_id'] ?? a['provider_id'] ?? '').toString();
              if (resolvedProviderId.isEmpty) resolvedProviderId = null;
            }
          } catch (_) {}

          seenIds.add(id);
          results.add({
            'id': item['id'],
            'source_table': 'jobs',
            'client_id': clientUuid,
            'client_name': 'Me',
            'provider_id': resolvedProviderId ?? '',
            'service_needed': item['title'] ?? 'Service',
            'location': item['address'] ?? item['city'] ?? '',
            'notes': item['description'] ?? '',
            'status': item['status'] ?? 'requested',
            'created_at': item['created_at'],
            'updated_at': item['updated_at'],
          });
        }
      }
    } catch (e) {
      debugPrint('>>> [BookingRepository.getClientRequests] jobs query error: $e');
    }

    results.sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return db.compareTo(da);
    });

    return results;
  }

  /// Fetch service requests received by a provider (from bookings, hire_requests, and job_assignments/jobs).
  Future<List<Map<String, dynamic>>> getProviderRequests(String providerId) async {
    final providerUuid = UuidUtils.firebaseUidToUuid(providerId);
    final List<Map<String, dynamic>> results = [];
    final Set<String> seenIds = {};

    try {
      final res = await _supabase
          .from('bookings')
          .select()
          .eq('provider_id', providerUuid)
          .order('created_at', ascending: false);
      for (final item in res) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          results.add(Map<String, dynamic>.from(item));
        }
      }
    } catch (e) {
      debugPrint('>>> [BookingRepository.getProviderRequests] bookings query error: $e');
    }

    try {
      final res = await _supabase
          .from('hire_requests')
          .select()
          .eq('provider_id', providerUuid)
          .order('created_at', ascending: false);
      for (final item in res) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          results.add(Map<String, dynamic>.from(item));
        }
      }
    } catch (e) {
      debugPrint('>>> [BookingRepository.getProviderRequests] hire_requests query error: $e');
    }

    try {
      final assignments = await _supabase
          .from('job_assignments')
          .select()
          .eq('technician_id', providerUuid)
          .order('created_at', ascending: false);

      final validAssignments = assignments.where((a) {
        final id = (a['id'] ?? '').toString();
        return id.isNotEmpty && !seenIds.contains(id) && a['job_id'] != null;
      }).toList();

      if (validAssignments.isNotEmpty) {
        final jobIds = validAssignments.map((a) => a['job_id'].toString()).toSet().toList();
        final Map<String, Map<String, dynamic>> jobsMap = {};

        try {
          final jobsData = await _supabase
              .from('jobs')
              .select()
              .filter('id', 'in', jobIds);
          for (final j in jobsData) {
            jobsMap[j['id'].toString()] = Map<String, dynamic>.from(j);
          }
        } catch (e) {
          debugPrint('>>> [BookingRepository.getProviderRequests] batch jobs lookup note: $e');
        }

        // Parallelize customer profile fetches
        final customerIds = jobsMap.values
            .map((j) => (j['customer_id'] ?? '').toString())
            .where((cid) => cid.isNotEmpty)
            .toSet();

        final Map<String, UserModel?> customerMap = {};
        await Future.wait(customerIds.map((cid) async {
          try {
            final u = await _userRepo.getUser(cid);
            customerMap[cid] = u;
          } catch (_) {}
        }));

        for (final assignment in validAssignments) {
          final assignmentId = (assignment['id'] ?? '').toString();
          final jobId = assignment['job_id']?.toString();
          final job = jobsMap[jobId];
          if (job == null) continue;

          final customerId = (job['customer_id'] ?? '').toString();
          final customer = customerMap[customerId];
          final clientName = customer != null && customer.name.isNotEmpty
              ? customer.name
              : 'Customer';
          final clientPhone = customer?.phone ?? '';

          seenIds.add(assignmentId);
          results.add({
            'id': assignmentId,
            'client_id': customerId,
            'client_name': clientName,
            'client_phone': clientPhone,
            'provider_id': providerUuid,
            'service_needed': job['title'] ?? 'Service',
            'location': job['address'] ?? job['city'] ?? '',
            'notes': job['description'] ?? '',
            'status': assignment['status'] ?? job['status'] ?? 'requested',
            'created_at': assignment['created_at'] ?? job['created_at'],
            'updated_at': job['updated_at'],
          });
        }
      }
    } catch (e) {
      debugPrint('>>> [BookingRepository.getProviderRequests] job_assignments query error: $e');
    }

    results.sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return db.compareTo(da);
    });

    return results;
  }
}