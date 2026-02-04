import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/main/main_bottom_nav.dart';
import '../screens/home/home_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/hotel/hotel_detail_screen.dart';
import '../screens/booking/booking_screen.dart';
import '../screens/booking/bookings_screen.dart';
import '../screens/profile/profile_screen.dart';

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

  static Map<String, WidgetBuilder> routes = {
    // splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    main: (context) => const MainBottomNav(),
    home: (context) => const HomeScreen(),
    search: (context) => const SearchScreen(),
    bookings: (context) => const BookingsScreen(),
    profile: (context) => const ProfileScreen(),
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
            pricePerNight: args['pricePerNight'],
          ),
        );
      default:
        return null;
    }
  }
}