import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/main/main_bottom_nav.dart';
import '../screens/home/home_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/hotel/hotel_detail_screen.dart';
import '../screens/booking/booking_screen.dart';
import '../screens/booking/bookings_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/notifications/notifications.dart';
import '../screens/wishlist/wishlist_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/add_hostel_screen.dart';
import '../screens/drawer/payments_screen.dart';
import '../screens/drawer/help_support_screen.dart';
import '../screens/drawer/privacy_policy_screen.dart';
import '../screens/drawer/invite_earn_screen.dart';
import 'package:rentra/screens/profile/change_password_screen.dart';
import '../screens/admin/admin_bookings_screen.dart';
import '../screens/admin/admin_booking_details_screen.dart';
import '../screens/booking/payment_status_screen.dart';
import '../screens/notifications/notification_settings_screen.dart';
import '../screens/profile/saved_payment_methods_screen.dart';

class AppRoutes {
  // static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String main = '/main';
  static const String home = '/home';
  static const String search = '/search';
  static const String hotelDetail = '/hotel-detail';
  static const String booking = '/booking';
  static const String bookings = '/bookings';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String wishlist = '/wishlist';
  static const String adminDashboard = '/admin';
  static const String addHostel = '/add-hostel';
  static const String payments = '/payments';
  static const String helpSupport = '/help-support';
  static const String privacyPolicy = '/privacy-policy';
  static const String adminBookings = '/admin-bookings';
  static const String inviteEarn = '/invite-earn';
  static const String changePassword = '/change-password';
  static const String paymentStatus = '/payment-status';
  static const String adminBookingDetails = '/admin-booking-details';
  static const String notificationSettings = '/notification-settings';
  static const String paymentMethods = '/payment-methods';

  static Map<String, WidgetBuilder> routes = {
    // splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    main: (context) => const MainBottomNav(),
    home: (context) => const HomeScreen(),
    search: (context) => const SearchScreen(),
    bookings: (context) => const BookingsScreen(),
    profile: (context) => const ProfileScreen(),
    wishlist: (context) => const WishlistScreen(),
    notifications: (context) => const NotificationsScreen(),
    adminDashboard: (context) => const AdminDashboard(),
    adminBookings: (context) => const AdminBookingsScreen(),
    addHostel: (context) => const AddHostelScreen(),
    payments: (context) => const PaymentsScreen(),
    helpSupport: (context) => const HelpSupportScreen(),
    privacyPolicy: (context) => const PrivacyPolicyScreen(),
    inviteEarn: (context) => const InviteEarnScreen(),
    changePassword: (context) => const ChangePasswordScreen(),
    notificationSettings: (context) => const NotificationSettingsScreen(),
    paymentMethods: (context) => const SavedPaymentMethodsScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case hotelDetail:
        String id;
        bool hide = false;
        double? dist;
        if (settings.arguments is Map) {
          final args = settings.arguments as Map<String, dynamic>;
          id = args['hostelId'];
          hide = args['hideBookingButton'] ?? false;
          dist = args['distance'];
        } else {
          id = settings.arguments as String;
        }
        return MaterialPageRoute(
          builder: (context) => HotelDetailScreen(
            hostelId: id,
            hideBookingButton: hide,
            distance: dist,
          ),
        );
      case bookings:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) =>
              BookingsScreen(highlightBookingId: args?['highlightBookingId']),
        );
      case adminBookings:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => AdminBookingsScreen(
            initialIndex: args?['initialIndex'] ?? 0,
            highlightBookingId: args?['highlightBookingId'],
          ),
        );
      case booking:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => BookingScreen(
            hostelId: args['hostelId'],
            hostelName: args['hostelName'],
            baseFee: (args['pricePerNight'] as num).toDouble(),
            rentPeriod: (args['rentPeriod'] as String?) ?? 'yearly',
          ),
        );
      case adminBookingDetails:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) =>
              AdminBookingDetailsScreen(bookingId: args?['bookingId'] ?? ''),
        );
      case paymentStatus:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => PaymentStatusScreen(
            bookingId: args['bookingId'],
            status: args['status'],
            hostelId: args['hostelId'],
          ),
        );
      default:
        return null;
    }
  }
}


