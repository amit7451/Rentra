import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../services/wishlist_service.dart';
import '../../models/hostel_model.dart';
import '../../widgets/loading_indicator.dart';
import '../../app/routes.dart';
import '../../widgets/glass_card.dart';

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
              backgroundColor: Colors.transparent,
              centerTitle: true,
              title: const Text(
                'Wishlist',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
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
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      );
    }

    final wishlistService = WishlistService();
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            elevation: 0,
            scrolledUnderElevation: 4,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            backgroundColor: Colors.transparent,
            centerTitle: true,
            title: const Text(
              'Wishlist',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
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
                                color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.favorite,
                                    color: Color(0xFF14B8A6),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${wishlisted.length} saved propert${wishlisted.length == 1 ? 'y' : 'ies'}',
                                    style: const TextStyle(
                                      color: Color(0xFF14B8A6),
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
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
              color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 64,
              color: Color(0xFF14B8A6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your wishlist is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Save hostels and flats you like by tapping the ♡ icon',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 14),
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
              backgroundColor: const Color(0xFF14B8A6),
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

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: 18,
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.hotelDetail, arguments: h.id);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ─────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: _removing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF14B8A6),
                              ),
                            )
                          : const Icon(
                              Icons.favorite,
                              color: Color(0xFF14B8A6),
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
                      color: Colors.black.withValues(alpha: 0.7),
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
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
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
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${h.address}, ${h.city}',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 13),
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
    );
  }

  Widget _placeholder() => Container(
    height: 180,
    width: double.infinity,
    color: Colors.white.withValues(alpha: 0.05),
    child: const Icon(Icons.image_outlined, size: 48, color: Color(0xFF14B8A6)),
  );

  Widget _pill(String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
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
