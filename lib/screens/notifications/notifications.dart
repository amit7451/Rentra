import 'package:flutter/material.dart';
import '../../app/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Dumb state for demonstration, not persisted
  bool _bookingConfirmation = true;
  bool _priceDrops = true;
  bool _newProperties = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNotificationToggle(
            'Booking Confirmation',
            'Get notified when your booking is approved or rejected',
            _bookingConfirmation,
            (value) => setState(() => _bookingConfirmation = value),
          ),
          const Divider(),
          _buildNotificationToggle(
            'Price Drops & Offers',
            'Be the first to know about discounts and special offers',
            _priceDrops,
            (value) => setState(() => _priceDrops = value),
          ),
          const Divider(),
          _buildNotificationToggle(
            'New Properties',
            'Get updates when new properties are added in your area',
            _newProperties,
            (value) => setState(() => _newProperties = value),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryRed,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.grey, fontSize: 13),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
