import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/firestore_service.dart';
import '../../models/booking_model.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/verification_dialog.dart';

class BookingScreen extends StatefulWidget {
  final String hostelId;
  final String hostelName;
  final double baseFee; // base fee (monthly or yearly depending on rentPeriod)
  final String rentPeriod; // 'monthly' or 'yearly'

  const BookingScreen({
    super.key,
    required this.hostelId,
    required this.hostelName,
    required this.baseFee,
    required this.rentPeriod,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _specialRequestsController = TextEditingController();

  HostelModel? _hostel;
  bool _loadingHostel = true;

  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  int _selectedSeater = 1; // 1,2 or 3 for hostel; ignored for flat
  bool _isLoading = false;

  late Razorpay _razorpay;
  String? _currentBookingId;

  // Registration fee config — change these when going live
  double get _originalAmount => 500.0;
  double get _payableAmount => 100.0;

  @override
  void dispose() {
    _razorpay.clear();
    _specialRequestsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadHostel();
  }

  // ── Payment helpers ──────────────────────────────────────────────────────

  Future<void> _notifyPaymentStatus(bool isSuccess) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _hostel == null) return;

    try {
      // 1. Notify the User (always)
      await _firestoreService.sendAppNotification(
        recipientId: user.uid,
        title: isSuccess ? 'Payment Successful 🎉' : 'Payment Failed ❌',
        body: isSuccess
            ? 'Your booking for ${widget.hostelName} is confirmed.'
            : 'Your payment for ${widget.hostelName} failed. Please try again.',
        type: 'booking',
        additionalData: {
          'bookingId': _currentBookingId ?? '',
          'status': isSuccess ? 'payment_success' : 'payment_failed',
        },
      );

      // 2. Notify the Owner ONLY if the payment is successful
      if (isSuccess) {
        await _firestoreService.sendAppNotification(
          recipientId: _hostel!.ownerId,
          title: 'New Booking Request 🏠',
          body: '${user.displayName ?? 'A user'} booked ${widget.hostelName}.',
          type: 'booking',
          additionalData: {
            'bookingId': _currentBookingId ?? '',
            'status': 'pending', // Keeps routing to AdminBookingsScreen
            'hostelId': widget.hostelId,
          },
        );
      }
    } catch (e) {
      debugPrint('Failed to send notification: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Verify signature via Cloud Function
      final result = await FirebaseFunctions.instance
          .httpsCallable('verifyPaymentSignature')
          .call({
            'razorpay_order_id': response.orderId,
            'razorpay_payment_id': response.paymentId,
            'razorpay_signature': response.signature,
            'bookingId': _currentBookingId,
          });

      if (result.data['success'] == true) {
        // Fallback direct update in case Cloud Function missed it
        await _firestoreService.updatePaymentStatus(
          bookingId: _currentBookingId!,
          status: 'successful',
          orderId: response.orderId,
          paymentId: response.paymentId,
        );
        await _notifyPaymentStatus(true);
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.paymentStatus,
          arguments: {
            'bookingId': _currentBookingId,
            'status': 'success',
            'hostelId': widget.hostelId,
          },
        );
      } else {
        throw 'Invalid signature';
      }
    } catch (e) {
      if (_currentBookingId != null) {
        try {
          await _firestoreService.updatePaymentStatus(
            bookingId: _currentBookingId!,
            status: 'failed',
          );
          await _firestoreService.updateBookingStatus(
            _currentBookingId!,
            BookingStatus.cancelled,
          );
        } catch (_) {}
      }
      await _notifyPaymentStatus(false);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.paymentStatus,
        arguments: {
          'bookingId': _currentBookingId,
          'status': 'failed',
          'hostelId': widget.hostelId,
        },
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    if (_currentBookingId != null) {
      try {
        await _firestoreService.updatePaymentStatus(
          bookingId: _currentBookingId!,
          status: 'failed',
        );
        await _firestoreService.updateBookingStatus(
          _currentBookingId!,
          BookingStatus.cancelled,
        );
      } catch (_) {}
    }
    await _notifyPaymentStatus(false);
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.paymentStatus,
      arguments: {
        'bookingId': _currentBookingId,
        'status': 'failed',
        'hostelId': widget.hostelId,
      },
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Optional: handle external wallet selection
  }

  Future<void> _loadHostel() async {
    try {
      final h = await _firestoreService.getHostel(widget.hostelId);
      if (!mounted) {
        return;
      }
      setState(() {
        _hostel = h;
        _loadingHostel = false;

        // Auto-select first available seater if current one is invalid
        if (h != null && h.unitType != 'flat') {
          final available = [
            if ((h.rooms1Seater) > 0 && (h.price1Seater ?? 0) > 0) 1,
            if ((h.rooms2Seater) > 0 && (h.price2Seater ?? 0) > 0) 2,
            if ((h.rooms3Seater) > 0 && (h.price3Seater ?? 0) > 0) 3,
          ];
          if (available.isNotEmpty && !available.contains(_selectedSeater)) {
            _selectedSeater = available.first;
          }
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingHostel = false);
    }
  }

  int get _rentalUnits {
    if (_checkInDate == null || _checkOutDate == null) return 0;
    final days = _checkOutDate!.difference(_checkInDate!).inDays;
    if (widget.rentPeriod == 'monthly') {
      return (days / 30).ceil();
    }
    return (days / 365).ceil();
  }

  double get _totalPrice {
    final units = _rentalUnits;
    if (units == 0) return 0.0;

    // Prefer using loaded hostel pricing
    final h = _hostel;
    if (h == null) return units * widget.baseFee;

    if (h.unitType == 'flat') {
      return units * h.rentPrice;
    }

    double priceForSeater = 0;
    if (_selectedSeater == 1) {
      priceForSeater = h.price1Seater ?? 0;
    } else if (_selectedSeater == 2) {
      priceForSeater = h.price2Seater ?? 0;
    } else if (_selectedSeater == 3) {
      priceForSeater = h.price3Seater ?? 0;
    }

    // Fallback to widget.baseFee only if it's > 0 and seater price wasn't found
    if (priceForSeater <= 0 && widget.baseFee > 0) {
      priceForSeater = widget.baseFee;
    }

    return units * priceForSeater;
  }

  Future<void> _selectCheckInDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 4)),
    );

