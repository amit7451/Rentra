import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _isLoading = true;

  // Settings with default values
  Map<String, bool> _settings = {
    'bookingUpdates': true,
    'newProperties': true,
    'priceDrops': true,
    'promotions': false,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('notifications')
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          // Merge fetched settings with defaults
          _settings = {..._settings, ...Map<String, bool>.from(doc.data()!)};
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    if (_uid == null) return;

    // Optimistic UI update
    setState(() => _settings[key] = value);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('notifications')
          .set({key: value}, SetOptions(merge: true));
    } catch (e) {
      // Revert on error
      setState(() => _settings[key] = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update setting')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: LoadingIndicator(message: 'Loading settings...')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          'Notification Settings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage your preferences',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              child: Column(
                children: [
                  _buildToggleTile(
                    'Booking Updates',
                    'Get notified about your booking status and payments',
                    'bookingUpdates',
                    Icons.confirmation_number_outlined,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildToggleTile(
                    'New Properties',
                    'Be the first to know when new hostels are added',
                    'newProperties',
                    Icons.home_work_outlined,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildToggleTile(
                    'Price Drops',
                    'Alerts when prices drop on your wishlist items',
                    'priceDrops',
                    Icons.trending_down_outlined,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildToggleTile(
                    'Promotions',
                    'Special offers, coupons and holiday deals',
                    'promotions',
                    Icons.local_offer_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Note: Critical system and security alerts will always be sent via email.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    String title,
    String subtitle,
    String settingKey,
    IconData icon,
  ) {
    return SwitchListTile.adaptive(
      value: _settings[settingKey] ?? true,
      onChanged: (bool value) => _updateSetting(settingKey, value),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryTeal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryTeal, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      activeColor: AppTheme.primaryTeal,
    );
  }
}


