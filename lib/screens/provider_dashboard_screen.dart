import 'package:findipro/models/booking_model.dart';
import 'package:findipro/models/notification_model.dart';
import 'package:findipro/repositories/booking_repository.dart';
import 'package:findipro/repositories/notification_repository.dart';
import 'package:findipro/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final bookingRepo = context.read<BookingRepository>();
    final notificationRepo = context.read<NotificationRepository>();
    final uid = authService.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Authentication error.")));
    }

    void updateBookingStatus(BookingModel booking, BookingStatus newStatus, String notificationTitle) {
      bookingRepo.updateBookingStatus(booking.id, newStatus);
      notificationRepo.createNotification(
        recipientId: booking.clientId,
        senderId: uid,
        type: NotificationType.bookingChanged,
        title: notificationTitle,
        body: 'Your request for "${booking.serviceNeeded}" has been updated.',
        referenceId: booking.id,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<BookingModel>>(
        stream: bookingRepo.getProviderBookingsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no incoming requests.'));
          }

          final bookings = snapshot.data!;

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.serviceNeeded, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('From Client: ${booking.clientId.substring(0, 6)}...'), // Placeholder for client name
                      const SizedBox(height: 4),
                      Text('Notes: ${booking.notes}'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status:', style: Theme.of(context).textTheme.bodyMedium),
                          Chip(
                            label: Text(booking.status.name),
                            backgroundColor: Colors.blueGrey,
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildActionButtons(context, booking, updateBookingStatus),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, BookingModel booking, Function(BookingModel, BookingStatus, String) updateStatus) {
    switch (booking.status) {
      case BookingStatus.pending:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => updateStatus(booking, BookingStatus.declined, 'Request Declined'),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Decline'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => updateStatus(booking, BookingStatus.accepted, 'Request Accepted'),
              child: const Text('Accept'),
            ),
          ],
        );
      case BookingStatus.accepted:
        return ElevatedButton(
          onPressed: () => updateStatus(booking, BookingStatus.inProgress, 'Service Started'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
          child: const Text('Start Service'),
        );
      case BookingStatus.inProgress:
        return ElevatedButton(
          onPressed: () => updateStatus(booking, BookingStatus.providerCompleted, 'Service Finished'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            minimumSize: const Size(double.infinity, 36),
          ),
          child: const Text('Mark as Complete'),
        );
      case BookingStatus.providerCompleted:
      case BookingStatus.clientConfirmed:
      case BookingStatus.declined:
      case BookingStatus.cancelled:
        return Align(
          alignment: Alignment.centerRight,
          child: Text('No actions available', style: Theme.of(context).textTheme.bodySmall),
        );
    }
  }
}