    if (date != null) {
      setState(() {
        _checkInDate = date;
        if (_checkOutDate != null && _checkOutDate!.isBefore(date)) {
          _checkOutDate = null;
        }
      });
    }
  }

  Future<void> _selectCheckOutDate() async {
    if (_checkInDate == null) return;

    final date = await showDatePicker(
      context: context,
      initialDate: _checkInDate!.add(const Duration(days: 1)),
      firstDate: _checkInDate!.add(const Duration(days: 1)),
      lastDate: _checkInDate!.add(const Duration(days: 365 * 4)),
    );

    if (date != null) {
      setState(() => _checkOutDate = date);
    }
  }

  Future<void> _handleBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in first')));
      return;
    }

    // Check email verification
    await user.reload();
    if (!FirebaseAuth.instance.currentUser!.emailVerified) {
      if (mounted) showVerificationDialog(context);
      return;
    }

    if (_checkInDate == null || _checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select dates'),
          backgroundColor: AppTheme.darkRed,
        ),
      );
      return;
    }

    if (_totalPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid booking: Price cannot be zero'),
          backgroundColor: AppTheme.darkRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      // Get hostel to find admin ID
      final hostel = await _firestoreService.getHostel(widget.hostelId);
      if (hostel == null) throw 'Hostel not found';

      final booking = BookingModel(
        id: '',
        userId: user.uid,
        hostelId: widget.hostelId,
        hostelName: widget.hostelName,
        adminId: hostel.ownerId, // CRITICAL: Get admin from hostel owner
        checkInDate: _checkInDate!,
        checkOutDate: _checkOutDate!,
        numberOfGuests: 1,
        totalPrice: _totalPrice,
        status: BookingStatus.pending,
        bookingDate: DateTime.now(),
        specialRequests: _specialRequestsController.text.trim().isEmpty
            ? null
            : _specialRequestsController.text.trim(),
        selectedSeater: hostel.unitType == 'flat' ? 0 : _selectedSeater,
        flatCapacity: hostel.flatCapacity,
      );

      final bookingId = await _firestoreService.createBooking(booking);
      _currentBookingId = bookingId;

      // Ensure minimum Razorpay amount is ₹1
      double amountToPay = _payableAmount < 1.0 ? 1.0 : _payableAmount;

      // Create Razorpay order via Cloud Function
      final result = await FirebaseFunctions.instance
          .httpsCallable('createRazorpayOrder')
          .call({'amount': amountToPay, 'receipt': bookingId});

      final String orderId = result.data['orderId'];

      final options = {
        'key': dotenv.env['RAZORPAY_KEY_ID'],
        'amount': (amountToPay * 100).toInt(),
        'name': 'Rentra',
        'description': 'Registration fee for ${widget.hostelName}',
        'order_id': orderId,
        'prefill': {
          'contact': user.phoneNumber ?? '',
          'email': user.email ?? '',
        },
        'notes': {'booking_id': bookingId},
      };

      // _isLoading stays true while Razorpay checkout is open
      _razorpay.open(options);
    } catch (e) {
      if (_currentBookingId != null) {
        try {
          // If order creation or something fails before checkout opens, mark as failed/cancelled
          await _firestoreService.updatePaymentStatus(
            bookingId: _currentBookingId!,
            status: 'failed',
          );
          await _firestoreService.updateBookingStatus(
            _currentBookingId!,
            BookingStatus.cancelled,
          );
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initiate payment: $e'),
          backgroundColor: AppTheme.darkRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Hostel')),
      body: RefreshIndicator(
        onRefresh: () async {
          await FirebaseAuth.instance.currentUser?.reload();
          await _loadHostel();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.hostelName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (context) {
                                      double perUnit = widget.baseFee;
                                      if (!_loadingHostel && _hostel != null) {
                                        final h = _hostel!;
                                        if (h.unitType == 'flat') {
                                          perUnit = h.rentPrice;
                                        } else {
                                          // Dynamic price based on selected seater
                                          double seaterPrice = 0;
                                          if (_selectedSeater == 1) {
                                            seaterPrice = h.price1Seater ?? 0;
                                          } else if (_selectedSeater == 2)
                                            seaterPrice = h.price2Seater ?? 0;
                                          else if (_selectedSeater == 3)
                                            seaterPrice = h.price3Seater ?? 0;

                                          if (seaterPrice > 0) {
                                            perUnit = seaterPrice;
                                          } else {
                                            // Fallback to minimum valid price
                                            final prices =
                                                [
                                                      h.price1Seater,
                                                      h.price2Seater,
                                                      h.price3Seater,
                                                    ]
                                                    .where(
                                                      (p) => p != null && p > 0,
                                                    )
                                                    .map((p) => p!)
                                                    .toList();
                                            if (prices.isNotEmpty) {
                                              perUnit = prices.reduce(
                                                (a, b) => a < b ? a : b,
                                              );
                                            }
                                          }
                                        }
                                      }

                                      return Text(
                                        '${perUnit.toStringAsFixed(0)} per ${widget.rentPeriod == 'monthly' ? 'Month' : 'Year'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: AppTheme.primaryRed,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Unit type & availability
                            if (_loadingHostel)
                              const SizedBox.shrink()
                            else ...[
                              Builder(
                                builder: (context) {
                                  int rooms = 0;
                                  if (_hostel != null) {
                                    if (_hostel!.unitType == 'flat') {
                                      rooms = _hostel!.availableRooms;
                                    } else {
                                      if (_selectedSeater == 1) {
                                        rooms = _hostel!.rooms1Seater;
                                      } else if (_selectedSeater == 2)
                                        rooms = _hostel!.rooms2Seater;
                                      else if (_selectedSeater == 3)
                                        rooms = _hostel!.rooms3Seater;
                                    }
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Unit type chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.lightGrey,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          (_hostel?.unitType.toLowerCase() ==
                                                  'flat')
                                              ? 'Flat'
                                              : 'Hostel / PG',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Availability badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (() {
                                            if (rooms <= 0) {
                                              return AppTheme.grey.withOpacity(
                                                0.1,
                                              );
                                            }
                                            if (rooms <= 3) {
                                              return Colors.red.withOpacity(
                                                0.08,
                                              );
                                            }
                                            if (rooms <= 5) {
                                              return Colors.amber.withOpacity(
                                                0.08,
                                              );
                                            }
                                            return Colors.green.withOpacity(
                                              0.08,
                                            );
                                          })(),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          (_hostel?.unitType.toLowerCase() ==
                                                  'flat')
                                              ? (rooms > 0
                                                    ? 'Available'
                                                    : 'Not Available')
                                              : (rooms > 0
                                                    ? '$rooms rooms available'
                                                    : 'No rooms'),
                                          style: TextStyle(
                                            color: (() {
                                              if (rooms <= 0) {
                                                return AppTheme.grey;
                                              }
                                              if (_hostel?.unitType
                                                      .toLowerCase() ==
                                                  'flat') {
                                                return Colors.green;
                                              }
                                              if (rooms <= 3) {
                                                return AppTheme.primaryRed;
                                              }
                                              if (rooms <= 5) {
                                                return Colors.orange;
                                              }
                                              return Colors.green;
                                            })(),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ⬇️ REST OF UI UNCHANGED ⬇️
                const SizedBox(height: 24),

                // Check-in date
                Text(
                  'Start Date',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectCheckInDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      border: Border.all(color: AppTheme.lightGrey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: AppTheme.primaryRed,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _checkInDate != null
                              ? '${_checkInDate!.day}/${_checkInDate!.month}/${_checkInDate!.year}'
                              : 'Starting date',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Check-out date
                Text('Till', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectCheckOutDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      border: Border.all(color: AppTheme.lightGrey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: AppTheme.primaryRed,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _checkOutDate != null
                              ? '${_checkOutDate!.day}/${_checkOutDate!.month}/${_checkOutDate!.year}'
                              : 'Till',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Number of guests
                Text(
                  'Select Seater',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (_loadingHostel)
                  const SizedBox.shrink()
                else if (_hostel != null && _hostel!.unitType == 'flat')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      border: Border.all(color: AppTheme.lightGrey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _hostel!.flatCapacity != null
                          ? 'Capacity: ${_hostel!.flatCapacity} person'
                          : 'Capacity: ${_hostel!.availableRooms} rooms',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: (() {
                      // Filter available seaters based on rooms and price
                      final available = [
                        if ((_hostel?.rooms1Seater ?? 0) > 0 &&
                            (_hostel?.price1Seater ?? 0) > 0)
                          1,
                        if ((_hostel?.rooms2Seater ?? 0) > 0 &&
                            (_hostel?.price2Seater ?? 0) > 0)
                          2,
                        if ((_hostel?.rooms3Seater ?? 0) > 0 &&
                            (_hostel?.price3Seater ?? 0) > 0)
                          3,
                      ];
                      if (available.contains(_selectedSeater)) {
                        return _selectedSeater;
                      }
                      return available.isNotEmpty ? available.first : null;
                    })(),
                    items:
                        [
                              if ((_hostel?.rooms1Seater ?? 0) > 0 &&
                                  (_hostel?.price1Seater ?? 0) > 0)
                                1,
                              if ((_hostel?.rooms2Seater ?? 0) > 0 &&
                                  (_hostel?.price2Seater ?? 0) > 0)
                                2,
                              if ((_hostel?.rooms3Seater ?? 0) > 0 &&
                                  (_hostel?.price3Seater ?? 0) > 0)
                                3,
                            ]
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text('$s seater'),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedSeater = v);
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                Text(
                  'Special Requests (Optional)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _specialRequestsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Any special requirements',
                  ),
                ),

                const SizedBox(height: 32),

                if (_rentalUnits > 0)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Price Summary',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Builder(
                                builder: (context) {
                                  double perUnit = widget.baseFee;
                                  if (_hostel != null) {
                                    final h = _hostel!;
                                    if (h.unitType == 'flat') {
                                      perUnit = h.rentPrice;
                                    } else {
                                      if (_selectedSeater == 1 &&
                                          h.price1Seater != null) {
                                        perUnit = h.price1Seater!;
                                      }
                                      if (_selectedSeater == 2 &&
                                          h.price2Seater != null) {
                                        perUnit = h.price2Seater!;
                                      }
                                      if (_selectedSeater == 3 &&
                                          h.price3Seater != null) {
                                        perUnit = h.price3Seater!;
                                      }
                                    }
                                  }

                                  return Text(
                                    '${perUnit.toStringAsFixed(0)} x $_rentalUnits ${widget.rentPeriod == 'monthly' ? 'months' : 'years'}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  );
                                },
                              ),
                              Text(
                                _totalPrice.toStringAsFixed(2),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _totalPrice.toStringAsFixed(2),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: AppTheme.primaryRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                // extra bottom spacing to avoid content being hidden behind
                // the fixed action button
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      // move confirm action to bottomNavigationBar so it stays visible
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Price chip
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryRed.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking Fee',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Limited time offer!',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '₹${_originalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${(_payableAmount < 1.0 ? 1.0 : _payableAmount).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: AppTheme.primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text:
                    'Pay ₹${(_payableAmount < 1.0 ? 1.0 : _payableAmount).toStringAsFixed(0)} & Book',
                onPressed: _handleBooking,
                isLoading: _isLoading,
                icon: Icons.lock_outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
