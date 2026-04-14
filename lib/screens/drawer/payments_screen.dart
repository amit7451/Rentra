import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../app/theme.dart';
import '../../services/firestore_service.dart';
import '../../models/booking_model.dart';
import '../../widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments & Transactions'),
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text('Please sign in to view history'))
          : StreamBuilder<List<BookingModel>>(
              stream: firestoreService.getFailedUserTransactions(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator();
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 80,
                          color: AppTheme.grey,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No failed or cancelled matches',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: AppTheme.grey),
                        ),
                      ],
                    ),
                  );
                }

                final transactions = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final booking = transactions[index];
                    final isCancelled =
                        booking.status == BookingStatus.cancelled;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    booking.hostelName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCancelled
                                        ? Colors.orange.withOpacity(0.1)
                                        : AppTheme.primaryTeal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isCancelled ? 'CANCELLED' : 'FAILED',
                                    style: TextStyle(
                                      color: isCancelled
                                          ? Colors.orange[800]
                                          : AppTheme.primaryTeal,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Booking ID: ${booking.id.substring(0, 8).toUpperCase()}',
                              style: const TextStyle(
                                color: AppTheme.grey,
                                fontSize: 12,
                              ),
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: AppTheme.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(booking.bookingDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '₹${booking.totalPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            if (booking.cancellationReason != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Reason: ${booking.cancellationReason}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.grey,
                                  ),
                                ),
                              ),
                            ],
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
}
