import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/hostel_model.dart';
import '../../models/booking_model.dart';
import '../../app/theme.dart';
import 'my_hostels_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_stats_screen.dart';
import '../../app/routes.dart';
import '../../widgets/verification_dialog.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: RefreshIndicator(
        color: AppTheme.primaryTeal,
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
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
                'Admin Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.black),
                  tooltip: 'Sign Out',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Sign Out'),
                        content: const Text(
                          'Are you sure you want to sign out?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryTeal,
                            ),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Welcome Header ──────────────────────────────────
                    _WelcomeHeader(uid: uid),
                    const SizedBox(height: 20),

                    // ── Top 4 Containers (Revenue, Pending, Add, My Hostels) ──
                    StreamBuilder<List<HostelModel>>(
                      stream: firestoreService.getHostelsByOwner(uid),
                      builder: (context, hostelSnap) {
                        return StreamBuilder<List<BookingModel>>(
                          stream: firestoreService.getBookingsForOwner(uid),
                          builder: (context, bookingSnap) {
                            final bookings = bookingSnap.data ?? [];
                            final confirmed = bookings
                                .where(
                                  (b) => b.status == BookingStatus.confirmed,
                                )
                                .toList();
                            final pending = bookings
                                .where((b) => b.status == BookingStatus.pending)
                                .toList();
                            final revenue = confirmed.fold<double>(
                              0,
                              (sum, b) => sum + b.totalPrice,
                            );

                            return Column(
                              children: [
                                // Row 1: Total Revenue & Pending Bookings
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricCard(
                                        label: 'Total Revenue',
                                        value:
                                            '₹${_formatNumber(revenue.toInt())}',
                                        icon: Icons.trending_up,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF43A047),
                                            Color(0xFF66BB6A),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        trendLabel: '+12%',
                                        trendUp: true,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminStatsScreen(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _MetricCard(
                                        label: 'Pending Bookings',
                                        value: '${pending.length}',
                                        icon: Icons.hourglass_bottom_outlined,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFF4511E),
                                            Color(0xFFFF7043),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        trendLabel: '',
                                        trendUp: null,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminBookingsScreen(
                                                  initialIndex: 0,
                                                ),
                                          ),
                                        ), // Pending tab
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                // Row 2: Add Hostel & My Hostels
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricCard(
                                        label: 'Add Hostel',
                                        value: 'New',
                                        icon: Icons.add_home_work_rounded,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFD32F2F),
                                            Color(0xFFEF5350),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        trendLabel: '',
                                        trendUp: null,
                                        onTap: () async {
                                          final currentUser =
                                              FirebaseAuth.instance.currentUser;
                                          await currentUser?.reload();
                                          if (currentUser != null &&
                                              !currentUser.emailVerified) {
                                            if (context.mounted) {
                                              showVerificationDialog(context);
                                            }
                                            return;
                                          }

                                          if (context.mounted) {
                                            Navigator.pushNamed(
                                              context,
                                              AppRoutes.addHostel,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _MetricCard(
                                        label: 'My Hostels',
                                        value:
                                            '${hostelSnap.data?.length ?? 0}',
                                        icon: Icons.apartment_rounded,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF1976D2),
                                            Color(0xFF42A5F5),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        trendLabel: '',
                                        trendUp: null,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const MyHostelsScreen(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // ── Manage Section Title ────────────────────────────
                    const Text(
                      'Manage',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Bottom Grid (5 Items) ───────────────────────────
                    _FeatureGrid(uid: uid, firestoreService: firestoreService),

                    const SizedBox(height: 24),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ── Welcome Header ──────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  final String uid;
  const _WelcomeHeader({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 60); // Placeholder height
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final name = data?['name'] ?? 'Admin';
        final photoUrl = data?['photoUrl'];

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WELCOME BACK',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.primaryTeal,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }
}

// ── Metric Card ────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final String trendLabel;
  final bool? trendUp;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.trendLabel,
    required this.trendUp,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                if (trendLabel.isNotEmpty && trendUp != null)
                  Row(
                    children: [
                      Icon(
                        trendUp!
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: trendUp! ? Colors.green : AppTheme.primaryTeal,
                      ),
                      Text(
                        trendLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: trendUp! ? Colors.green : AppTheme.primaryTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20, // Reduced font size slightly to prevent overflow
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature Grid ───────────────────────────────────────────────────────────

class _FeatureGrid extends StatelessWidget {
  final String uid;
  final FirestoreService firestoreService;

  const _FeatureGrid({required this.uid, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    final features = [
      _Feature(
        icon: Icons.receipt_long_rounded,
        label: 'Bookings',
        subtitle: 'All reservations',
        bgColor: const Color(0xFFE8F5E9),
        iconColor: const Color(0xFF2E7D32),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminBookingsScreen()),
        ),
      ),
      _Feature(
        icon: Icons.bar_chart_rounded,
        label: 'Analytics',
        subtitle: 'Detailed stats',
        bgColor: const Color(0xFFFFF3E0),
        iconColor: const Color(0xFFE65100),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminStatsScreen()),
        ),
      ),
      _Feature(
        icon: Icons.check_circle_outline_rounded,
        label: 'Confirmed',
        subtitle: 'Active bookings',
        bgColor: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1565C0),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AdminBookingsScreen(initialIndex: 1), // Confirmed
          ),
        ),
      ),
      _Feature(
        icon: Icons.support_agent_rounded,
        label: 'Help & Support',
        subtitle: 'Contact support',
        bgColor: const Color(0xFFE0F2F1),
        iconColor: const Color(0xFF00695C),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Help & Support'),
              content: const Text(
                'For assistance, please contact the support team at:\n\namitkumarstm1507@gmail.com\n\nOr call us at +91 7323006476.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
      _Feature(
        icon: Icons.star_rate_rounded,
        label: 'Reviews',
        subtitle: 'Guest feedback',
        bgColor: const Color(0xFFF3E5F5),
        iconColor: const Color(0xFF6A1B9A),
        onTap: () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reviews coming soon!'))),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemCount: features.length,
      itemBuilder: (context, i) => _FeatureCard(feature: features[i]),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: feature.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: feature.bgColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(feature.icon, color: feature.iconColor, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              feature.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              feature.subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _Feature({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });
}
