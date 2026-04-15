import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
      final context = _globalNavigatorKey.currentContext;
      if (context != null) {
        handleNotificationClick(context, data);
      }
    });

    // 4. Setup Foreground Listener
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint(
        "🔔 Notification received in foreground: ${event.notification.title}",
      );
      // In v5, you can't easily force it to show as a system notification here,
      // but you can show a SnackBar or similar.
      // To allow the system notification to show even in foreground:
      event.notification.display();
    });

    debugPrint("✅ OneSignal Initialized");
  }

  /// Handle notification clicks
  void handleNotificationClick(
    BuildContext context,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return;

    final type = data['type'];
    final bookingId = data['bookingId'];
    final status = data['status'];

    if (true) {
      if (type == 'booking') {
        // Check if this is for admin (new booking) or user (confirmed/cancelled)
        // Usually, admin notifications have 'bookingId' and maybe 'hostelId'
        // If 'status' is present, it's likely a status update for the user.
        // If 'status' is 'pending', it's a new booking for the admin.

        if (status == 'confirmed' ||
            status == 'payment_success' ||
            status == 'payment_failed' ||
            (status == 'cancelled' && bookingId != null)) {
          // User side: Booking status updated
          Navigator.pushNamed(
            context,
            AppRoutes.bookings,
            arguments: {'highlightBookingId': bookingId},
          );
        } else {
          // Admin side: New booking or other update
          int initialIndex = 0;
          if (status == 'cancelled') {
            initialIndex = 2; // For admin cancellation tab if you have one
          }

          Navigator.pushNamed(
            context,
            AppRoutes.adminBookings,
            arguments: {
              'initialIndex': initialIndex,
              'highlightBookingId': bookingId,
            },
          );
        }
      } else if (type == 'property') {
        final hostelId = data['hostelId'];
        if (hostelId != null) {
          Navigator.pushNamed(
            context,
            AppRoutes.hotelDetail,
            arguments: {'hostelId': hostelId},
          );
        }
      } else if (type == 'offer') {
        Navigator.pushNamed(context, AppRoutes.home);
      } else {
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

  /// Send push notification via OneSignal REST API
  Future<void> sendPushNotification({
    required String playerId, // Generally the UID we logged in with
    required String title,
    required String content,
    Map<String, dynamic>? additionalData,
  }) async {
    final appId = dotenv.env['ONESIGNAL_APP_ID'];
    final restApiKey = dotenv.env['ONESIGNAL_REST_API_KEY'];

    if (appId == null || restApiKey == null) {
      debugPrint("⚠️ OneSignal credentials missing");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restApiKey',
        },
        body: jsonEncode({
          'app_id': appId,
          // Use include_external_user_ids because we use OneSignal.login(uid)
          'include_external_user_ids': [playerId],
          'headings': {'en': title},
          'contents': {'en': content},
          'data': additionalData,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Push Notification Sent Successfully");
      } else {
        debugPrint("❌ Failed to send Push: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error sending push notification: $e");
    }
  }

  /// Send push notification to multiple users in one call
  Future<void> sendPushToUsers({
    required List<String> playerIds,
    required String title,
    required String content,
    Map<String, dynamic>? additionalData,
  }) async {
    if (playerIds.isEmpty) return;

    final appId = dotenv.env['ONESIGNAL_APP_ID'];
    final restApiKey = dotenv.env['ONESIGNAL_REST_API_KEY'];

    if (appId == null || restApiKey == null) {
      debugPrint("⚠️ OneSignal credentials missing");
      return;
    }

    try {
      // Chunking if list is too large (OneSignal limit is usually 2000 per call for external_ids)
      const chunkSize = 1500;
      for (var i = 0; i < playerIds.length; i += chunkSize) {
        final chunk = playerIds.sublist(
          i,
          i + chunkSize > playerIds.length ? playerIds.length : i + chunkSize,
        );

        final response = await http.post(
          Uri.parse('https://onesignal.com/api/v1/notifications'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Basic $restApiKey',
          },
          body: jsonEncode({
            'app_id': appId,
            'include_external_user_ids': chunk,
            'headings': {'en': title},
            'contents': {'en': content},
            'data': additionalData,
          }),
        );

        if (response.statusCode != 200) {
          debugPrint("❌ Failed to send Batch Push: ${response.body}");
        }
      }
      debugPrint("✅ Batch Push Notifications Sent Successfully");
    } catch (e) {
      debugPrint("❌ Error sending batch push notification: $e");
    }
  }
}

/// Global Navigator Key to access context from anywhere
final GlobalKey<NavigatorState> _globalNavigatorKey =
    GlobalKey<NavigatorState>();
GlobalKey<NavigatorState> get navigatorKey => _globalNavigatorKey;


