import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/booking_model.dart';
import '../../app/theme.dart';
import '../../widgets/primary_button.dart';

class BookingScreen extends StatefulWidget {
  final String hostelId;
  final String hostelName;
  final double yearlyFee; // ✅ fetched from DB earlier

  const BookingScreen({
    super.key,
    required this.hostelId,
    required this.hostelName,
    required this.yearlyFee,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _specialRequestsController = TextEditingController();

  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  int _numberOfGuests = 1;
  bool _isLoading = false;

  @override
  void dispose() {
    _specialRequestsController.dispose();
    super.dispose();
  }

  int get _numberOfYears {
    if (_checkInDate == null || _checkOutDate == null) return 0;
    final days = _checkOutDate!.difference(_checkInDate!).inDays;
    return (days / 365).ceil();
  }

  double get _totalPrice {
    return _numberOfYears * widget.yearlyFee;
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

    if (_checkInDate == null || _checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select dates'),
          backgroundColor: AppTheme.darkRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      final booking = BookingModel(
        id: '',
        userId: user.uid,
        hostelId: widget.hostelId,
        hostelName: widget.hostelName,
        checkInDate: _checkInDate!,
        checkOutDate: _checkOutDate!,
        numberOfGuests: _numberOfGuests,
        totalPrice: _totalPrice,
        status: BookingStatus.pending,
        bookingDate: DateTime.now(),
        specialRequests: _specialRequestsController.text.trim().isEmpty
            ? null
            : _specialRequestsController.text.trim(),
      );

      await _firestoreService.createBooking(booking);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create booking: $e'),
          backgroundColor: AppTheme.darkRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Hostel')),
      body: SingleChildScrollView(
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
                      Text(
                        widget.hostelName,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.yearlyFee.toStringAsFixed(0)} per Year',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ⬇️ REST OF UI UNCHANGED ⬇️
              const SizedBox(height: 24),

              // Check-in date
              Text('Start Date', style: Theme.of(context).textTheme.titleLarge),
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
                'Number of Person',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _numberOfGuests > 1
                        ? () => setState(() => _numberOfGuests--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppTheme.primaryRed,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.lightGrey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _numberOfGuests.toString(),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _numberOfGuests++),
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppTheme.primaryRed,
                  ),
                ],
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

              if (_numberOfYears > 0)
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
                            Text(
                              '${widget.yearlyFee.toStringAsFixed(0)} x $_numberOfYears years',
                              style: Theme.of(context).textTheme.bodyLarge,
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
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _totalPrice.toStringAsFixed(2),
                              style: Theme.of(context).textTheme.headlineMedium
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

              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Confirm Booking',
                onPressed: _handleBooking,
                isLoading: _isLoading,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
