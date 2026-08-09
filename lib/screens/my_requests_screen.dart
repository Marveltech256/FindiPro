import 'package:findipro/models/booking_model.dart';
import 'package:findipro/models/notification_model.dart';
import 'package:findipro/repositories/booking_repository.dart';
import 'package:findipro/repositories/notification_repository.dart';
import 'package:findipro/screens/login_screen.dart';
import 'package:findipro/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A screen that displays a list of booking requests made by the authenticated client.
class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final bookingRepo = context.read<BookingRepository>();
    final notificationRepo = context.read<NotificationRepository>();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
      ),
      body: uid == null // If user is not authenticated
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('You must be logged in to see your requests.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
                      },
                      child: const Text('Login to View Requests'),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<List<BookingModel>>(
              stream: bookingRepo.getClientBookingsStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('You have no active requests.', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  );
                }

                final bookings = snapshot.data!;

                return ListView.separated(
                  itemCount: bookings.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    // A real implementation would fetch the provider's user document for the name.
                    // For now, we use a placeholder.
                    final providerName = 'Provider ${booking.providerId.substring(0, 6)}...';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(booking.serviceNeeded, style: Theme.of(context).textTheme.titleLarge),
                              subtitle: Text('With $providerName'),
                              trailing: Chip(
                                label: Text(booking.status.name.toUpperCase()),
                                backgroundColor: _getStatusColor(booking.status),
                                labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                            if (booking.status == BookingStatus.providerCompleted)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    bookingRepo.updateBookingStatus(booking.id, BookingStatus.clientConfirmed); // Update to clientConfirmed
                                    // For now, we just acknowledge.
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Thank you for confirming!')),
                                    );
                                    // Optionally, notify the provider
                                    notificationRepo.createNotification(
                                      recipientId: booking.providerId,
                                      senderId: uid,
                                      type: NotificationType.serviceCompleted,
                                      title: "Service Confirmed",
                                      body: "The client has confirmed completion of your service.",
                                      referenceId: booking.id,
                                    );
                                  },
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Confirm Completion'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    minimumSize: const Size(double.infinity, 40),
                                  ),
                                ),
                              )
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

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
        return Colors.green;
      case BookingStatus.declined:
        return Colors.red;
      case BookingStatus.inProgress:
        return Colors.blueAccent;
      case BookingStatus.providerCompleted:
        return Colors.purple;
      case BookingStatus.clientConfirmed:
        return Colors.blue;
      case BookingStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}