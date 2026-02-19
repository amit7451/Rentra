import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'theme.dart';
import 'routes.dart';
import '../screens/splash_screen.dart';
import '../widgets/connectivity_wrapper.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Book Hostel or Flat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {'/': (context) => const SplashScreen(), ...AppRoutes.routes},
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (context, child) {
        return ConnectivityWrapper(child: child);
      },
    );
  }
}
