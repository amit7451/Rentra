import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/firestore_service.dart';
import '../../services/wishlist_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/error_text.dart';
import '../search/search_screen.dart';
import 'hotel_card.dart';
import 'hostels_see_all_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/verification_dialog.dart';

// -----------------------------------------------------------------------------
// HomeScreen
// -----------------------------------------------------------------------------

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
  bool _isLoadingLocation = true;

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

  // -- Lifecycle ---------------------------------------------------------------

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

  Stream<List<HostelModel>> _buildHostelsStream() {
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

    if (targetLat != null && targetLng != null) {
      return _firestoreService
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
      return _firestoreService.getHostels(unitType: _selectedUnitType);
    }
  }

  void _updateHostelsStream() {
    setState(() => _hostelsStream = _buildHostelsStream().asBroadcastStream());
  }

  // -- Location ----------------------------------------------------------------

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          if (mounted) {
            setState(() => _isLoadingLocation = false);
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
            setState(() => _isLoadingLocation = false);
            _showPermissionDialog();
          }
          return;
        }
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          _showPermissionDialog();
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        _updateHostelsStream();
        await _fetchLiveLocation(position: position);
      }
    } catch (e) {
      debugPrint('Location error handled: $e');
      if (mounted) setState(() => _isLoadingLocation = false);
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

  // -- Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
            // -- Email Verification Banner --------------------------------
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

            // -- Hero Search Panel ----------------------------------------
            SliverAppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              floating: false,
              primary: true,
              toolbarHeight: 85,
              automaticallyImplyLeading: false,
              actions: const [
                // SizedBox.shrink(),
              ], // Suppresses extra hamburger icon
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
                            const Color(0xFF123A3C).withValues(alpha: 0.9),
                            const Color(0xFF184A4C).withValues(alpha: 0.95),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _GlassSearchBar(
                          hint: _selectedUnitType == 'hostel'
                              ? 'Search hostels, PGs'
                              : 'Search flats',
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
            // -- Premium Glass Banner --------------------------------
            SliverToBoxAdapter(
              child: Column(
                children: const [
                  SizedBox(height: 12), // optimal spacing from search panel
                  PremiumBannerSection(),
                ],
              ),
            ),

            StreamBuilder<List<HostelModel>>(
              stream: _hostelsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ErrorText(
                        message: 'Error: ${snapshot.error}',
                        onRetry: () => setState(() {}),
                      ),
                    ),
                  );
                }

                final hostels = snapshot.data ?? <HostelModel>[];
                final bool isLoading =
                    _isLoadingLocation ||
                    (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData);

                return StreamBuilder<List<String>>(
                  stream: _wishlistStream,
                  builder: (context, wishlistSnap) {
                    final wishlistIds = wishlistSnap.data ?? const <String>[];

                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHorizontalSection(
                            context: context,
                            title: 'Hostels Near You',
                            unitType: 'hostel',
                            allUnits: hostels,
                            wishlistIds: wishlistIds,
                            isLoading: isLoading,
                          ),
                          _buildHorizontalSection(
                            context: context,
                            title: 'Flats Near You',
                            unitType: 'flat',
                            allUnits: hostels,
                            wishlistIds: wishlistIds,
                            isLoading: isLoading,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            // SliverPersistentHeader(
            //   pinned: true,
            //   delegate: _LocationFilterDelegate(
            //     locationFilters: _locationFilters,
            //     selectedFilter: _selectedLocationFilter,
            //     currentPosition: _currentPosition,
            //     onFilterSelected: (name) {
            //       setState(() => _selectedLocationFilter = name);
            //       _updateHostelsStream();
            //       if (name == 'Live Location' && _currentPosition == null) {
            //         _getCurrentLocation();
            //       }
            //     },
            //   ),
            // ),
            // SliverToBoxAdapter(
            //   child: Padding(
            //     padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            //     child: _CategoryToggle(
            //       selected: _selectedUnitType,
            //       onChanged: (id) async {
            //         setState(() => _selectedUnitType = id);
            //         await Future.delayed(const Duration(milliseconds: 50));
            //         _updateHostelsStream();
            //       },
            //     ),
            //   ),
            // ),
            // SliverPersistentHeader(
            //   pinned: true,
            //   delegate: _StickyTitleDelegate(
            //     title: _selectedLocationFilter == 'Live Location'
            //         ? '${_selectedUnitType == 'hostel' ? 'Hostels' : 'Flats'} near you'
            //         : '${_selectedUnitType == 'hostel' ? 'Hostels' : 'Flats'} in $_selectedLocationFilter',
            //   ),
            // ),
            // StreamBuilder<List<HostelModel>>(
            //   stream: _hostelsStream,
            //   builder: (context, snapshot) {
            //     if (snapshot.connectionState == ConnectionState.waiting &&
            //         !snapshot.hasData) {
            //       return const SliverToBoxAdapter(
            //         child: LoadingIndicator(message: 'Loading hostels...'),
            //       );
            //     }
            //     if (snapshot.hasError) {
            //       return SliverToBoxAdapter(
            //         child: ErrorText(
            //           message: 'Error: ${snapshot.error}',
            //           onRetry: () => setState(() {}),
            //         ),
            //       );
            //     }

            //     final hostels = snapshot.data ?? [];
            //     if (hostels.isEmpty) {
            //       return const SliverToBoxAdapter(
            //         child: Center(
            //           heightFactor: 10,
            //           child: Text('No hostels found in this area'),
            //         ),
            //       );
            //     }

            //     return StreamBuilder<List<String>>(
            //       stream: _wishlistStream,
            //       builder: (context, wishlistSnap) {
            //         final wishlistIds = wishlistSnap.data ?? [];
            //         var filteredList = hostels
            //             .where((h) => h.unitType == _selectedUnitType)
            //             .take(10)
            //             .toList();

            //         return SliverPadding(
            //           padding: const EdgeInsets.only(bottom: 24),
            //           sliver: SliverList(
            //             delegate: SliverChildBuilderDelegate((context, index) {
            //               final hostel = filteredList[index];
            //               double? dist;
            //               if (_currentPosition != null &&
            //                   hostel.latitude != null &&
            //                   hostel.longitude != null) {
            //                 dist =
            //                     Geolocator.distanceBetween(
            //                       _currentPosition!.latitude,
            //                       _currentPosition!.longitude,
            //                       hostel.latitude!,
            //                       hostel.longitude!,
            //                     ) /
            //                     1000;
            //               }
            //               return PremiumHostelCard(
            //                 hostel: hostel,
            //                 isWishlisted: wishlistIds.contains(hostel.id),
            //                 uid: _uid,
            //                 wishlistService: _wishlistService,
            //                 distance: dist,
            //               );
            //             }, childCount: filteredList.length),
            //           ),
            //         );
            //       },
            //     );
            //   },
            // ),
            const SliverToBoxAdapter(child: SizedBox(height: 150)),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalSection({
    required BuildContext context,
    required String title,
    required String unitType,
    required List<HostelModel> allUnits,
    required List<String> wishlistIds,
    bool isLoading = false,
  }) {
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 236,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const visibleCards = 2.5;
                const horizontalPadding = 16.0;
                const spacing = 10.0;
                final rawWidth =
                    (constraints.maxWidth -
                        (horizontalPadding * 2) -
                        (spacing * (visibleCards - 1))) /
                    visibleCards;
                final cardWidth = rawWidth.clamp(120.0, 220.0).toDouble();

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    20,
                  ),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(width: spacing),
                  itemBuilder: (context, index) {
                    return _GlassSkeletonCard(width: cardWidth);
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    final filteredUnits = allUnits
        .where((h) => h.unitType.toLowerCase() == unitType.toLowerCase())
        .map((h) {
          double? dist;
          if (_currentPosition != null &&
              h.latitude != null &&
              h.longitude != null) {
            dist =
                Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  h.latitude!,
                  h.longitude!,
                ) /
                1000;
          }
          return _NearbyHostelEntry(hostel: h, distance: dist);
        })
        .toList();

    filteredUnits.sort((a, b) {
      if (a.distance == null && b.distance == null) return 0;
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });

    if (filteredUnits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Text(
          'No ${unitType.toLowerCase()}s near you right now.',
          style: const TextStyle(color: AppTheme.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _hostelsStream == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HostelsSeeAllScreen(
                            title: title,
                            unitType: unitType,
                            hostelsStream: _buildHostelsStream(),
                            currentPosition: _currentPosition,
                            uid: _uid,
                          ),
                        ),
                      ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color.fromARGB(255, 29, 219, 229),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 236,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const visibleCards = 2.5;
              const horizontalPadding = 16.0;
              const spacing = 10.0;
              final rawWidth =
                  (constraints.maxWidth -
                      (horizontalPadding * 2) -
                      (spacing * (visibleCards - 1))) /
                  visibleCards;
              final cardWidth = rawWidth.clamp(120.0, 220.0).toDouble();

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  20,
                ),
                itemCount: filteredUnits.length,
                separatorBuilder: (_, _) => const SizedBox(width: spacing),
                itemBuilder: (context, index) {
                  final entry = filteredUnits[index];
                  return PremiumHostelCard(
                    width: cardWidth,
                    hostel: entry.hostel,
                    isWishlisted: wishlistIds.contains(entry.hostel.id),
                    uid: _uid,
                    wishlistService: _wishlistService,
                    distance: entry.distance,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildGlassAppBar() {
    final bool isLive = _selectedLocationFilter == 'Live Location';

    final String displayTitle = isLive
        ? (_liveLocality.isNotEmpty ? _liveLocality : 'Locating...')
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
                        const Color(0xFF123A3C).withValues(alpha: 0.6),
                        const Color(0xFF184A4C).withValues(alpha: 0.95),
                      ],
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
                                        color: Colors.white.withValues(alpha: 0.55),
                                        size: 16,
                                      ),
                                    ],
                                  ),

                                  if (displaySub.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      displaySub,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.42),
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

                          /// Avatar / Profile
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: _uid.isEmpty
                                ? null
                                : FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(_uid)
                                      .snapshots(),
                            builder: (context, userSnap) {
                              final String? firestorePhotoUrl =
                                  userSnap.data?.data()?['photoUrl'] as String?;
                              final String? authPhotoUrl =
                                  FirebaseAuth.instance.currentUser?.photoURL;
                              final String? photoUrl =
                                  (firestorePhotoUrl != null &&
                                      firestorePhotoUrl.trim().isNotEmpty)
                                  ? firestorePhotoUrl
                                  : authPhotoUrl;

                              return _AvatarButton(
                                photoUrl: photoUrl,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.profile,
                                ),
                              );
                            },
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

  // -- Helpers -----------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// Glass Search Bar
// -----------------------------------------------------------------------------

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
                  const Color(0xFF1E3437).withValues(alpha: 0.9),
                  const Color(0xFF243C40).withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.7,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  hint,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
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

// -----------------------------------------------------------------------------
// Pulsing Live Badge
// -----------------------------------------------------------------------------

// class _LiveBadge extends StatefulWidget {
//   const _LiveBadge();

//   @override
//   State<_LiveBadge> createState() => _LiveBadgeState();
// }

// class _LiveBadgeState extends State<_LiveBadge>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _ctrl;
//   late final Animation<double> _anim;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1400),
//     )..repeat(reverse: true);
//     _anim = Tween<double>(
//       begin: 1.0,
//       end: 0.28,
//     ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
//       decoration: BoxDecoration(
//         color: const Color(0xFF34C759).withValues(alpha: 0.16),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: const Color(0xFF34C759).withValues(alpha: 0.35),
//           width: 0.6,
//         ),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           AnimatedBuilder(
//             animation: _anim,
//             builder: (_, _) => Opacity(
//               opacity: _anim.value,
//               child: Container(
//                 width: 5,
//                 height: 5,
//                 decoration: const BoxDecoration(
//                   color: Color(0xFF34C759),
//                   shape: BoxShape.circle,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 4),
//           const Text(
//             'Live',
//             style: TextStyle(
//               color: Color(0xFF34C759),
//               fontSize: 9.5,
//               fontWeight: FontWeight.w700,
//               letterSpacing: 0.2,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class PremiumBannerSection extends StatefulWidget {
  const PremiumBannerSection({super.key});

  @override
  State<PremiumBannerSection> createState() => _PremiumBannerSectionState();
}

class _PremiumBannerSectionState extends State<PremiumBannerSection> {
  final PageController _controller = PageController(viewportFraction: 1);
  int _currentIndex = 0;

  final List<Map<String, dynamic>> banners = [
    {"title": "Explore Rentals", "icon": Icons.home_rounded},
    {"title": "Find Your Dream Home", "icon": Icons.location_city},
    {"title": "Affordable PGs Nearby", "icon": Icons.apartment},
    {"title": "List Your Property", "icon": Icons.add_business},
  ];

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_controller.hasClients) {
        _currentIndex = (_currentIndex + 1) % banners.length;

        _controller.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AspectRatio(
        aspectRatio: 2 / 1, // 👈 IMPORTANT (your requirement)
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              /// 🌫️ FIXED GLASS BACKGROUND
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(),
              ),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),

                  /// 🌊 TEAL FROSTED GLASS (LIGHT MODE FIXED)
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF224E58).withValues(alpha: 0.75),
                            const Color(0xFF14363F).withValues(alpha: 0.75),
                          ]
                        : [
                            const Color(
                              0xFF14B8A6,
                            ).withValues(alpha: 0.18), // 👈 teal tint
                            Colors.white.withValues(alpha: 0.25), // 👈 softness
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),

                  /// subtle border
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFF14B8A6).withValues(alpha: 0.35),
                    width: 1,
                  ),

                  /// soft glow (less white, more natural)
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.4)
                          : const Color(0xFF14B8A6).withValues(alpha: 0.15),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(
                          0xFF14B8A6,
                        ).withValues(alpha: isDark ? 0.05 : 0.12),
                        Colors.transparent,
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [Colors.white.withValues(alpha: 0.06), Colors.transparent]
                          : [
                              Colors.white.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              /// 🔁 SLIDING CONTENT
              PageView.builder(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemCount: banners.length,
                itemBuilder: (context, index) {
                  final item = banners[index];

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: _BannerContent(
                      title: item["title"],
                      icon: item["icon"],
                      isDark: isDark,
                    ),
                  );
                },
              ),

              /// 🔘 DOT INDICATOR
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    banners.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: _currentIndex == index ? 18 : 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _currentIndex == index
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.grey.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;

  const _BannerContent({
    required this.title,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        /// TEXT
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),

        /// ICON GLASS BUBBLE
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.05),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.7),
                      Colors.white.withValues(alpha: 0.2),
                    ],
            ),
          ),
          child: Icon(
            icon,
            size: 26,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Glass Chip (icon container)
// -----------------------------------------------------------------------------

class _GlassChip extends StatelessWidget {
  final Widget child;
  const _GlassChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 0.6),
      ),
      child: Center(child: child),
    );
  }
}

