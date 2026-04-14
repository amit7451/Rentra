import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../services/wishlist_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../app/routes.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              elevation: 0,
              pinned: true,
              scrolledUnderElevation: 4,
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.grey[50],
              centerTitle: true,
              title: const Text(
                'Wishlist',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(color: Colors.grey[50]),
              ),
            ),
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.login_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sign in to view your wishlist',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final wishlistService = WishlistService();
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            elevation: 0,
            scrolledUnderElevation: 4,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            backgroundColor: Colors.grey[50],
            centerTitle: true,
            title: const Text(
              'Wishlist',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: Colors.grey[50]),
            ),
          ),
          StreamBuilder<List<String>>(
            stream: wishlistService.watchWishlist(uid),
            builder: (context, idSnap) {
              if (idSnap.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: LoadingIndicator(message: 'Loading wishlist...'),
                );
              }

              final hostelIds = idSnap.data ?? [];

              if (hostelIds.isEmpty) {
                return SliverFillRemaining(child: _EmptyWishlist());
              }

              return StreamBuilder<List<HostelModel>>(
                stream: firestoreService.getHostels(),
                builder: (context, hostelSnap) {
                  if (hostelSnap.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: LoadingIndicator(message: 'Loading hostels...'),
                    );
                  }

                  final all = hostelSnap.data ?? [];
                  final wishlisted = all
                      .where((h) => hostelIds.contains(h.id))
                      .toList();

                  if (wishlisted.isEmpty) {
                    return SliverFillRemaining(child: _EmptyWishlist());
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == 0) {
                        return Column(
                          children: [
                            // ── Count header ────────────────────────────────
                            Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.favorite,
                                    color: AppTheme.primaryTeal,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${wishlisted.length} saved propert${wishlisted.length == 1 ? 'y' : 'ies'}',
                                    style: const TextStyle(
                                      color: AppTheme.primaryTeal,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _WishlistCard(
                          hostel: wishlisted[index - 1],
                          uid: uid,
                          wishlistService: wishlistService,
                        ),
                      );
                    }, childCount: wishlisted.length + 1),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Empty Wishlist ─────────────────────────────────────────────────────────

class _EmptyWishlist extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 64,
              color: AppTheme.primaryTeal,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your wishlist is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Save hostels and flats you like by tapping the ♡ icon',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.search, color: Colors.white),
            label: const Text(
              'Explore Hostels',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wishlist Card ─────────────────────────────────────────────────────────

class _WishlistCard extends StatefulWidget {
  final HostelModel hostel;
  final String uid;
  final WishlistService wishlistService;

  const _WishlistCard({
    required this.hostel,
    required this.uid,
    required this.wishlistService,
  });

  @override
  State<_WishlistCard> createState() => _WishlistCardState();
}

class _WishlistCardState extends State<_WishlistCard> {
  bool _removing = false;

  Future<void> _remove() async {
    setState(() => _removing = true);
    try {
      await widget.wishlistService.removeFromWishlist(
        widget.uid,
        widget.hostel.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from wishlist'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hostel;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.hotelDetail, arguments: h.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ─────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Stack(
                children: [
                  h.images.isNotEmpty
                      ? Image.network(
                          h.images.first,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(),
                        )
                      : _placeholder(),

                  // Wishlist remove button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _removing ? null : _remove,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        child: _removing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryTeal,
                                ),
                              )
                            : const Icon(
                                Icons.favorite,
                                color: AppTheme.primaryTeal,
                                size: 20,
                              ),
                      ),
                    ),
                  ),

                  // Price badge
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '₹${h.startingPrice.toStringAsFixed(0)}/${h.rentPeriod == 'monthly' ? 'mo' : 'yr'}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Info ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          h.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 15, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            h.rating.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            ' (${h.totalReviews})',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${h.address}, ${h.city}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _pill(
                        '${h.availableRooms} rooms',
                        Icons.bed_outlined,
                        Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      if (h.amenities.isNotEmpty)
                        _pill(h.amenities.first, Icons.wifi, Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 180,
    width: double.infinity,
    color: Colors.grey[200],
    child: const Icon(Icons.image_outlined, size: 48, color: Colors.grey),
  );

  Widget _pill(String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
