import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final _wishlistService = WishlistService();
  late final String _uid;

  String _selectedUnitType = 'hostel';
  bool _isVerified = true;

  // Location
  String _selectedLocationFilter = 'Live Location';
  Position? _currentPosition;
  String _liveLocality = '';
  String _liveSubLocality = '';
  bool _isFetchingLocation = false;

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

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _initStreams();

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

    setState(() => _hostelsStream = stream);
  }

  // ── Location ────────────────────────────────────────────────────────────────

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
          if (mounted) _showPermissionDialog();
          return;
        }
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) _showPermissionDialog();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      if (mounted) {
        setState(() => _currentPosition = position);
        _updateHostelsStream();
        await _fetchLiveLocation(position: position);
      }
    } catch (e) {
      debugPrint('Location error handled: $e');
    }
  }

  Future<void> _fetchLiveLocation({Position? position}) async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);

    try {
      final targetPosition = position ?? _currentPosition;
      if (targetPosition == null) return;

      final placemarks = await placemarkFromCoordinates(
        targetPosition.latitude,
        targetPosition.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final locality = (place.subLocality?.isNotEmpty ?? false)
            ? place.subLocality!
            : (place.locality?.isNotEmpty ?? false)
            ? place.locality!
            : 'Current Location';
        final subLine = [
          place.administrativeArea ?? '',
          place.country ?? '',
        ].where((v) => v.trim().isNotEmpty).join(', ');
        setState(() {
          _liveLocality = locality;
          _liveSubLocality = subLine;
        });
      }
    } catch (_) {
      setState(() {
        _liveLocality = 'Current Location';
        _liveSubLocality = '';
      });
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _checkVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (mounted) setState(() => _isVerified = user.emailVerified);
      }
    } catch (e) {
      debugPrint('Verification error: $e');
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: AppDrawer(),
      appBar: _buildGlassAppBar(),
      body: RefreshIndicator(
        color: AppTheme.primaryTeal,
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
            // ── Email Verification Banner ────────────────────────────────
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
                    color: const Color(0xFFFFC107),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.black87,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Email not verified. Tap to verify now.',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.black54,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Hero Search Panel ────────────────────────────────────────
            SliverAppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              floating: false,
              primary: true,
              toolbarHeight: 85,
              automaticallyImplyLeading: false,
              expandedHeight: 85,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF123A3C).withOpacity(0.9),
                            const Color(0xFF184A4C).withOpacity(0.95),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 0.6,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _GlassSearchBar(
                          hint: _selectedUnitType == 'hostel'
                              ? 'Search hostels, PGs…'
                              : 'Search flats…',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SearchScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Location Filter Row ──────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _LocationFilterDelegate(
                locationFilters: _locationFilters,
                selectedFilter: _selectedLocationFilter,
                currentPosition: _currentPosition,
                onFilterSelected: (name) {
                  setState(() => _selectedLocationFilter = name);
                  _updateHostelsStream();
                  if (name == 'Live Location' && _currentPosition == null) {
                    _getCurrentLocation();
                  }
                },
              ),
            ),

            // ── Category Toggle ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _CategoryToggle(
                  selected: _selectedUnitType,
                  onChanged: (id) async {
                    setState(() => _selectedUnitType = id);
                    await Future.delayed(const Duration(milliseconds: 50));
                    _updateHostelsStream();
                  },
                ),
              ),
            ),

            // ── Section Title ────────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTitleDelegate(
                title: _selectedLocationFilter == 'Live Location'
                    ? '${_selectedUnitType == 'hostel' ? 'Hostels' : 'Flats'} near you'
                    : '${_selectedUnitType == 'hostel' ? 'Hostels' : 'Flats'} in $_selectedLocationFilter',
              ),
            ),

            // ── Hostel List ──────────────────────────────────────────────
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
                    var filteredList = hostels
                        .where((h) => h.unitType == _selectedUnitType)
                        .take(10)
                        .toList();

                    return SliverPadding(
                      padding: const EdgeInsets.only(bottom: 24),
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

  PreferredSizeWidget _buildGlassAppBar() {
    final bool isLive = _selectedLocationFilter == 'Live Location';

    final String displayTitle = isLive
        ? (_liveLocality.isNotEmpty ? _liveLocality : 'Locating…')
        : _selectedLocationFilter;

    final String displaySub = isLive ? _liveSubLocality : '';

    return PreferredSize(
      preferredSize: const Size.fromHeight(110),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2F31), Color(0xFF184A4C)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 19),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF123A3C).withOpacity(0.6),
                        const Color(0xFF184A4C).withOpacity(0.95),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 0.8,
                    ),
                  ),
                  child: SizedBox(
                    height: 80,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          /// Location icon
                          const _GlassChip(
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),

                          const SizedBox(width: 10),

                          /// Location text
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _showLocationSheet,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 3),

                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          displayTitle,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.2,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white.withOpacity(0.55),
                                        size: 16,
                                      ),
                                    ],
                                  ),

                                  if (displaySub.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      displaySub,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.42),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          /// Wishlist button
                          StreamBuilder<List<String>>(
                            stream: _wishlistStream,
                            builder: (context, snap) {
                              return _AppBarButton(
                                count: snap.data?.length ?? 0,
                                icon: Icons.favorite_border_rounded,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.wishlist,
                                ),
                              );
                            },
                          ),

                          const SizedBox(width: 8),

                          /// Notifications button
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _firestoreService.getUserNotifications(
                              _uid,
                            ),
                            builder: (context, snapshot) {
                              final int unread = (snapshot.data ?? [])
                                  .where((n) => n['isRead'] == false)
                                  .length;

                              return _AppBarButton(
                                count: unread,
                                icon: Icons.notifications_outlined,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.notifications,
                                ),
                              );
                            },
                          ),

                          const SizedBox(width: 8),

                          /// Avatar / Drawer
                          Builder(
                            builder: (ctx) => _AvatarButton(
                              onTap: () => Scaffold.of(ctx).openDrawer(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Bottom sheet to pick a different city / switch to live location.
  void _showLocationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        locationFilters: _locationFilters,
        selectedFilter: _selectedLocationFilter,
        onSelected: (name) {
          setState(() => _selectedLocationFilter = name);
          _updateHostelsStream();
          if (name == 'Live Location' && _currentPosition == null) {
            _getCurrentLocation();
          }
        },
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Location Access Required'),
        content: const Text(
          'Location permission is permanently denied. Please enable it in app settings.',
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

// ─────────────────────────────────────────────────────────────────────────────
// Glass Search Bar
// ─────────────────────────────────────────────────────────────────────────────

class _GlassSearchBar extends StatelessWidget {
  final String hint;
  final VoidCallback onTap;

  const _GlassSearchBar({required this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E3437).withOpacity(0.9),
                  const Color(0xFF243C40).withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 0.7,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: Colors.white.withOpacity(0.55),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  hint,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing Live Badge
// ─────────────────────────────────────────────────────────────────────────────

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 1.0,
      end: 0.28,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF34C759).withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF34C759).withOpacity(0.35),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Opacity(
              opacity: _anim.value,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFF34C759),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Live',
            style: TextStyle(
              color: Color(0xFF34C759),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Chip (icon container)
// ─────────────────────────────────────────────────────────────────────────────

class _GlassChip extends StatelessWidget {
  final Widget child;
  const _GlassChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.16), width: 0.6),
      ),
      child: Center(child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppBar Action Button (icon + red badge)
// ─────────────────────────────────────────────────────────────────────────────

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const _AppBarButton({
    required this.icon,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.16),
                width: 0.6,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF184A4C),
                    width: 1.5,
                  ),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar / Drawer Button
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AvatarButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.16), width: 0.6),
        ),
        child: Center(
          child: CircleAvatar(
            radius: 13,
            backgroundColor: Colors.white.withOpacity(0.88),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF184A4C),
              size: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Toggle (Hostels / Flats)
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryToggle extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;

  const _CategoryToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleOption(
              id: 'hostel',
              label: 'Hostels',
              selected: selected,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ToggleOption(
              id: 'flat',
              label: 'Flats',
              selected: selected,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String id;
  final String label;
  final String selected;
  final void Function(String) onChanged;

  const _ToggleOption({
    required this.id,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == id;
    return GestureDetector(
      onTap: () => onChanged(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF184A4C) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF184A4C).withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: isSelected ? Colors.white : const Color(0xFF184A4C),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Filter Sliver Header
// ─────────────────────────────────────────────────────────────────────────────

class _LocationFilterDelegate extends SliverPersistentHeaderDelegate {
  final List<Map<String, dynamic>> locationFilters;
  final String selectedFilter;
  final Position? currentPosition;
  final void Function(String) onFilterSelected;

  _LocationFilterDelegate({
    required this.locationFilters,
    required this.selectedFilter,
    required this.currentPosition,
    required this.onFilterSelected,
  });

  @override
  double get minExtent => 0;
  @override
  double get maxExtent => 120;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / maxExtent).clamp(0.0, 1.0);
    final opacity = (1.0 - t * 1.5).clamp(0.0, 1.0);
    final scale = (1.0 - t * 0.5).clamp(0.0, 1.0);
    final translateY = -shrinkOffset * 0.4;

    return Container(
      height: maxExtent,
      color: Colors.grey[50]!.withOpacity(1.0 - t),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, translateY),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: 110,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: locationFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
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
                                duration: const Duration(milliseconds: 280),
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.amber.withOpacity(0.55)
                                        : Colors.grey.shade200,
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? const Color(
                                              0xFFFFF176,
                                            ).withOpacity(0.55)
                                          : Colors.black.withOpacity(0.04),
                                      blurRadius: isSelected ? 12 : 6,
                                      spreadRadius: isSelected ? 2 : 0,
                                      offset: isSelected
                                          ? Offset.zero
                                          : const Offset(0, 2),
                                    ),
                                    if (isSelected)
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFFF59D,
                                        ).withOpacity(0.3),
                                        blurRadius: 18,
                                        spreadRadius: 5,
                                      ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: filter['image'] != null
                                      ? Image.asset(
                                          filter['image'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.location_city,
                                            color: isSelected
                                                ? AppTheme.primaryTeal
                                                : Colors.black54,
                                            size: 28,
                                          ),
                                        )
                                      : Icon(
                                          filter['icon'] ?? Icons.location_city,
                                          color: isSelected
                                              ? AppTheme.primaryTeal
                                              : Colors.black87,
                                          size: 28,
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
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.black45,
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
  bool shouldRebuild(covariant _LocationFilterDelegate old) =>
      selectedFilter != old.selectedFilter ||
      currentPosition != old.currentPosition;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky Section Title
// ─────────────────────────────────────────────────────────────────────────────

class _StickyTitleDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  const _StickyTitleDelegate({required this.title});

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
      color: Colors.grey[50],
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTitleDelegate old) => title != old.title;
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _LocationPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> locationFilters;
  final String selectedFilter;
  final void Function(String) onSelected;

  const _LocationPickerSheet({
    required this.locationFilters,
    required this.selectedFilter,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.black.withOpacity(0.06),
              width: 0.6,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Location',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: locationFilters.map((filter) {
                  final name = filter['name'] as String;
                  final isSelected = selectedFilter == name;
                  return GestureDetector(
                    onTap: () {
                      onSelected(name);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF184A4C)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF184A4C)
                              : Colors.grey.shade200,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            filter['icon'] as IconData? ?? Icons.location_city,
                            size: 15,
                            color: isSelected ? Colors.white : Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wishlisted Card Wrapper
// ─────────────────────────────────────────────────────────────────────────────

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
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedScale(
              scale: isWishlisted ? 1.18 : 1.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              child: IconButton(
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey<bool>(isWishlisted),
                    color: isWishlisted ? AppTheme.primaryTeal : Colors.grey,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  if (uid.isEmpty) return;
                  isWishlisted
                      ? wishlistService.removeFromWishlist(uid, hostel.id)
                      : wishlistService.addToWishlist(uid, hostel.id);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
