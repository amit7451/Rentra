import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/glass_card.dart';
import 'edit_hostel_screen.dart';

import '../../services/firestore_service_additions.dart';

class MyHostelsScreen extends StatelessWidget {
  const MyHostelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(      backgroundColor: Colors.transparent,

      body: RefreshIndicator(
        color: AppTheme.primaryTeal,
        onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 4,
              pinned: true,
              centerTitle: true,
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
              title: const Text(
                'My Hostels',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            StreamBuilder<List<HostelModel>>(
              stream: firestoreService.getHostelsByOwner(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: LoadingIndicator(message: 'Loading your hostels...'),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppTheme.primaryTeal,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final hostels = snapshot.data ?? [];

                if (hostels.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.home_work_outlined,
                              size: 60,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No hostels listed yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.titleLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first property to get started',
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.builder(
                    itemCount: hostels.length,
                    itemBuilder: (context, index) {
                      return _HostelCard(
                        hostel: hostels[index],
                        firestoreService: firestoreService,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HostelCard extends StatelessWidget {
  final HostelModel hostel;
  final FirestoreService firestoreService;

  const _HostelCard({required this.hostel, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.hotelDetail,
                arguments: {'hostelId': hostel.id, 'hideBookingButton': true},
              );
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image ──────────────────────────────────────────
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Stack(
                    children: [
                      hostel.images.isNotEmpty
                          ? Image.network(
                              hostel.images.first,
                              height: 170,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _placeholder(context),
                            )
                          : _placeholder(context),
                      // Status badge overlay
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: hostel.isActive
                                ? Colors.green.withValues(alpha: 0.9)
                                : Colors.grey.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hostel.isActive
                                    ? Icons.check_circle
                                    : Icons.pause_circle,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hostel.isActive ? 'Active' : 'Inactive',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Info ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hostel.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${hostel.address}, ${hostel.city}',
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodySmall?.color,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Builder(
                            builder: (context) {
                              double displayPrice = hostel.rentPrice;
                              if (hostel.unitType != 'flat' &&
                                  displayPrice == 0) {
                                final prices =
                                    [
                                          hostel.price1Seater,
                                          hostel.price2Seater,
                                          hostel.price3Seater,
                                        ]
                                        .where((p) => p != null && p > 0)
                                        .map((p) => p!)
                                        .toList();
                                if (prices.isNotEmpty) {
                                  displayPrice = prices.reduce(
                                    (a, b) => a < b ? a : b,
                                  );
                                }
                              }
                              return _infoChip(
                                '₹${displayPrice.toStringAsFixed(0)}/${hostel.rentPeriod == 'monthly' ? 'mo' : 'yr'}',
                                Icons.payments_outlined,
                                AppTheme.getPriceColor(context).withValues(alpha: 0.1),
                                AppTheme.getPriceColor(context),
                              );
                            },
                          ),
                          _infoChip(
                            '${hostel.availableRooms} rooms',
                            Icons.bed_outlined,
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.blue.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.1),
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.blue[300]!
                                : Colors.blue[700]!,
                          ),
                          // Rating box fixed as per hotel_card.dart
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFFB400),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hostel.rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Amenities preview ───────────────────────
                      if (hostel.amenities.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: hostel.amenities.take(4).map((a) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                  a,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Action Buttons ──────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _actionButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    color: AppTheme.getPriceColor(context),
                    outlined: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditHostelScreen(hostel: hostel),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    label: hostel.isActive ? 'Deactivate' : 'Activate',
                    icon: hostel.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    color: hostel.isActive
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange[300]!
                            : Colors.orange[700]!)
                        : Colors.green,
                    outlined: true,
                    onTap: () async {
                      await firestoreService.toggleHostelActive(
                        hostel.id,
                        !hostel.isActive,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _deleteButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    height: 170,
    width: double.infinity,
    color: Colors.white.withValues(alpha: 0.05),
    child: Icon(Icons.image_outlined, size: 48, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5) ?? AppTheme.grey),
  );

  Widget _infoChip(String label, IconData icon, Color bgColor, Color fgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool outlined,
    required VoidCallback onTap,
  }) {
    return outlined
        ? OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          )
        : ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          );
  }

  Widget _deleteButton(BuildContext context) {
    return InkWell(
      onTap: () => _confirmDelete(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.getPriceColor(context).withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete_outline, color: AppTheme.getPriceColor(context), size: 20),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Hostel'),
        content: Text(
          'Delete "${hostel.name}"? All associated data will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await firestoreService.deleteHostel(hostel.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hostel deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppTheme.primaryTeal,
          ),
        );
      }
    }
  }
}
