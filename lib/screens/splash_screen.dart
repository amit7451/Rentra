import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/cloudinary_service.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../app/theme.dart';
import '../app/routes.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  String _displayText = "";
  final String _fullText = "GET YOUR PERFECT HOME";
  int _charIndex = 0;
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();

    // Subtle fading animation for the logo
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();

    // Start Loading Data
    _initializeApp();
  }

  void _startTypewriter() {
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_charIndex < _fullText.length) {
        if (mounted) {
          setState(() {
            _charIndex++;
            _displayText = _fullText.substring(0, _charIndex);
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      await dotenv.load(fileName: ".env");

      // Start typewriter after a small delay
      Future.delayed(const Duration(milliseconds: 500), _startTypewriter);

      await Future.wait([
        CloudinaryService.initialize(),
        NotificationService().initialize(),
        FirestoreService().preLoadAppData().timeout(const Duration(seconds: 10)),
        // Minimum time to allow typewriter and initialization
        Future.delayed(const Duration(seconds: 2)),
      ]);
    } catch (e) {
      debugPrint("Initialization error: $e");
    } finally {
      // Ensure typewriter is done or wait a bit more
      if (_charIndex < _fullText.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (mounted) _finishSplash();
    }
  }

  Future<void> _finishSplash() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.main);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102B2C),
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo in a Squircle frame
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Premium Capitalized Typewriter Text
                  SizedBox(
                    height: 30,
                    child: Text(
                      _displayText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Powered By Section
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Powered by',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'techeasesolutions',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
