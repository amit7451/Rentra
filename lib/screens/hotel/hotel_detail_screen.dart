import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/error_text.dart';
import '../../widgets/primary_button.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class HotelDetailScreen extends StatefulWidget {
  final String hostelId;
  final bool hideBookingButton;
  final double? distance;

  const HotelDetailScreen({
    super.key,
    required this.hostelId,
    this.hideBookingButton = false,
    this.distance,
  });

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) setState(() => _currentPosition = pos);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<HostelModel?>(
      stream: firestoreService.watchHostel(widget.hostelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonLoader();
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorText(
              message: 'Error loading hostel: ${snapshot.error}',
              onRetry: () {
                // Trigger rebuild
              },
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const ErrorText(message: 'Hostel not found'),
          );
        }

        final hostel = snapshot.data!;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App bar with image
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: hostel.images.isNotEmpty
                      ? PageView.builder(
                          itemCount: hostel.images.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              hostel.images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppTheme.lightGrey,
                                  child: const Icon(
                                    Icons.hotel,
                                    size: 64,
                                    color: AppTheme.grey,
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : Container(
                          color: AppTheme.lightGrey,
                          child: const Icon(
                            Icons.hotel,
                            size: 64,
                            color: AppTheme.grey,
                          ),
                        ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    hostel.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.displaySmall,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Unit type chip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightGrey,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    hostel.unitType.toLowerCase() == 'flat'
                                        ? 'Flat'
                                        : 'Hostel / PG',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Color(0xFFFFB400),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hostel.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              if ((widget.distance != null ||
                                      _currentPosition != null) &&
                                  hostel.latitude != null &&
                                  hostel.longitude != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.near_me,
                                          color: AppTheme.primaryRed,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          widget.distance != null
                                              ? '${widget.distance!.toStringAsFixed(1)} km'
                                              : '${(Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, hostel.latitude!, hostel.longitude!) / 1000).toStringAsFixed(1)} km',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Reviews count
                      Text(
                        '${hostel.totalReviews} reviews',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),

                      const SizedBox(height: 16),

                      // Location
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppTheme.primaryRed,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${hostel.address}, ${hostel.city}, ${hostel.country}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Price
                      if (hostel.unitType == 'flat')
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Rent Price',
                                    style: TextStyle(
                                      color: AppTheme.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '₹${hostel.rentPrice.toStringAsFixed(0)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          color: AppTheme.primaryRed,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    hostel.rentPeriod == 'monthly'
                                        ? '/ Month'
                                        : '/ Year',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              _buildAvailabilityBadge(
                                hostel.availableRooms,
                                isFlat: true,
                                capacity: hostel.flatCapacity,
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.lightGrey),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Seater',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Price',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Availability',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              _buildSeaterRow(
                                context,
                                '1 Seater',
                                hostel.price1Seater,
                                hostel.rooms1Seater,
                                hostel.rentPeriod,
                              ),
                              _buildSeaterRow(
                                context,
                                '2 Seater',
                                hostel.price2Seater,
                                hostel.rooms2Seater,
                                hostel.rentPeriod,
                              ),
                              _buildSeaterRow(
                                context,
                                '3 Seater',
                                hostel.price3Seater,
                                hostel.rooms3Seater,
                                hostel.rentPeriod,
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Description
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hostel.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),

                      const SizedBox(height: 24),

                      // Amenities
                      Text(
                        'Amenities',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: hostel.amenities.map((amenity) {
                          return Chip(
                            label: Text(amenity),
                            backgroundColor: AppTheme.lightGrey,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Map Section
                      if (hostel.latitude != null &&
                          hostel.longitude != null) ...[
                        Text(
                          'Location',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () async {
                            final url = Uri.parse(
                              'https://www.google.com/maps/dir/?api=1&destination=${hostel.latitude},${hostel.longitude}',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.lightGrey),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: LatLng(
                                        hostel.latitude!,
                                        hostel.longitude!,
                                      ),
                                      zoom: 14,
                                    ),
                                    markers: {
                                      Marker(
                                        markerId: const MarkerId(
                                          'hostelLocation',
                                        ),
                                        position: LatLng(
                                          hostel.latitude!,
                                          hostel.longitude!,
                                        ),
                                      ),
                                    },
                                    liteModeEnabled: true,
                                    zoomControlsEnabled: false,
                                    myLocationButtonEnabled: false,
                                    scrollGesturesEnabled: false,
                                    zoomGesturesEnabled: false,
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: IgnorePointer(
                                      child: ElevatedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(
                                          Icons.directions,
                                          size: 16,
                                        ),
                                        label: const Text('Navigate'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppTheme.primaryRed,
                                          elevation: 2,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Book button
          bottomNavigationBar: widget.hideBookingButton
              ? null
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: PrimaryButton(
                      text: 'Book Now',
                      onPressed: hostel.availableRooms > 0
                          ? () {
                              if (currentUserId == hostel.ownerId) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Action Not Allowed'),
                                    content: const Text(
                                      'You cannot book your own property.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }
                              Navigator.pushNamed(
                                context,
                                AppRoutes.booking,
                                arguments: {
                                  'hostelId': hostel.id,
                                  'hostelName': hostel.name,
                                  'pricePerNight': hostel.rentPrice,
                                  'rentPeriod': hostel.rentPeriod,
                                },
                              );
                            }
                          : () {},
                      icon: Icons.calendar_today,
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildAvailabilityBadge(
    int rooms, {
    bool isFlat = false,
    int? capacity,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isFlat && capacity != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Capacity: $capacity person',
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (() {
              if (rooms <= 0) return AppTheme.grey.withOpacity(0.1);
              if (isFlat) return Colors.green.withOpacity(0.08);
              if (rooms <= 3) return Colors.red.withOpacity(0.08);
              if (rooms <= 5) return Colors.amber.withOpacity(0.08);
              return Colors.green.withOpacity(0.08);
            })(),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isFlat
                ? (rooms > 0 ? 'Available' : 'Not Available')
                : (rooms > 0 ? '$rooms rooms' : 'No rooms'),
            style: TextStyle(
              color: (() {
                if (rooms <= 0) return AppTheme.grey;
                if (isFlat) return Colors.green;
                if (rooms <= 3) return AppTheme.primaryRed;
                if (rooms <= 5) return Colors.orange;
                return Colors.green;
              })(),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeaterRow(
    BuildContext context,
    String label,
    double? price,
    int available,
    String rentPeriod,
  ) {
    if (price == null || price == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₹${price.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppTheme.primaryRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildAvailabilityBadge(available),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            backgroundColor: Colors.grey[200],
            flexibleSpace: FlexibleSpaceBar(
              background: _skeletonBox(height: 300, width: double.infinity),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Container preview type searching bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey[300]),
                        const SizedBox(width: 12),
                        Container(
                          width: 150,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _skeletonBox(height: 32, width: 200),
                          _skeletonBox(height: 24, width: 60),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _skeletonBox(height: 16, width: double.infinity),
                      const SizedBox(height: 8),
                      _skeletonBox(height: 16, width: 250),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _skeletonBox(
                            height: 40,
                            width: 100,
                            borderRadius: 20,
                          ),
                          const SizedBox(width: 12),
                          _skeletonBox(
                            height: 40,
                            width: 100,
                            borderRadius: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _skeletonBox(height: 20, width: 120),
                      const SizedBox(height: 16),
                      _skeletonBox(height: 100, width: double.infinity),
                      const SizedBox(height: 32),
                      _skeletonBox(height: 20, width: 150),
                      const SizedBox(height: 16),
                      _skeletonBox(height: 200, width: double.infinity),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox({
    required double height,
    required double width,
    double borderRadius = 8,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const _ShimmerOverlay(),
    );
  }
}

class _ShimmerOverlay extends StatefulWidget {
  const _ShimmerOverlay();

  @override
  State<_ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<_ShimmerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FractionallySizedBox(
          widthFactor: 1.0,
          heightFactor: 1.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + (_controller.value * 2), -0.3),
                end: Alignment(0.0 + (_controller.value * 2), 0.3),
                colors: [
                  Colors.grey[200]!,
                  Colors.grey[100]!,
                  Colors.grey[200]!,
                ],
                stops: const [0.3, 0.5, 0.7],
              ),
            ),
          ),
        );
      },
    );
  }
}
