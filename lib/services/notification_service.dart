import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/material.dart';
import '../app/routes.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    final appId = dotenv.env['ONESIGNAL_APP_ID'];

    if (appId == null || appId.isEmpty) {
      debugPrint("⚠️ OneSignal App ID is missing in .env");
      return;
    }

    // 1. Initialize OneSignal
    OneSignal.initialize(appId);

    // 2. Request Permission
    await OneSignal.Notifications.requestPermission(true);

    // 3. Setup Click Listener (Deep Linking)
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      _handleNotificationClick(data);
    });

    debugPrint("✅ OneSignal Initialized");
  }

  /// Handle notification clicks
  void _handleNotificationClick(Map<String, dynamic>? data) {
    if (data == null) return;

    final type = data['type'];
    final context = _globalNavigatorKey.currentContext;

    if (context != null) {
      if (type == 'booking') {
        // Example: Navigate to Bookings Screen
        Navigator.pushNamed(context, AppRoutes.bookings);
      } else if (type == 'offer') {
        // Navigate to Home or specific offer page
        Navigator.pushNamed(context, AppRoutes.home);
      } else {
        // Default to Notifications Screen
        Navigator.pushNamed(context, AppRoutes.notifications);
      }
    }
  }

  /// Login user to OneSignal (Link with Firebase UID)
  void login(String uid) {
    OneSignal.login(uid);
  }

  /// Logout user from OneSignal
  void logout() {
    OneSignal.logout();
  }

  /// Set user tags for targeting
  void setUserTags({
    String? role,
    String? city,
    String? pincode,
    String? hostelId,
  }) {
    final tags = <String, String>{};

    if (role != null) tags['role'] = role;
    if (city != null) tags['city'] = city;
    if (pincode != null) tags['pincode'] = pincode;
    if (hostelId != null) tags['hostelId'] = hostelId;

    if (tags.isNotEmpty) {
      OneSignal.User.addTags(tags);
    }
  }

  /// Remove specific tags
  void removeTags(List<String> keys) {
    OneSignal.User.removeTags(keys);
  }
}

/// Global Navigator Key to access context from anywhere
final GlobalKey<NavigatorState> _globalNavigatorKey =
    GlobalKey<NavigatorState>();
GlobalKey<NavigatorState> get navigatorKey => _globalNavigatorKey;
