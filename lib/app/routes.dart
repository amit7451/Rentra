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
  static const String inviteEarn = '/invite-earn';

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
    addHostel: (context) => const AddHostelScreen(),
    payments: (context) => const PaymentsScreen(),
    helpSupport: (context) => const HelpSupportScreen(),
    privacyPolicy: (context) => const PrivacyPolicyScreen(),
    inviteEarn: (context) => const InviteEarnScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case hotelDetail:
        final hostelId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (context) => HotelDetailScreen(hostelId: hostelId),
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
      default:
        return null;
    }
  }
}
