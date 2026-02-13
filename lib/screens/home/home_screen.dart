import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../services/wishlist_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_text.dart';
import '../search/search_screen.dart';
import '/widgets/app_drawer.dart';
import 'hotel_card.dart';

import 'package:rentra/app/routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final _wishlistService = WishlistService();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _selectedUnitType = 'hostel'; // 'hostel' or 'flat'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(
        elevation: 2,
        backgroundColor: AppTheme.primaryRed,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset(
          'assets/icons/app_icon.png',
          height: 36,
          fit: BoxFit.contain,
          color: Colors.white,
          colorBlendMode: BlendMode.srcIn,
        ),
        actions: [
          // Wishlist icon with live badge count
          StreamBuilder<List<String>>(
            stream: _wishlistService.watchWishlist(_uid),
            builder: (context, snap) {
              final count = snap.data?.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.favorite_border,
                      color: AppTheme.white,
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.wishlist),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryRed,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: AppTheme.primaryRed,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppTheme.white),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Red search header ─────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.primaryRed,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    readOnly: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search hostels, flats...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppTheme.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppTheme.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // const Text(
                //   'Nearby stays',
                //   style: TextStyle(
                //     color: AppTheme.white,
                //     fontSize: 18,
                //     fontWeight: FontWeight.w600,
                //   ),
                // ),
                // const SizedBox(height: 12),
                // Unit selector (segmented control)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _unitToggleButton('hostel', 'Hostel / PG'),
                        _unitToggleButton('flat', 'Flat'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Hostel list ───────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<HostelModel>>(
              stream: _firestoreService.getHostels(unitType: _selectedUnitType),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(message: 'Loading hostels...');
                }

                if (snapshot.hasError) {
                  return ErrorText(
                    message: 'Error: ${snapshot.error}',
                    onRetry: () => setState(() {}),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.hotel_outlined,
                          size: 64,
                          color: AppTheme.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hostels available',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                }

                // ── Stream wishlist IDs for heart state ────────────
                return StreamBuilder<List<String>>(
                  stream: _uid.isEmpty
                      ? Stream.value([])
                      : _wishlistService.watchWishlist(_uid),
                  builder: (context, wishlistSnap) {
                    final wishlistIds = wishlistSnap.data ?? [];

                    return RefreshIndicator(
                      color: AppTheme.primaryRed,
                      onRefresh: () async =>
                          await Future.delayed(const Duration(seconds: 1)),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final hostel = snapshot.data![index];
                          return _WishlistableCard(
                            hostel: hostel,
                            isWishlisted: wishlistIds.contains(hostel.id),
                            uid: _uid,
                            wishlistService: _wishlistService,
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitToggleButton(String key, String label) {
    final selected = _selectedUnitType == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedUnitType = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.primaryRed : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Wishlistable Card Wrapper ──────────────────────────────────────────────
// Wraps the existing HotelCard and adds a wishlist button overlay.

class _WishlistableCard extends StatefulWidget {
  final HostelModel hostel;
  final bool isWishlisted;
  final String uid;
  final WishlistService wishlistService;

  const _WishlistableCard({
    required this.hostel,
    required this.isWishlisted,
    required this.uid,
    required this.wishlistService,
  });

  @override
  State<_WishlistableCard> createState() => _WishlistableCardState();
}

class _WishlistableCardState extends State<_WishlistableCard>
    with SingleTickerProviderStateMixin {
  late bool _isWishlisted;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _isWishlisted = widget.isWishlisted;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_WishlistableCard old) {
    super.didUpdateWidget(old);
    if (old.isWishlisted != widget.isWishlisted) {
      setState(() => _isWishlisted = widget.isWishlisted);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save to wishlist')),
      );
      return;
    }

    // Optimistic UI update
    setState(() => _isWishlisted = !_isWishlisted);
    _animCtrl.forward().then((_) => _animCtrl.reverse());

    try {
      await widget.wishlistService.toggleWishlist(widget.uid, widget.hostel.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isWishlisted ? '❤ Added to wishlist' : 'Removed from wishlist',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (_) {
      // Revert on failure
      if (mounted) setState(() => _isWishlisted = !_isWishlisted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HotelCard(hostel: widget.hostel),

        // ── Floating wishlist button ─────────────────────────
        Positioned(
          top: 16,
          right: 26,
          child: GestureDetector(
            onTap: _toggle,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  _isWishlisted ? Icons.favorite : Icons.favorite_border,
                  color: _isWishlisted ? AppTheme.primaryRed : Colors.grey[500],
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
