import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/booking_model.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';

class AdminStatsScreen extends StatelessWidget {
  const AdminStatsScreen({super.key});

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
                'Analytics',
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
              builder: (context, hostelSnap) {
                if (hostelSnap.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: LoadingIndicator(message: 'Loading...'),
                  );
                }

                final hostels = hostelSnap.data ?? [];

                if (hostels.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bar_chart_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Add hostels to see analytics',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return StreamBuilder<List<BookingModel>>(
                  stream: firestoreService.getBookingsForOwner(uid),
                  builder: (context, bookingSnap) {
                    if (bookingSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: LoadingIndicator(message: 'Computing stats...'),
                      );
                    }

                    final bookings = bookingSnap.data ?? [];
                    return SliverToBoxAdapter(
                      child: _StatsBody(hostels: hostels, bookings: bookings),
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
}

class _StatsBody extends StatelessWidget {
  final List<HostelModel> hostels;
  final List<BookingModel> bookings;

  const _StatsBody({required this.hostels, required this.bookings});

  @override
  Widget build(BuildContext context) {
    final confirmed = bookings
        .where((b) => b.status == BookingStatus.confirmed)
        .toList();
    final pending = bookings
        .where((b) => b.status == BookingStatus.pending)
        .toList();
    final cancelled = bookings
        .where((b) => b.status == BookingStatus.cancelled)
        .toList();
    final revenue = confirmed.fold<double>(0, (s, b) => s + b.totalPrice);
    final guests = confirmed.fold<int>(0, (s, b) => s + b.numberOfGuests);
    final occupancyRate = hostels.isEmpty
        ? 0.0
        : (confirmed.length / (hostels.length * 10)).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Period selector ───────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'All Time',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Header ────────────────────────────────────────
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats grid ────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.2,
            children: [
              _StatCard(
                title: 'Revenue',
                value: _fmt(revenue.toInt()),
                prefix: '₹',
                icon: Icons.trending_up,
                bgColor: const Color(0xFFE8F5E9),
                iconColor: Colors.green[700]!,
                trendLabel: '+12%',
                trendUp: true,
              ),
              _StatCard(
                title: 'Total Bookings',
                value: '${bookings.length}',
                prefix: '',
                icon: Icons.receipt_long_outlined,
                bgColor: const Color(0xFFE3F2FD),
                iconColor: Colors.blue[700]!,
                trendLabel: '${confirmed.length} confirmed',
                trendUp: null,
              ),
              _StatCard(
                title: 'Pending',
                value: '${pending.length}',
                prefix: '',
                icon: Icons.hourglass_empty,
                bgColor: const Color(0xFFFFF3E0),
                iconColor: Colors.orange[700]!,
                trendLabel: 'Needs action',
                trendUp: null,
              ),
              _StatCard(
                title: 'Total Guests',
                value: '$guests',
                prefix: '',
                icon: Icons.people_alt_outlined,
                bgColor: const Color(0xFFF3E5F5),
                iconColor: Colors.purple[700]!,
                trendLabel: '+8%',
                trendUp: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Occupancy bar ─────────────────────────────────
          const Text(
            'Occupancy Rate',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
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
                    Text(
                      '${(occupancyRate * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${confirmed.length} / ${hostels.length * 10}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: occupancyRate,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      occupancyRate > 0.7
                          ? Colors.green
                          : occupancyRate > 0.4
                          ? Colors.orange
                          : AppTheme.primaryRed,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on confirmed bookings vs estimated capacity',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Booking breakdown ─────────────────────────────
          const Text(
            'Booking Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _BookingBreakdown(
            confirmed: confirmed.length,
            pending: pending.length,
            cancelled: cancelled.length,
          ),
          const SizedBox(height: 24),

          // ── Per-hostel performance ────────────────────────
          const Text(
            'Hostel Performance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...hostels.map((h) {
            final hBookings = bookings
                .where((b) => b.hostelId == h.id)
                .toList();
            final hRevenue = hBookings
                .where((b) => b.status == BookingStatus.confirmed)
                .fold<double>(0, (s, b) => s + b.totalPrice);
            return _HostelPerfCard(
              hostel: h,
              bookingCount: hBookings.length,
              revenue: hRevenue,
            );
          }),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title, value, prefix;
  final IconData icon;
  final Color bgColor, iconColor;
  final String trendLabel;
  final bool? trendUp;

  const _StatCard({
    required this.title,
    required this.value,
    required this.prefix,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.trendLabel,
    required this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              if (trendUp != null)
                Icon(
                  trendUp!
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                  color: trendUp! ? Colors.green : Colors.red,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$prefix$value',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (trendLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              trendLabel,
              style: TextStyle(
                fontSize: 11,
                color: trendUp == true ? Colors.green : Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Booking Breakdown ──────────────────────────────────────────────────────

class _BookingBreakdown extends StatelessWidget {
  final int confirmed, pending, cancelled;
  const _BookingBreakdown({
    required this.confirmed,
    required this.pending,
    required this.cancelled,
  });

  @override
  Widget build(BuildContext context) {
    final total = confirmed + pending + cancelled;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(child: Text('No bookings yet')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _bar('Confirmed', confirmed, total, Colors.green),
          const SizedBox(height: 12),
          _bar('Pending', pending, total, Colors.orange),
          const SizedBox(height: 12),
          _bar('Cancelled', cancelled, total, Colors.red),
        ],
      ),
    );
  }

  Widget _bar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ── Hostel Performance Card ────────────────────────────────────────────────

class _HostelPerfCard extends StatelessWidget {
  final HostelModel hostel;
  final int bookingCount;
  final double revenue;

  const _HostelPerfCard({
    required this.hostel,
    required this.bookingCount,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: hostel.images.isNotEmpty
                ? Image.network(
                    hostel.images.first,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hostel.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${hostel.city} · ${hostel.availableRooms} rooms left',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${_fmt(revenue.toInt())}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.green,
                  fontSize: 15,
                ),
              ),
              Text(
                '$bookingCount bookings',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 56,
    height: 56,
    color: Colors.grey[200],
    child: const Icon(Icons.home, color: Colors.grey),
  );

  String _fmt(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
