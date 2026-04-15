import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/booking_model.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/highlight_wrapper.dart';

class AdminBookingsScreen extends StatefulWidget {
  final int initialIndex;
  final String? highlightBookingId;
  const AdminBookingsScreen({
    super.key,
    this.initialIndex = 0,
    this.highlightBookingId,
  });

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _firestoreService = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _highlightId;

  @override
  void initState() {
    super.initState();
    _highlightId = widget.highlightBookingId;
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );

    // Clear highlight after initial animation
    if (_highlightId != null) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _highlightId = null);
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 4,
              pinned: true,
              floating: true,
              forceElevated: innerBoxIsScrolled,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F2F31), Color(0xFF184A4C)],
                  ),
                ),
              ),
              title: const Text(
                'Manage Bookings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Clear cancelled bookings',
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () => _confirmAndClearCancelled(context),
                ),
              ],
              bottom: TabBar(
                controller: _tabs,
                indicatorColor: AppTheme.primaryTeal,
                indicatorWeight: 3,
                labelColor: AppTheme.primaryTeal,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Confirmed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),
          ];
        },
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

                final all = (bookingSnap.data ?? [])
                    .where((b) => b.paymentStatus != 'failed')
                    .toList();

                return RefreshIndicator(
                  color: AppTheme.primaryTeal,
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
                        highlightBookingId: _highlightId,
                      ),
                      _BookingList(
                        bookings: all
                            .where((b) => b.status == BookingStatus.confirmed)
                            .toList(),
                        hostels: hostels,
                        firestoreService: _firestoreService,
                        emptyIcon: Icons.check_circle_outline,
                        emptyMessage: 'No confirmed bookings',
                        highlightBookingId: _highlightId,
                      ),
                      _BookingList(
                        bookings: all
                            .where((b) => b.status == BookingStatus.cancelled)
                            .toList(),
                        hostels: hostels,
                        firestoreService: _firestoreService,
                        emptyIcon: Icons.cancel_outlined,
                        emptyMessage: 'No cancelled bookings',
                        highlightBookingId: _highlightId,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
            ),
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
            backgroundColor: AppTheme.primaryTeal,
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
  final String? highlightBookingId;

  const _BookingList({
    required this.bookings,
    required this.hostels,
    required this.firestoreService,
    required this.emptyIcon,
    required this.emptyMessage,
    this.highlightBookingId,
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
          shouldHighlight: highlightBookingId == booking.id,
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
  final bool shouldHighlight;

  const _BookingCard({
    required this.booking,
    required this.hostel,
    required this.firestoreService,
    this.shouldHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return HighlightWrapper(
      shouldHighlight: shouldHighlight,
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.adminBookingDetails,
            arguments: {'bookingId': booking.id},
          );
        },
        child: _buildCard(context),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final checkIn = booking.checkInDate;
    final checkOut = booking.checkOutDate;
    final isFlat = hostel.unitType == 'flat';

    String durationText;
    if (isFlat) {
      // Calculate months for flats
      final totalDays = checkOut.difference(checkIn).inDays;
      final months = (totalDays / 30).ceil();
      durationText = '$months month${months != 1 ? 's' : ''}';
    } else {
      // Calculate years for hostels
      final totalDays = checkOut.difference(checkIn).inDays;
      final years = (totalDays / 365).ceil();
      final displayYears = years > 0 ? years : 1; // Default to 1 if < 1yr
      durationText = '$displayYears year${displayYears != 1 ? 's' : ''}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
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
                _row(
                  isFlat
                      ? Icons.people_outline
                      : Icons.airline_seat_individual_suite_outlined,
                  isFlat ? 'Capacity' : 'Seater',
                  isFlat
                      ? '${booking.flatCapacity ?? hostel.flatCapacity ?? 0} Person'
                      : '${booking.selectedSeater ?? 1} Seater',
                ),
                _row(Icons.calendar_today_outlined, 'Check-in', _fmt(checkIn)),
                _row(
                  Icons.calendar_today_outlined,
                  'Check-out',
                  _fmt(checkOut),
                ),
                _row(Icons.calendar_month_outlined, 'Duration', durationText),
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

                // ── Cancellation Info & Delete ────────────────────
                if (booking.status == BookingStatus.cancelled) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cancelled by ${booking.cancelledBy == 'admin' ? 'Owner' : 'User'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                            if (booking.cancellationReason != null &&
                                booking.cancellationReason!.isNotEmpty)
                              Text(
                                'Reason: ${booking.cancellationReason}',
                                style: TextStyle(
                                  color: AppTheme.darkTeal,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Record'),
                              content: const Text(
                                'Permanently delete this cancelled booking record?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: AppTheme.primaryTeal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await firestoreService.deleteBooking(booking.id);
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.primaryTeal,
                          size: 20,
                        ),
                        tooltip: 'Delete record',
                      ),
                    ],
                  ),
                ],

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
                          color: AppTheme.darkTeal,
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
    final reasonController = TextEditingController();

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
            if (!isConfirm) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
            if (isConfirm && hostel.availableRooms > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
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
                        'Available units: ${hostel.availableRooms} → ${hostel.availableRooms - 1}',
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
                  color: AppTheme.primaryTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_outlined,
                      size: 16,
                      color: AppTheme.primaryTeal,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'No rooms available!',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryTeal,
                      ),
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
              backgroundColor: isConfirm ? Colors.green : AppTheme.primaryTeal,
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
      if (newStatus == BookingStatus.cancelled) {
        await firestoreService.cancelBooking(
          booking.id,
          reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim(),
          'admin',
        );
      } else {
        await firestoreService.updateBookingStatus(booking.id, newStatus);
      }

      // 2. Room management
      if (booking.hostelId.isNotEmpty) {
        // Fetch LATEST hostel data to avoid race conditions/stale counts
        final latestHostel = await firestoreService.getHostel(booking.hostelId);
        if (latestHostel == null) return;

        final isHostel = latestHostel.unitType != 'flat';
        final seater = booking.selectedSeater ?? 1;

        if (isConfirm) {
          // Reduce available rooms when confirmed (always 1 unit)
          final newOverall = (latestHostel.availableRooms - 1).clamp(0, 9999);

          if (isHostel) {
            // Find current count of that specific seater
            int seaterCount = 0;
            if (seater == 1) seaterCount = latestHostel.rooms1Seater;
            if (seater == 2) seaterCount = latestHostel.rooms2Seater;
            if (seater == 3) seaterCount = latestHostel.rooms3Seater;

            final newSeaterCount = (seaterCount - 1).clamp(0, 9999);

            await firestoreService.updateSeaterAvailability(
              hostelId: latestHostel.id,
              overallCount: newOverall,
              seaterType: seater,
              seaterCount: newSeaterCount,
            );
          } else {
            // Flat behavior
            await firestoreService.updateAvailableRooms(
              latestHostel.id,
              newOverall,
            );
          }
        } else if (wasConfirmed) {
          // Restore rooms when a confirmed booking is cancelled (always 1 unit)
          final newOverall = latestHostel.availableRooms + 1;

          if (isHostel) {
            int seaterCount = 0;
            if (seater == 1) seaterCount = latestHostel.rooms1Seater;
            if (seater == 2) seaterCount = latestHostel.rooms2Seater;
            if (seater == 3) seaterCount = latestHostel.rooms3Seater;

            final newSeaterCount = seaterCount + 1;

            await firestoreService.updateSeaterAvailability(
              hostelId: latestHostel.id,
              overallCount: newOverall,
              seaterType: seater,
              seaterCount: newSeaterCount,
            );
          } else {
            // Flat behavior
            await firestoreService.updateAvailableRooms(
              latestHostel.id,
              newOverall,
            );
          }
        }
      }

      // 3. Notify User
      await firestoreService.sendAppNotification(
        recipientId: booking.userId,
        title: isConfirm ? 'Booking Confirmed!' : 'Booking Cancelled',
        body: isConfirm
            ? 'Your booking for ${booking.hostelName} has been confirmed by the owner.'
            : 'Your booking for ${booking.hostelName} was cancelled by the owner.',
        type: 'booking',
        additionalData: {
          'bookingId': booking.id,
          'status': isConfirm ? 'confirmed' : 'cancelled',
        },
      );

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
            backgroundColor: AppTheme.primaryTeal,
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
        bg = Colors.green.withOpacity(0.1);
        icon = Icons.check_circle;
        break;
      case BookingStatus.cancelled:
        fg = AppTheme.darkTeal;
        bg = AppTheme.primaryTeal.withOpacity(0.1);
        icon = Icons.cancel;
        break;
      default:
        fg = Colors.orange[700]!;
        bg = Colors.orange.withOpacity(0.1);
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
