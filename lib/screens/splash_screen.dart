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

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bubbleController;
  late Animation<double> _bubbleAnimation;

  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;
  late Animation<double> _opacityAnimation;

  String _displayText = "";
  final String _fullText = "Feel the Home";
  int _charIndex = 0;
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();

    // 1. Bubble Animation (Only for the Icon)
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _bubbleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bubbleController, curve: Curves.easeInOut),
    );

    // 2. Zoom & Exit Animation (For the whole content)
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Slightly slower zoom
    );

    _zoomAnimation = Tween<double>(begin: 1.0, end: 15.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeInExpo),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _zoomController, curve: const Interval(0.5, 1.0)),
    );

    // 3. Start Loading Data
    _initializeApp();

    // 4. Start Typewriter
    _startTypewriter();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Load environment variables first
      await dotenv.load(fileName: ".env");

      // 2. Initialize non-dependent services in parallel
      await Future.wait([
        CloudinaryService.initialize(),
        NotificationService().initialize(),
        FirestoreService().preLoadAppData().timeout(
          const Duration(seconds: 10),
        ),
        // Ensure minimum splash time for smooth feel
        Future.delayed(const Duration(seconds: 4)),
      ]);
    } catch (e) {
      debugPrint("Initialization error: $e");
    } finally {
      if (mounted) {
        _finishSplash();
      }
    }
  }

  void _startTypewriter() {
    // Delay start slightly
    Future.delayed(const Duration(milliseconds: 300), () {
      _typewriterTimer = Timer.periodic(const Duration(milliseconds: 120), (
        timer,
      ) {
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
    });
  }

  Future<void> _finishSplash() async {
    // Wait for typewriter to finish if it hasn't
    while (_charIndex < _fullText.length) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    // Start zoom animation
    await _zoomController.forward();

    if (!mounted) return;

    // Navigate to next screen
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.main);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    _zoomController.dispose();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white, // Use white as base
      body: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_bubbleController, _zoomController]),
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _zoomAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Icon (with bubly scale)
                        Transform.scale(
                          scale: _bubbleAnimation.value,
                          child: Image.asset(
                            'assets/icons/app_icon.png',
                            width: 200, // Made it bigger
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Tagline (No bubly scale, just typewriter & zoom)
                        SizedBox(
                          height: 30,
                          child: Text(
                            _displayText,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Parent Company Name at Bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Powered by',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'techeasesolutions',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


