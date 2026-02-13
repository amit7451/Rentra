import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/booking_model.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../services/firestore_service_additions.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _firestoreService = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Manage Bookings'),
        actions: [
          IconButton(
            tooltip: 'Clear cancelled bookings',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmAndClearCancelled(context),
          ),
        ],
        centerTitle: true,
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Confirmed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: StreamBuilder<List<HostelModel>>(
        stream: _firestoreService.getHostelsByOwner(_uid),
        builder: (context, hostelSnap) {
          if (hostelSnap.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading...');
          }

          final hostels = hostelSnap.data ?? [];

          if (hostels.isEmpty) {
            return _emptyState(
              icon: Icons.home_work_outlined,
              message: 'No hostels found.',
              subMessage: 'Add a hostel to start receiving bookings.',
            );
          }

          return StreamBuilder<List<BookingModel>>(
            stream: _firestoreService.getBookingsForOwner(_uid),
            builder: (context, bookingSnap) {
              if (bookingSnap.connectionState == ConnectionState.waiting) {
                return const LoadingIndicator(message: 'Loading bookings...');
              }

              final all = bookingSnap.data ?? [];

              return RefreshIndicator(
                color: AppTheme.primaryRed,
                onRefresh: () async =>
                    await Future.delayed(const Duration(seconds: 1)),
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _BookingList(
                      bookings: all
                          .where((b) => b.status == BookingStatus.pending)
                          .toList(),
                      hostels: hostels,
                      firestoreService: _firestoreService,
                      emptyIcon: Icons.hourglass_empty,
                      emptyMessage: 'No pending bookings',
                    ),
                    _BookingList(
                      bookings: all
                          .where((b) => b.status == BookingStatus.confirmed)
                          .toList(),
                      hostels: hostels,
                      firestoreService: _firestoreService,
                      emptyIcon: Icons.check_circle_outline,
                      emptyMessage: 'No confirmed bookings',
                    ),
                    _BookingList(
                      bookings: all
                          .where((b) => b.status == BookingStatus.cancelled)
                          .toList(),
                      hostels: hostels,
                      firestoreService: _firestoreService,
                      emptyIcon: Icons.cancel_outlined,
                      emptyMessage: 'No cancelled bookings',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmAndClearCancelled(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cancelled Bookings'),
        content: const Text(
          'This will permanently delete all cancelled bookings for your hostels. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('adminId', isEqualTo: _uid)
          .where('status', isEqualTo: BookingStatus.cancelled.name)
          .get();

      if (snapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cancelled bookings to clear.')),
          );
        }
        return;
      }

      final batchCount = snapshot.docs.length;

      for (final doc in snapshot.docs) {
        await _firestoreService.deleteBooking(doc.id);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $batchCount cancelled booking(s).'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cancelled bookings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _emptyState({
    required IconData icon,
    required String message,
    required String subMessage,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 52, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            subMessage,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Booking List ───────────────────────────────────────────────────────────

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final List<HostelModel> hostels;
  final FirestoreService firestoreService;
  final IconData emptyIcon;
  final String emptyMessage;

  const _BookingList({
    required this.bookings,
    required this.hostels,
    required this.firestoreService,
    required this.emptyIcon,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 14),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, i) {
        final booking = bookings[i];
        final hostel = hostels.firstWhere(
          (h) => h.id == booking.hostelId,
          orElse: () => HostelModel.empty(),
        );
        return _BookingCard(
          booking: booking,
          hostel: hostel,
          firestoreService: firestoreService,
        );
      },
    );
  }
}

// ── Booking Card ───────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final HostelModel hostel;
  final FirestoreService firestoreService;

  const _BookingCard({
    required this.booking,
    required this.hostel,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    final checkIn = booking.checkInDate;
    final checkOut = booking.checkOutDate;
    final nights = checkOut.difference(checkIn).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hostel image strip ─────────────────────────────
          if (hostel.images.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Image.network(
                hostel.images.first,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.hostelName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${booking.id.length > 10 ? '${booking.id.substring(0, 10)}…' : booking.id}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(status: booking.status),
                  ],
                ),
                const Divider(height: 20),

                // ── Booking details grid ───────────────────────
                _row(Icons.calendar_today_outlined, 'Check-in', _fmt(checkIn)),
                _row(
                  Icons.calendar_today_outlined,
                  'Check-out',
                  _fmt(checkOut),
                ),
                _row(
                  Icons.nights_stay_outlined,
                  'Duration',
                  '$nights month${nights != 1 ? 's' : ''}',
                ),
                _row(
                  Icons.people_outline,
                  'Guests',
                  '${booking.numberOfGuests}',
                ),
                _row(
                  Icons.currency_rupee,
                  'Total',
                  '₹${booking.totalPrice.toStringAsFixed(0)}',
                ),
                if (booking.specialRequests != null &&
                    booking.specialRequests!.isNotEmpty)
                  _row(
                    Icons.sticky_note_2_outlined,
                    'Note',
                    booking.specialRequests!,
                  ),

                // ── Action Buttons ─────────────────────────────
                if (booking.status == BookingStatus.pending) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _actionBtn(
                          context,
                          label: 'Confirm',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                          onTap: () =>
                              _changeStatus(context, BookingStatus.confirmed),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionBtn(
                          context,
                          label: 'Deny',
                          icon: Icons.cancel_outlined,
                          color: Colors.red[700]!,
                          onTap: () =>
                              _changeStatus(context, BookingStatus.cancelled),
                        ),
                      ),
                    ],
                  ),
                ],

                if (booking.status == BookingStatus.confirmed) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _actionBtn(
                      context,
                      label: 'Cancel Booking',
                      icon: Icons.cancel_outlined,
                      color: Colors.orange[700]!,
                      onTap: () =>
                          _changeStatus(context, BookingStatus.cancelled),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _actionBtn(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    BookingStatus newStatus,
  ) async {
    final isConfirm = newStatus == BookingStatus.confirmed;
    final wasConfirmed = booking.status == BookingStatus.confirmed;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isConfirm ? 'Confirm Booking' : 'Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isConfirm
                  ? 'Confirm this booking for "${booking.hostelName}"?'
                  : 'Cancel this booking? The guest will be notified.',
            ),
            if (isConfirm && hostel.availableRooms > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Available rooms: ${hostel.availableRooms} → ${hostel.availableRooms - booking.numberOfGuests}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isConfirm && hostel.availableRooms <= 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_outlined, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'No rooms available!',
                      style: TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isConfirm ? Colors.green : Colors.red,
            ),
            child: Text(
              isConfirm ? 'Confirm' : 'Yes, Cancel',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // 1. Update booking status
      await firestoreService.updateBookingStatus(booking.id, newStatus);

      // 2. Room management
      if (hostel.id.isNotEmpty) {
        if (isConfirm) {
          // Reduce available rooms when confirmed
          final newCount = (hostel.availableRooms - booking.numberOfGuests)
              .clamp(0, 9999);
          await firestoreService.updateAvailableRooms(hostel.id, newCount);
        } else if (wasConfirmed) {
          // Restore rooms when a confirmed booking is cancelled
          final restored = hostel.availableRooms + booking.numberOfGuests;
          await firestoreService.updateAvailableRooms(hostel.id, restored);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking ${isConfirm ? 'confirmed' : 'cancelled'} successfully',
            ),
            backgroundColor: isConfirm ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ── Status Pill ───────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final BookingStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color fg, bg;
    late final IconData icon;

    switch (status) {
      case BookingStatus.confirmed:
        fg = Colors.green[700]!;
        bg = Colors.green.withValues(alpha: 0.1);
        icon = Icons.check_circle;
        break;
      case BookingStatus.cancelled:
        fg = Colors.red[700]!;
        bg = Colors.red.withValues(alpha: 0.1);
        icon = Icons.cancel;
        break;
      default:
        fg = Colors.orange[700]!;
        bg = Colors.orange.withValues(alpha: 0.1);
        icon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            status.name[0].toUpperCase() + status.name.substring(1),
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
