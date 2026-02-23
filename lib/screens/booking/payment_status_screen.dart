import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/booking_model.dart';
import '../../models/user_model.dart';
import '../../models/hostel_model.dart'; // Added HostelModel strictly
import '../../services/firestore_service.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/primary_button.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String? bookingId;
  final String status; // 'success' or 'failed'
  final String hostelId;

  const PaymentStatusScreen({
    super.key,
    required this.bookingId,
    required this.status,
    required this.hostelId,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  bool _isLoading = true;
  BookingModel? _booking;
  UserModel? _owner;
  HostelModel? _hostel;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
    _fetchData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final hostel = await _firestoreService.getHostel(widget.hostelId);
      BookingModel? booking;
      UserModel? owner;

      if (widget.bookingId != null) {
        booking = await _firestoreService.getBooking(widget.bookingId!);
      }

      if (hostel != null) {
        owner = await _firestoreService.getUser(hostel.ownerId);
      }

      if (mounted) {
        setState(() {
          _booking = booking;
          _owner = owner;
          _hostel = hostel;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching payment status data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _launchUrl(String uri) async {
    final parsed = Uri.parse(uri);
    if (await canLaunchUrl(parsed)) {
      await launchUrl(parsed);
    }
  }

  bool get isSuccess => widget.status == 'success';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Payment Status'),
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRed),
        ),
      );
    }

    // Determine booking status text
    String bookingStatusText = '';
    Color bookingStatusColor = Colors.orange;
    if (isSuccess && _booking != null) {
      if (_booking!.status == BookingStatus.confirmed) {
        bookingStatusText = 'Hostel Booked';
        bookingStatusColor = Colors.green;
      } else {
        bookingStatusText = 'Pending Owner Confirmation';
        bookingStatusColor = Colors.orange;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50], // Modern background
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Payment Status'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HUGE STATUS BOX
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSuccess
                        ? Colors.green.withOpacity(0.5)
                        : Colors.red.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.cancel,
                      size: 80,
                      color: isSuccess ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSuccess ? 'Payment Successful' : 'Payment Failed',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSuccess ? Colors.green : Colors.red,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // OWNER CONFIRMATION BOX (Only on success)
            if (isSuccess && _booking != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: bookingStatusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: bookingStatusColor.withOpacity(0.5),
                  ),
                ),
                child: Center(
                  child: Text(
                    bookingStatusText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: bookingStatusColor,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            if (_booking != null && _hostel != null) ...[
              // HOSTEL DETAILS CARD
              Text(
                'Hostel Details',
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
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _hostel!.address,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // BOOKING DETAILS CARD
              Text(
                'Booking Details',
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
                      _detailRow('Booking ID', _booking!.id),
                      _detailRow(
                        'Date',
                        '${_fmt(_booking!.checkInDate)} - ${_fmt(_booking!.checkOutDate)}',
                      ),
                      _detailRow(
                        'Time',
                        '${_booking!.bookingDate.hour.toString().padLeft(2, '0')}:${_booking!.bookingDate.minute.toString().padLeft(2, '0')}',
                      ),
                      _detailRow(
                        'Seater/Type',
                        _hostel!.unitType == 'flat'
                            ? 'Flat'
                            : '${_booking!.selectedSeater ?? 1} Seater',
                      ),
                      _detailRow(
                        'Total Hostel Fees',
                        '₹${_booking!.totalPrice.toStringAsFixed(0)}',
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Booking Amount Paid',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            isSuccess
                                ? '₹${_booking!.bookingFee?.toStringAsFixed(0) ?? '0'}'
                                : 'Failed', // Dynamic registration fee or Failed
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.primaryRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // OWNER DETAILS CARD
              if (_owner != null) ...[
                Text(
                  'Owner Details',
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
                              backgroundColor: AppTheme.primaryRed.withOpacity(
                                0.1,
                              ),
                              backgroundImage:
                                  (_owner!.photoUrl?.isNotEmpty ?? false)
                                  ? NetworkImage(_owner!.photoUrl!)
                                  : null,
                              child: (_owner!.photoUrl?.isEmpty ?? true)
                                  ? const Icon(
                                      Icons.person,
                                      color: AppTheme.primaryRed,
                                      size: 22,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _owner!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isSuccess) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (_owner!.phoneNumber?.isNotEmpty ?? false)
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _launchUrl(
                                      'tel:${_owner!.phoneNumber}',
                                    ),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.phone,
                                            size: 18,
                                            color: AppTheme.primaryRed,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Call',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if ((_owner!.phoneNumber?.isNotEmpty ?? false) &&
                                  _owner!.email.isNotEmpty)
                                const SizedBox(width: 12),
                              if (_owner!.email.isNotEmpty)
                                Expanded(
                                  child: InkWell(
                                    onTap: () =>
                                        _launchUrl('mailto:${_owner!.email}'),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.email,
                                            size: 18,
                                            color: AppTheme.primaryRed,
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
                                    'Pay the booking fee to view contact detail.',
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
              ],
            ],

            const SizedBox(height: 32),

            // SUCCESS ONLY: MAP
            if (isSuccess &&
                _hostel != null &&
                _hostel!.latitude != null &&
                _hostel!.longitude != null) ...[
              Text(
                'Location',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            _hostel!.latitude!,
                            _hostel!.longitude!,
                          ),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('hostelLoc'),
                            position: LatLng(
                              _hostel!.latitude!,
                              _hostel!.longitude!,
                            ),
                          ),
                        },
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: FloatingActionButton.extended(
                          heroTag: 'nav_btn',
                          onPressed: () {
                            _launchUrl(
                              'https://www.google.com/maps/search/?api=1&query=${_hostel!.latitude},${_hostel!.longitude}',
                            );
                          },
                          backgroundColor: Colors.white,
                          icon: const Icon(
                            Icons.directions,
                            color: Colors.blue,
                          ),
                          label: const Text(
                            'Navigate',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Builder(
            builder: (context) {
              if (isSuccess) {
                return PrimaryButton(
                  text: 'Go to My Bookings',
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.bookings,
                    (route) => route.isFirst,
                  ),
                );
              } else {
                return PrimaryButton(
                  text: 'Retry Payment',
                  onPressed: () {
                    if (_hostel == null) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.home,
                        (route) => false,
                      );
                      return;
                    }

                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.booking,
                      arguments: {
                        'hostelId': widget.hostelId,
                        'hostelName': _hostel!.name,
                        'pricePerNight': _hostel!.startingPrice,
                        'rentPeriod': _hostel!.rentPeriod,
                      },
                    );
                  },
                );
              }
            },
          ),
        ),
      ),
    );
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

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
