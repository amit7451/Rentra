import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/booking_model.dart';
import '../../models/hostel_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../app/theme.dart';

class AdminBookingDetailsScreen extends StatefulWidget {
  final String bookingId;

  const AdminBookingDetailsScreen({super.key, required this.bookingId});

  @override
  State<AdminBookingDetailsScreen> createState() =>
      _AdminBookingDetailsScreenState();
}

class _AdminBookingDetailsScreenState extends State<AdminBookingDetailsScreen> {
  final _firestoreService = FirestoreService();
  bool _isLoading = true;
  BookingModel? _booking;
  HostelModel? _hostel;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final b = await _firestoreService.getBooking(widget.bookingId);
      if (b != null) {
        final h = await _firestoreService.getHostel(b.hostelId);
        final u = await _firestoreService.getUser(b.userId);
        if (mounted) {
          setState(() {
            _booking = b;
            _hostel = h;
            _user = u;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching admin booking details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _launchUrl(String uri) async {
    final parsed = Uri.parse(uri);
    if (await canLaunchUrl(parsed)) {
      await launchUrl(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryTeal),
        ),
      );
    }

    if (_booking == null || _hostel == null || _user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: Text('Booking details not found.')),
      );
    }

    final isFlat = _hostel!.unitType == 'flat';
    String durationText;
    if (isFlat) {
      final totalDays = _booking!.checkOutDate
          .difference(_booking!.checkInDate)
          .inDays;
      final months = (totalDays / 30).ceil();
      durationText = '$months month${months != 1 ? 's' : ''}';
    } else {
      final totalDays = _booking!.checkOutDate
          .difference(_booking!.checkInDate)
          .inDays;
      final years = (totalDays / 365).ceil();
      final displayYears = years > 0 ? years : 1;
      durationText = '$displayYears year${displayYears != 1 ? 's' : ''}';
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: Colors.grey[50],
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: _getStatusColor(_booking!.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(_booking!.status),
                    color: _getStatusColor(_booking!.status),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getStatusText(_booking!.status),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(_booking!.status),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Booking ID: ${_booking!.id}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Property Info
            Text(
              'Property Information',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hostel!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hostel!.address,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const Divider(height: 24),
                    _detailRow('Unit Type', isFlat ? 'Flat' : 'Hostel / PG'),
                    _detailRow(
                      isFlat ? 'Capacity' : 'Selected Seater',
                      isFlat
                          ? '${_booking!.flatCapacity ?? _hostel!.flatCapacity ?? 0} Person'
                          : '${_booking!.selectedSeater ?? 1} Seater',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Booking Breakdown
            Text(
              'Booking Breakdown',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _detailRow('Check-in Date', _fmt(_booking!.checkInDate)),
                    _detailRow('Check-out Date', _fmt(_booking!.checkOutDate)),
                    _detailRow('Duration', durationText),
                    _detailRow(
                      'Payment Processed',
                      _fmt(_booking!.bookingDate),
                    ),
                    _detailRow(
                      'Booking Fee Paid',
                      '₹${_booking!.bookingFee?.toStringAsFixed(0) ?? '0'}',
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Rent',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${_booking!.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Guest Info (Only show if confirmed, or just basic name otherwise)
            Text(
              'Guest Information',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                          backgroundImage:
                              (_user!.photoUrl?.isNotEmpty ?? false)
                              ? NetworkImage(_user!.photoUrl!)
                              : null,
                          child: (_user!.photoUrl?.isEmpty ?? true)
                              ? const Icon(
                                  Icons.person,
                                  color: AppTheme.primaryTeal,
                                  size: 24,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user!.name.isNotEmpty
                                    ? _user!.name
                                    : 'Guest User',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_booking!.specialRequests?.isNotEmpty ??
                                  false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Note: "${_booking!.specialRequests}"',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_booking!.status == BookingStatus.confirmed) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (_user!.phoneNumber?.isNotEmpty ?? false) {
                                  _launchUrl('tel:${_user!.phoneNumber}');
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.phone,
                                      size: 18,
                                      color: AppTheme.primaryTeal,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      (_user!.phoneNumber?.isNotEmpty ?? false)
                                          ? 'Call'
                                          : 'No Phone',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (_user!.email.isNotEmpty) {
                                  _launchUrl('mailto:${_user!.email}');
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.email,
                                      size: 18,
                                      color: AppTheme.primaryTeal,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Email',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Contact details will be visible after confirming the booking.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ACTION BUTTONS (Only if pending)
            if (_booking!.status == BookingStatus.pending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryTeal,
                        side: const BorderSide(color: AppTheme.primaryTeal),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () =>
                          _updateBookingStatus(BookingStatus.cancelled),
                      child: const Text(
                        'Deny',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () =>
                          _updateBookingStatus(BookingStatus.confirmed),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _updateBookingStatus(BookingStatus newStatus) async {
    try {
      await _firestoreService.updateBookingStatus(_booking!.id, newStatus);

      // Send notification to user
      await _firestoreService.sendAppNotification(
        recipientId: _booking!.userId,
        title: newStatus == BookingStatus.confirmed
            ? 'Booking Confirmed! 🎉'
            : 'Booking Cancelled ❌',
        body: newStatus == BookingStatus.confirmed
            ? 'Your booking at ${_booking!.hostelName} has been confirmed securely.'
            : 'Your booking at ${_booking!.hostelName} was cancelled by the owner.',
        type: 'booking',
        additionalData: {'bookingId': _booking!.id, 'status': newStatus.name},
      );

      if (mounted) {
        setState(() {
          _booking = BookingModel(
            id: _booking!.id,
            userId: _booking!.userId,
            hostelId: _booking!.hostelId,
            hostelName: _booking!.hostelName,
            adminId: _booking!.adminId,
            checkInDate: _booking!.checkInDate,
            checkOutDate: _booking!.checkOutDate,
            numberOfGuests: _booking!.numberOfGuests,
            totalPrice: _booking!.totalPrice,
            status: newStatus,
            bookingDate: _booking!.bookingDate,
            specialRequests: _booking!.specialRequests,
            cancellationReason: _booking!.cancellationReason,
            cancelledBy: _booking!.cancelledBy,
            selectedSeater: _booking!.selectedSeater,
            flatCapacity: _booking!.flatCapacity,
            paymentStatus: _booking!.paymentStatus,
            bookingFee: _booking!.bookingFee,
            razorpayOrderId: _booking!.razorpayOrderId,
            razorpayPaymentId: _booking!.razorpayPaymentId,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == BookingStatus.confirmed
                  ? 'Booking Confirmed'
                  : 'Booking Cancelled',
            ),
            backgroundColor: newStatus == BookingStatus.confirmed
                ? Colors.green
                : AppTheme.primaryTeal,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.cancelled:
        return AppTheme.primaryTeal;
      case BookingStatus.completed:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.hourglass_top;
      case BookingStatus.confirmed:
        return Icons.check_circle_outline;
      case BookingStatus.cancelled:
        return Icons.cancel_outlined;
      case BookingStatus.completed:
        return Icons.task_alt;
    }
  }

  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending Confirmation';
      case BookingStatus.confirmed:
        return 'Booking Confirmed';
      case BookingStatus.cancelled:
        return 'Booking Cancelled';
      case BookingStatus.completed:
        return 'Booking Completed';
    }
  }
}
