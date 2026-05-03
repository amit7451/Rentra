import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'theme.dart';
import 'routes.dart';
import '../screens/splash_screen.dart';
import '../widgets/connectivity_wrapper.dart';
import '../widgets/app_background.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Book Hostel or Flat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        ...AppRoutes.routes,
      },
      onGenerateRoute: (settings) {
        final route = AppRoutes.onGenerateRoute(settings);
        if (route is MaterialPageRoute) {
          return MaterialPageRoute(
            settings: route.settings,
            builder: (context) => route.builder(context),
          );
        }
        return route;
      },
      builder: (context, child) {
        return ConnectivityWrapper(
          child: AppBackground(child: child!),
        );
      },
    );
  }
}
