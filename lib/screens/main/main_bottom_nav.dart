import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app/theme.dart';
import '../home/home_screen.dart';
import '../search/search_screen.dart';
import '../booking/bookings_screen.dart';
import '../profile/profile_screen.dart';
import '../admin/admin_screen.dart';
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

  // ---------------- INIT ----------------

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

  // ---------------- DISPOSE ----------------

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  // ---------------- ADMIN CHECK ----------------

  Future<void> _checkAdminStatus(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!mounted) return;

      final isAdmin = doc.data()?['isAdmin'] == true;

      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;

        // Safety: reset index if admin tab disappears
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

  // ---------------- SCREENS ----------------

  List<Widget> get _screens {
    final screens = <Widget>[
      const HomeScreen(),
      const SearchScreen(),
      const BookingsScreen(),
      const ProfileScreen(),
    ];

    if (_isAdmin) {
      screens.add(const AdminScreen());
    }

    return screens;
  }

  // ---------------- NAV ITEMS ----------------

  List<BottomNavigationBarItem> get _navItems {
    final items = const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.search_outlined),
        activeIcon: Icon(Icons.search),
        label: 'Search',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.book_outlined),
        activeIcon: Icon(Icons.book),
        label: 'Bookings',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outlined),
        activeIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ].toList();

    if (_isAdmin) {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          activeIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      );
    }

    return items;
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryRed),
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

    // Extra safety (never crash)
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryRed,
          unselectedItemColor: AppTheme.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: _navItems,
        ),
      ),
    );
  }
}
