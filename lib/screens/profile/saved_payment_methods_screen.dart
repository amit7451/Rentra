import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/theme.dart';
import '../../models/user_model.dart';
import '../../models/payment_method_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/loading_indicator.dart';

class SavedPaymentMethodsScreen extends StatefulWidget {
  const SavedPaymentMethodsScreen({super.key});

  @override
  State<SavedPaymentMethodsScreen> createState() =>
      _SavedPaymentMethodsScreenState();
}

class _SavedPaymentMethodsScreenState extends State<SavedPaymentMethodsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _addPaymentMethod() {
    String type = 'card';
    final nicknameController = TextEditingController();
    final detailController =
        TextEditingController(); // UPI ID or Card Number Mask

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Payment Method',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _typeChip('card', Icons.credit_card, type, (val) {
                    setModalState(() => type = val);
                  }),
                  const SizedBox(width: 10),
                  _typeChip('upi', Icons.account_balance_wallet, type, (val) {
                    setModalState(() => type = val);
                  }),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nicknameController,
                decoration: const InputDecoration(
                  labelText: 'Nickname (e.g. My HDFC Card)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: detailController,
                decoration: InputDecoration(
                  labelText: type == 'card' ? 'Last 4 Digits' : 'UPI ID',
                  border: const OutlineInputBorder(),
                  hintText: type == 'card' ? 'e.g. 4242' : 'e.g. user@okaxis',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nicknameController.text.isEmpty ||
                        detailController.text.isEmpty) {
                      return;
                    }

                    final method = PaymentMethodModel(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      type: type,
                      nickname: nicknameController.text,
                      last4: type == 'card' ? detailController.text : null,
                      upiId: type == 'upi' ? detailController.text : null,
                      createdAt: DateTime.now(),
                    );

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await _firestoreService.savePaymentMethod(
                          user.uid,
                          method.toMap(),
                        );
                        if (mounted) Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Save Method',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(
    String val,
    IconData icon,
    String selected,
    Function(String) onSelect,
  ) {
    final isSelected = val == selected;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.black),
          const SizedBox(width: 8),
          Text(
            val.toUpperCase(),
            style: TextStyle(color: isSelected ? Colors.white : Colors.black),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelect(val),
      selectedColor: AppTheme.primaryRed,
      backgroundColor: Colors.grey[200],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods'), elevation: 0),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingIndicator();

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final userModel = data != null ? UserModel.fromMap(data) : null;
          final methods =
              userModel?.savedPaymentMethods
                  ?.map((m) => PaymentMethodModel.fromMap(m))
                  .toList() ??
              [];

          if (methods.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payment_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No saved payment methods',
                    style: TextStyle(color: AppTheme.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _addPaymentMethod,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Method'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: methods.length,
            itemBuilder: (context, index) {
              final method = methods[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryRed.withOpacity(0.1),
                    child: Icon(
                      method.type == 'card'
                          ? Icons.credit_card
                          : Icons.account_balance_wallet,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                  title: Text(
                    method.nickname,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    method.type == 'card'
                        ? '**** **** **** ${method.last4}'
                        : method.upiId ?? '',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _deleteMethod(method),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPaymentMethod,
        backgroundColor: AppTheme.primaryRed,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _deleteMethod(PaymentMethodModel method) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Method'),
        content: const Text(
          'Are you sure you want to remove this payment method?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.deletePaymentMethod(user.uid, method.toMap());
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }
}