// -----------------------------------------------------------------------------
// AppBar Action Button (icon + red badge)
// -----------------------------------------------------------------------------

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
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
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

// -----------------------------------------------------------------------------
// Avatar / Profile Button
// -----------------------------------------------------------------------------

class _AvatarButton extends StatelessWidget {
  final VoidCallback onTap;
  final String? photoUrl;

  const _AvatarButton({required this.onTap, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 0.6),
        ),
        child: Center(
          child: CircleAvatar(
            radius: 13,
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            child: hasPhoto
                ? ClipOval(
                    child: Image.network(
                      photoUrl!,
                      width: 26,
                      height: 26,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF184A4C),
                        size: 15,
                      ),
                    ),
                  )
                : const Icon(
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

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
// Location Picker Bottom Sheet
// -----------------------------------------------------------------------------

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
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.06),
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
                    color: Colors.black.withValues(alpha: 0.12),
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

// -----------------------------------------------------------------------------
// Wishlisted Card Wrapper
// -----------------------------------------------------------------------------

class _NearbyHostelEntry {
  final HostelModel hostel;
  final double? distance;

  const _NearbyHostelEntry({required this.hostel, this.distance});
}

class _GlassSkeletonCard extends StatefulWidget {
  final double width;
  const _GlassSkeletonCard({this.width = 150});

