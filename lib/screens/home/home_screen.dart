import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../services/wishlist_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_text.dart';
import '../search/search_screen.dart';
import 'hotel_card.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/verification_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final _wishlistService = WishlistService();
  late final String _uid;

  String _selectedUnitType = 'hostel'; // 'hostel' or 'flat'
  bool _isVerified = true;

  // Location
  String _selectedLocationFilter = 'Live Location';
  Position? _currentPosition;

  // Optimized Streams to prevent infinite rebuild loops
  Stream<List<HostelModel>>? _hostelsStream;
  Stream<List<String>>? _wishlistStream;

  final List<Map<String, dynamic>> _locationFilters = [
    {'name': 'Live Location', 'lat': null, 'lng': null, 'icon': Icons.near_me},
    {
      'name': 'Ghaziabad',
      'lat': 28.6692,
      'lng': 77.4538,
      'image': 'assets/images/ghaziabad.png',
    },
    {
      'name': 'Noida',
      'lat': 28.5355,
      'lng': 77.3910,
      'image': 'assets/images/noida.png',
    },
    {
      'name': 'Delhi',
      'lat': 28.6139,
      'lng': 77.2090,
      'image': 'assets/images/delhi.png',
    },
    {
      'name': 'Bengaluru',
      'lat': 12.9716,
      'lng': 77.5946,
      'image': 'assets/images/bengaluru.png',
    },
    {
      'name': 'Mumbai',
      'lat': 19.0760,
      'lng': 72.8777,
      'image': 'assets/images/mumbai.png',
    },
    {
      'name': 'Hyderabad',
      'lat': 17.3850,
      'lng': 78.4867,
      'image': 'assets/images/hyderabad.png',
    },
    {
      'name': 'Pune',
      'lat': 18.5204,
      'lng': 73.8567,
      'image': 'assets/images/pune.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _initStreams();

    // Delay initial checks to let the UI render and avoid blocking startup
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _checkVerification();
        _getCurrentLocation();
      }
    });
  }

  void _initStreams() {
    _wishlistStream = _uid.isEmpty
        ? Stream.value([])
        : _wishlistService.watchWishlist(_uid).asBroadcastStream();
    _updateHostelsStream();
  }

  void _updateHostelsStream() {
    double? targetLat;
    double? targetLng;

    if (_selectedLocationFilter == 'Live Location') {
      targetLat = _currentPosition?.latitude;
      targetLng = _currentPosition?.longitude;
    } else {
      final city = _locationFilters.firstWhere(
        (e) => e['name'] == _selectedLocationFilter,
        orElse: () => {},
      );
      if (city.isNotEmpty) {
        targetLat = city['lat'];
        targetLng = city['lng'];
      }
    }

    Stream<List<HostelModel>> stream;
    if (targetLat != null && targetLng != null) {
      stream = _firestoreService
          .getHostelsNearLocation(lat: targetLat, lng: targetLng)
          .map((list) {
            if (_selectedLocationFilter != 'Live Location') {
              final cityLower = _selectedLocationFilter.toLowerCase();
              return list
                  .where(
                    (h) =>
                        h.city.toLowerCase().contains(cityLower) ||
                        h.address.toLowerCase().contains(cityLower),
                  )
                  .toList();
            }
            return list;
          });
    } else {
      stream = _firestoreService.getHostels(unitType: _selectedUnitType);
    }

    setState(() {
      _hostelsStream = stream;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location permission is required to find hostels near you.',
                ),
              ),
            );
          }
          return;
        } else if (requested == LocationPermission.deniedForever) {
          if (mounted) {
            _showPermissionDialog();
          }
          return;
        }
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermissionDialog();
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _updateHostelsStream();
      }
    } catch (e) {
      debugPrint('Location error handled: $e');
    }
  }

  Future<void> _checkVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (mounted) {
          setState(() {
            _isVerified = user.emailVerified;
          });
        }
      }
    } catch (e) {
      debugPrint('Verification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: AppDrawer(),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.grey[50],
        toolbarHeight:
            60, // Increased to fit the large logo and remove secondary gaps
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.0),
          child: Image.asset(
            'assets/icons/app_icon.png',
            height: 100, // Maximum height for a "major" horizontal feel
            width: 200, // Wide enough for a full horizontal logo branding
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.apartment, color: Colors.black87, size: 40),
          ),
        ),
        actions: [
          StreamBuilder<List<String>>(
            stream: _wishlistStream,
            builder: (context, snap) {
              final count = snap.data?.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.favorite_border,
                      color: Colors.black87,
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
                          color: AppTheme.primaryRed,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
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
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestoreService.getUserNotifications(_uid),
            builder: (context, snapshot) {
              final unreadCount = (snapshot.data ?? [])
                  .where((n) => n['isRead'] == false)
                  .length;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.black87,
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.notifications),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryRed,
        onRefresh: () async {
          await _checkVerification();
          await _getCurrentLocation();
          if (mounted) setState(() {});
          await Future.delayed(const Duration(seconds: 1));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            if (!_isVerified)
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => showVerificationDialog(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    decoration: const BoxDecoration(color: Colors.amber),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.black87,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Email not verified. Tap to verify now.',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.black54,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            SliverAppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              pinned: false,
              floating: true,
              primary:
                  false, // Prevents gap/padding duplication between AppBar and SliverAppBar
              automaticallyImplyLeading: false,
              expandedHeight: 160,
              backgroundColor: Colors.grey[50],
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // ─── 1. Redesigned Search Bar ─────────────────
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search,
                                color: Colors.black87,
                                size: 26,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _selectedUnitType == 'hostel'
                                    ? 'Search for hostels/pgs'
                                    : 'Search for flats',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ─── 2. Image-Based Category Toggles ──────────
                      Row(
                        children: [
                          Expanded(
                            child: _buildCategoryItem(
                              id: 'hostel',
                              label: 'Hostels',
                              assetPath: 'assets/images/hostel.png',
                              fallbackIcon: Icons.apartment,
                            ),
                          ),
                          Expanded(
                            child: _buildCategoryItem(
                              id: 'flat',
                              label: 'Flats',
                              assetPath: 'assets/images/flat.png',
                              fallbackIcon: Icons.home_work_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // ─── 3. Soft Divider with Shadow ──────────────
                      Container(
                        height: 1,
                        width: double.infinity,
                        clipBehavior: Clip.none,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.black.withOpacity(0.06),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Location Filter Shrinking Header ───────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _LocationFilterDelegate(
                locationFilters: _locationFilters,
                selectedFilter: _selectedLocationFilter,
                onFilterSelected: (name) {
                  setState(() {
                    _selectedLocationFilter = name;
                  });
                  _updateHostelsStream(); // Update stream on filter change
                  if (name == 'Live Location' && _currentPosition == null) {
                    _getCurrentLocation();
                  }
                },
                currentPosition: _currentPosition,
              ),
            ),

            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTitleDelegate(
                title: _selectedLocationFilter == 'Live Location'
                    ? '${_selectedUnitType == 'hostel' ? 'Hostels' : 'Flats'} near you'
                    : '${_selectedUnitType == 'hostel' ? 'Hostels' : 'Flats'} in $_selectedLocationFilter',
              ),
            ),

            StreamBuilder<List<HostelModel>>(
              stream: _hostelsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const SliverToBoxAdapter(
                    child: LoadingIndicator(message: 'Loading hostels...'),
                  );
                }

                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: ErrorText(
                      message: 'Error: ${snapshot.error}',
                      onRetry: () => setState(() {}),
                    ),
                  );
                }

                final hostels = snapshot.data ?? [];
                if (hostels.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      heightFactor: 10,
                      child: Text('No hostels found in this area'),
                    ),
                  );
                }

                return StreamBuilder<List<String>>(
                  stream: _wishlistStream,
                  builder: (context, wishlistSnap) {
                    final wishlistIds = wishlistSnap.data ?? [];
                    var filteredList = _selectedUnitType == 'all'
                        ? hostels
                        : hostels
                              .where((h) => h.unitType == _selectedUnitType)
                              .toList();

                    if (filteredList.length > 10) {
                      filteredList = filteredList.take(10).toList();
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.only(bottom: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final hostel = filteredList[index];
                          double? dist;
                          if (_currentPosition != null &&
                              hostel.latitude != null &&
                              hostel.longitude != null) {
                            dist =
                                Geolocator.distanceBetween(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                  hostel.latitude!,
                                  hostel.longitude!,
                                ) /
                                1000;
                          }

                          return _WishlistableCard(
                            hostel: hostel,
                            isWishlisted: wishlistIds.contains(hostel.id),
                            uid: _uid,
                            wishlistService: _wishlistService,
                            distance: dist,
                          );
                        }, childCount: filteredList.length),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem({
    required String id,
    required String label,
    required String assetPath,
    required IconData fallbackIcon,
  }) {
    final isSelected = _selectedUnitType == id;
    return GestureDetector(
      onTap: () async {
        setState(() => _selectedUnitType = id);
        // Small delay to let the toggle animation start before changing data
        await Future.delayed(const Duration(milliseconds: 50));
        _updateHostelsStream();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Decoration Layer: Safe from overshooting (Prevents negative blurRadius crash)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isSelected
                  ? RadialGradient(
                      colors: [
                        const Color(0xFFFFF9C4).withOpacity(0.5),
                        Colors.transparent,
                      ],
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFFFFF176).withOpacity(0.3)
                      : Colors.transparent,
                  blurRadius: isSelected ? 12 : 0,
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            // 2. Animation Layer: Elastic Bouncy Effect
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              transform: Matrix4.translationValues(
                0.0,
                isSelected ? -8.0 : 0.0,
                0.0,
              )..scale(isSelected ? 1.25 : 1.0, isSelected ? 1.25 : 1.0),
              alignment: Alignment.center,
              child: Opacity(
                opacity: isSelected ? 1.0 : 0.6,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    fallbackIcon,
                    size: 24,
                    color: isSelected ? Colors.black87 : Colors.black45,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.black87 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6), // Adjusted for floating space
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: isSelected ? 60 : 0,
            color: Colors.black87,
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is permanently denied. Please enable it in app settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

class _WishlistableCard extends StatelessWidget {
  final HostelModel hostel;
  final bool isWishlisted;
  final String uid;
  final WishlistService wishlistService;
  final double? distance;

  const _WishlistableCard({
    required this.hostel,
    required this.isWishlisted,
    required this.uid,
    required this.wishlistService,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HotelCard(hostel: hostel, distance: distance),
        Positioned(
          top: 20,
          right: 28,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedScale(
              scale: isWishlisted ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              child: IconButton(
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                  child: Icon(
                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey<bool>(isWishlisted),
                    color: isWishlisted ? Colors.red : Colors.grey,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  if (uid.isEmpty) return;
                  if (isWishlisted) {
                    wishlistService.removeFromWishlist(uid, hostel.id);
                  } else {
                    wishlistService.addToWishlist(uid, hostel.id);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationFilterDelegate extends SliverPersistentHeaderDelegate {
  final List<Map<String, dynamic>> locationFilters;
  final String selectedFilter;
  final Function(String) onFilterSelected;
  final Position? currentPosition;

  _LocationFilterDelegate({
    required this.locationFilters,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.currentPosition,
  });

  @override
  double get minExtent => 0;

  @override
  double get maxExtent => 120; // Increased to prevent overflow on larger fonts

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Faster fade and scale to meet the user's "shrink as scrolls up" request
    final double shrinkPercentage = (shrinkOffset / maxExtent).clamp(0.0, 1.0);
    final double opacity = (1.0 - (shrinkPercentage * 1.5)).clamp(0.0, 1.0);
    final double scale = (1.0 - (shrinkPercentage * 0.5)).clamp(0.0, 1.0);

    // Move up slightly faster than the scroll to feel like it's "shrinking into" the header above
    final double translationY = -shrinkOffset * 0.4;

    return Container(
      height: maxExtent,
      // We use a transparent container to ensure the glow from the selected circle
      // can "override" or bleed into the portion above without being cut off
      color: Colors.grey[50]?.withOpacity(1.0 - shrinkPercentage),
      child: Stack(
        clipBehavior:
            Clip.none, // CRITICAL: Fixes the "flattened at the top" glow issue
        children: [
          Positioned(
            top: 0, // Really tight top space
            left: 0,
            right: 0,
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, translationY),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height:
                        110, // Increased to accommodate text + padding safely
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        4, // Extremely tight top padding
                        16,
                        0,
                      ), // Removed bottom padding
                      scrollDirection: Axis.horizontal,
                      clipBehavior:
                          Clip.none, // Allow glow to overflow list bounds
                      itemCount: locationFilters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final filter = locationFilters[index];
                        final name = filter['name'] as String;
                        final isSelected = selectedFilter == name;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => onFilterSelected(name),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.amber.withOpacity(0.5)
                                        : Colors.grey.shade200,
                                    width: 2,
                                  ),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? const Color(
                                              0xFFFFF176,
                                            ).withOpacity(0.5)
                                          : Colors.black.withOpacity(0.04),
                                      blurRadius: isSelected ? 10 : 6,
                                      spreadRadius: isSelected ? 2 : 0,
                                      offset: isSelected
                                          ? Offset.zero
                                          : const Offset(0, 2),
                                    ),
                                    BoxShadow(
                                      color: isSelected
                                          ? const Color(
                                              0xFFFFF59D,
                                            ).withOpacity(0.3)
                                          : Colors.transparent,
                                      blurRadius: isSelected ? 15 : 0,
                                      spreadRadius: isSelected ? 4 : 0,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: filter['image'] != null
                                      ? Image.asset(
                                          filter['image'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, _, _) => Icon(
                                            Icons.location_city,
                                            color: isSelected
                                                ? AppTheme.primaryRed
                                                : Colors.black54,
                                            size: 30,
                                          ),
                                        )
                                      : Icon(
                                          filter['icon'] ?? Icons.location_city,
                                          color: isSelected
                                              ? AppTheme.primaryRed
                                              : Colors.black87,
                                          size: 30,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _LocationFilterDelegate oldDelegate) {
    return selectedFilter != oldDelegate.selectedFilter ||
        currentPosition != oldDelegate.currentPosition;
  }
}

class _StickyTitleDelegate extends SliverPersistentHeaderDelegate {
  final String title;

  _StickyTitleDelegate({required this.title});

  @override
  double get minExtent => 50;

  @override
  double get maxExtent => 50;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      width: double.infinity,
      color: Colors.grey[50], // Match page background
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTitleDelegate oldDelegate) {
    return title != oldDelegate.title;
  }
}
