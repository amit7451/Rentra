import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/theme.dart';
import '../../models/hostel_model.dart';
import '../../services/wishlist_service.dart';
import '../../widgets/loading_indicator.dart';
import 'hotel_card.dart';

class HostelsSeeAllScreen extends StatelessWidget {
  final String title;
  final String unitType;
  final Stream<List<HostelModel>> hostelsStream;
  final Position? currentPosition;
  final String uid;

  final WishlistService _wishlistService = WishlistService();

  HostelsSeeAllScreen({
    super.key,
    required this.title,
    required this.unitType,
    required this.hostelsStream,
    required this.currentPosition,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final Stream<List<String>> wishlistStream = uid.isEmpty
        ? Stream.value(<String>[])
        : _wishlistService.watchWishlist(uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F2F31), Color(0xFF184A4C)],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<HostelModel>>(
        stream: hostelsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LoadingIndicator(message: 'Loading hostels...');
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load hostels: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.grey),
                ),
              ),
            );
          }

          final hostels = snapshot.data ?? <HostelModel>[];
          final hostelDistances = hostels
              .where((h) => h.unitType.toLowerCase() == unitType.toLowerCase())
              .map((h) {
                double? dist;
                if (currentPosition != null &&
                    h.latitude != null &&
                    h.longitude != null) {
                  dist =
                      Geolocator.distanceBetween(
                        currentPosition!.latitude,
                        currentPosition!.longitude,
                        h.latitude!,
                        h.longitude!,
                      ) /
                      1000;
                }
                return _HostelDistance(hostel: h, distance: dist);
              })
              .toList();

          hostelDistances.sort((a, b) {
            if (a.distance == null && b.distance == null) return 0;
            if (a.distance == null) return 1;
            if (b.distance == null) return -1;
            return a.distance!.compareTo(b.distance!);
          });

          if (hostelDistances.isEmpty) {
            return const Center(
              child: Text(
                'No hostels available right now.',
                style: TextStyle(color: AppTheme.grey),
              ),
            );
          }

          return StreamBuilder<List<String>>(
            stream: wishlistStream,
            builder: (context, wishlistSnap) {
              final wishlistIds = wishlistSnap.data ?? const <String>[];

              return LayoutBuilder(
                builder: (context, constraints) {
                  const pagePadding = 16.0;
                  const spacing = 12.0;
                  const cardHeight = 232.0;

                  final cardWidth =
                      (constraints.maxWidth - (pagePadding * 2) - spacing) / 2;
                  final cardAspectRatio = cardWidth / cardHeight;

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      pagePadding,
                      12,
                      pagePadding,
                      24,
                    ),
                    itemCount: hostelDistances.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: cardAspectRatio,
                    ),
                    itemBuilder: (context, index) {
                      final entry = hostelDistances[index];
                      return PremiumHostelCard(
                        width: cardWidth,
                        height: cardHeight,
                        hostel: entry.hostel,
                        distance: entry.distance,
                        uid: uid,
                        wishlistService: _wishlistService,
                        isWishlisted: wishlistIds.contains(entry.hostel.id),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _HostelDistance {
  final HostelModel hostel;
  final double? distance;

  const _HostelDistance({required this.hostel, this.distance});
}
