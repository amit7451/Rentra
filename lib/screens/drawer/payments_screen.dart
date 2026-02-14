import 'package:flutter/material.dart';
import '../../app/theme.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments & Transactions')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payment_rounded, size: 80, color: AppTheme.grey),
            const SizedBox(height: 20),
            Text(
              'Payments coming soon',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: AppTheme.grey),
            ),
          ],
        ),
      ),
    );
  }
}