  @override
  State<_GlassSkeletonCard> createState() => _GlassSkeletonCardState();
}

class _GlassSkeletonCardState extends State<_GlassSkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _anim = Tween<double>(begin: 0.3, end: 0.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = widget.width <= 160;
    final imageHeight = isCompact ? 112.0 : 126.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = _anim.value;

        return SizedBox(
          width: widget.width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                /// 🌫️ glass blur base
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(),
                ),

                /// 🧊 glass surface
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(
                                0xFF224E58,
                              ).withValues(alpha: 0.75 * opacity),
                              const Color(
                                0xFF14363F,
                              ).withValues(alpha: 0.75 * opacity),
                            ]
                          : [
                              const Color(0xFF14B8A6).withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0.4),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25 * opacity)
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),

                /// 📦 skeleton content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// image placeholder
                    Container(
                      height: imageHeight,
                      width: double.infinity,
                      color: isDark
                          ? Colors.white.withValues(alpha: opacity * 0.2)
                          : Colors.grey.withValues(alpha: opacity),
                    ),

                    Padding(
                      padding: EdgeInsets.all(isCompact ? 8.0 : 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _line(opacity, width: 90, isDark: isDark),
                          const SizedBox(height: 10),
                          _line(opacity, width: 60, isDark: isDark),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _line(
                                opacity,
                                width: 50,
                                isDark: isDark,
                                height: 14,
                              ),
                              _line(
                                opacity,
                                width: 30,
                                isDark: isDark,
                                height: 14,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _line(
    double opacity, {
    required double width,
    required bool isDark,
    double height = 12,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: opacity * 0.25)
            : Colors.grey.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
