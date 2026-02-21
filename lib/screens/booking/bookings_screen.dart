import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/booking_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_text.dart';
import '../../widgets/highlight_wrapper.dart';

class BookingsScreen extends StatefulWidget {
  final String? highlightBookingId;
  const BookingsScreen({super.key, this.highlightBookingId});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String? _highlightId;

  @override
  void initState() {
    super.initState();
    _highlightId = widget.highlightBookingId;

    if (_highlightId != null) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _highlightId = null);
      });
    }
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.cancelled:
        return AppTheme.darkRed;
      case BookingStatus.completed:
        return Colors.blue;
    }
  }

  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.completed:
        return 'Completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view bookings')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            elevation: 0,
            scrolledUnderElevation: 4,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            backgroundColor: Colors.grey[50],
            centerTitle: true,
            title: const Text(
              'My Bookings',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          StreamBuilder<List<BookingModel>>(
            stream: firestoreService.getUserBookings(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: LoadingIndicator(message: 'Loading bookings...'),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: ErrorText(
                    message: 'Error loading bookings: ${snapshot.error}',
                    onRetry: () {},
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.book_outlined,
                          size: 64,
                          color: AppTheme.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bookings yet',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start exploring hostels!',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final bookings = snapshot.data!;

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final booking = bookings[index];
                    return _buildBookingCard(
                      context,
                      booking,
                      firestoreService,
                      shouldHighlight: _highlightId == booking.id,
                    );
                  }, childCount: bookings.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(
    BuildContext context,
    BookingModel booking,
    FirestoreService firestoreService, {
    bool shouldHighlight = false,
  }) {
    return HighlightWrapper(
      shouldHighlight: shouldHighlight,
      borderRadius: 12, // Card default radius
      child: _buildCardContent(context, booking, firestoreService),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    BookingModel booking,
    FirestoreService firestoreService,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.paymentStatus,
          arguments: {
            'bookingId': booking.id,
            'status': booking.paymentStatus == 'successful'
                ? 'success'
                : 'failed',
            'hostelId': booking.hostelId,
          },
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hostel name and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      booking.hostelName,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (booking.paymentStatus == 'failed'
                                  ? Colors.red
                                  : _getStatusColor(booking.status))
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      booking.paymentStatus == 'failed'
                          ? 'Payment Failed'
                          : _getStatusText(booking.status),
                      style: TextStyle(
                        color: booking.paymentStatus == 'failed'
                            ? Colors.red
                            : _getStatusColor(booking.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Check-in and check-out
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start date',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: AppTheme.primaryRed,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${booking.checkInDate.day}/${booking.checkInDate.month}/${booking.checkInDate.year}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End date',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: AppTheme.primaryRed,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${booking.checkOutDate.day}/${booking.checkOutDate.month}/${booking.checkOutDate.year}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Seater/Capacity and nights
              Row(
                children: [
                  Icon(
                    booking.selectedSeater == 0
                        ? Icons.home_work_outlined
                        : Icons.airline_seat_individual_suite_outlined,
                    size: 16,
                    color: AppTheme.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    booking.selectedSeater == 0
                        ? (booking.flatCapacity != null
                              ? 'Flat (Capacity: ${booking.flatCapacity})'
                              : 'Flat')
                        : '${booking.selectedSeater} Seater',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),

              const Divider(height: 24),

              // Total price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Booking Price',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    '₹${booking.totalPrice.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Cancel button (only for pending/confirmed bookings)
              if (booking.status == BookingStatus.pending ||
                  booking.status == BookingStatus.confirmed) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      _showCancelDialog(context, booking, firestoreService);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.darkRed,
                      side: const BorderSide(color: AppTheme.darkRed),
                    ),
                    child: const Text('Cancel Booking'),
                  ),
                ),
              ],

              // Cancellation info and Delete button
              if (booking.status == BookingStatus.cancelled) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cancelled by ${booking.cancelledBy == 'admin' ? 'Owner' : 'You'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.red,
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Record'),
                                  content: const Text(
                                    'Remove this cancelled booking from your list?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await firestoreService.deleteBooking(
                                  booking.id,
                                );
                              }
                            },
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      if (booking.cancellationReason != null &&
                          booking.cancellationReason!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Reason: ${booking.cancellationReason}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.red[800],
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(
    BuildContext context,
    BookingModel booking,
    FirestoreService firestoreService,
  ) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this booking?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                hintText: 'Optional',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final wasConfirmed = booking.status == BookingStatus.confirmed;

                // 1. Update status
                await firestoreService.cancelBooking(
                  booking.id,
                  reasonController.text.trim().isEmpty
                      ? null
                      : reasonController.text.trim(),
                  'user',
                );

                // 1.1 Notify Admin
                await firestoreService.sendAppNotification(
                  recipientId: booking.adminId,
                  title: 'Booking Cancelled 🔴',
                  body:
                      'The user has cancelled their booking for ${booking.hostelName}.',
                  type: 'booking',
                  additionalData: {
                    'bookingId': booking.id,
                    'status': 'cancelled',
                  },
                );

                // 2. Restore room if it was confirmed
                if (wasConfirmed) {
                  final hostel = await firestoreService.getHostel(
                    booking.hostelId,
                  );
                  if (hostel != null) {
                    final newOverall = hostel.availableRooms + 1;
                    final isHostel = hostel.unitType != 'flat';
                    final seater = booking.selectedSeater ?? 1;

                    if (isHostel) {
                      int seaterCount = 0;
                      if (seater == 1) seaterCount = hostel.rooms1Seater;
                      if (seater == 2) seaterCount = hostel.rooms2Seater;
                      if (seater == 3) seaterCount = hostel.rooms3Seater;

                      await firestoreService.updateSeaterAvailability(
                        hostelId: hostel.id,
                        overallCount: newOverall,
                        seaterType: seater,
                        seaterCount: seaterCount + 1,
                      );
                    } else {
                      await firestoreService.updateAvailableRooms(
                        hostel.id,
                        newOverall,
                      );
                    }
                  }
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Booking cancelled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel booking: $e'),
                      backgroundColor: AppTheme.darkRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}
