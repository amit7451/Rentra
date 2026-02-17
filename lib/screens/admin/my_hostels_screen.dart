import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/loading_indicator.dart';
import 'edit_hostel_screen.dart';

import '../../services/firestore_service_additions.dart';

class MyHostelsScreen extends StatelessWidget {
  const MyHostelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        color: AppTheme.primaryRed,
        onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              title: const Text(
                'My Hostels',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.grey[50],
              foregroundColor: Colors.black,
              pinned: true,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 4,
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
                            color: Colors.red,
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
                              color: AppTheme.primaryRed.withValues(
                                alpha: 0.08,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.home_work_outlined,
                              size: 60,
                              color: AppTheme.primaryRed,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No hostels listed yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first property to get started',
                            style: TextStyle(color: Colors.grey[600]),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                              errorBuilder: (_, _, _) => _placeholder(),
                            )
                          : _placeholder(),
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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${hostel.address}, ${hostel.city}',
                              style: TextStyle(
                                color: Colors.grey[600],
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
                                AppTheme.primaryRed.withValues(alpha: 0.1),
                                AppTheme.primaryRed,
                              );
                            },
                          ),
                          _infoChip(
                            '${hostel.availableRooms} rooms',
                            Icons.bed_outlined,
                            Colors.blue.withValues(alpha: 0.1),
                            Colors.blue[700]!,
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
                                style: const TextStyle(
                                  color: Colors.black,
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
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                a,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
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
                    color: AppTheme.primaryRed,
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
                    color: hostel.isActive ? Colors.orange[700]! : Colors.green,
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

  Widget _placeholder() => Container(
    height: 170,
    width: double.infinity,
    color: Colors.grey[200],
    child: const Icon(Icons.image_outlined, size: 48, color: Colors.grey),
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
          border: Border.all(color: Colors.red[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete_outline, color: Colors.red[600], size: 20),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
