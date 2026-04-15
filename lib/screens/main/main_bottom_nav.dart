import 'dart:async';
import 'dart:ui'; // for ImageFilter

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app/theme.dart';
import '../home/home_screen.dart';
import '../search/search_screen.dart';
import '../booking/bookings_screen.dart';
import '../profile/profile_screen.dart';
import '../admin/admin_dashboard.dart';
import '../../services/user_cache.dart';

class MainBottomNav extends StatefulWidget {
  final int initialIndex;
  const MainBottomNav({super.key, this.initialIndex = 0});

  @override
  State<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends State<MainBottomNav> {
  late final StreamSubscription<User?> _authSub;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _currentIndex = 0;
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    UserCache.getUser();

    _currentIndex = widget.initialIndex;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;

      if (user == null) {
        setState(() {
          _isAdmin = false;
          _isLoading = false;
          _currentIndex = 0;
        });
      } else {
        _checkAdminStatus(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _checkAdminStatus(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!mounted) return;

      final isAdmin = doc.data()?['isAdmin'] == true;

      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;

        if (!_isAdmin && _currentIndex > 3) {
          _currentIndex = 0;
        }
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint('Error checking admin status: $e');
      setState(() {
        _isAdmin = false;
        _isLoading = false;
        _currentIndex = 0;
      });
    }
  }

  List<Widget> get _screens {
    final screens = <Widget>[
      const HomeScreen(),
      const SearchScreen(),
      const BookingsScreen(),
      const ProfileScreen(),
    ];

    if (_isAdmin) {
      screens.add(const AdminDashboard());
    }

    return screens;
  }

  List<_NavBarItem> get _navItems {
    final items = [
      _NavBarItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
      ),
      _NavBarItem(
        icon: Icons.search_outlined,
        activeIcon: Icons.search,
        label: 'Search',
      ),
      _NavBarItem(
        icon: Icons.book_outlined,
        activeIcon: Icons.book,
        label: 'Bookings',
      ),
      _NavBarItem(
        icon: Icons.person_outlined,
        activeIcon: Icons.person,
        label: 'Profile',
      ),
    ];

    if (_isAdmin) {
      items.add(
        _NavBarItem(
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
          label: 'Admin',
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryTeal),
              const SizedBox(height: 16),
              const Text(
                'Checking user permissions...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final screens = _screens;
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.fromLTRB(25, 0, 25, 25),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(42),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 85,
              decoration: BoxDecoration(
                color: AppTheme.darkTeal.withAlpha(200),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(
                  color: Colors.white.withAlpha(40),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final isSelected = _currentIndex == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentIndex = index);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.fastOutSlowIn,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 18.0 : 12.0,
                        vertical: 10.0,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentTeal.withAlpha(60)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.fastOutSlowIn,
                            padding: EdgeInsets.all(isSelected ? 8.0 : 0.0),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.accentTeal
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.accentTeal.withAlpha(
                                          120,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: AnimatedScale(
                              scale: isSelected ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.fastOutSlowIn,
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.lightGrey.withAlpha(180),
                                size: 24,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            AnimatedOpacity(
                              opacity: isSelected ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 350),
                              child: Text(
                                item.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}


