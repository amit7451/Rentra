import 'package:flutter/material.dart';
import 'theme.dart';
import 'routes.dart';
import '../screens/splash_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Hostel or Flat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {'/': (context) => const SplashScreen(), ...AppRoutes.routes},
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
