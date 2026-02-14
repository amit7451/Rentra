import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_text.dart';
import '../../widgets/primary_button.dart';

class HotelDetailScreen extends StatelessWidget {
  final String hostelId;

  const HotelDetailScreen({super.key, required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return StreamBuilder<HostelModel?>(
      stream: firestoreService.watchHostel(hostelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LoadingIndicator(message: 'Loading hostel details...'),
          );
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
                            color: AppTheme.primaryRed.withValues(alpha: 0.1),
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
                                color: Colors.black.withValues(alpha: 0.05),
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

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Book button
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
                color: Colors.blue.withValues(alpha: 0.08),
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
              if (rooms <= 0) return AppTheme.grey.withValues(alpha: 0.1);
              if (isFlat) return Colors.green.withValues(alpha: 0.08);
              if (rooms <= 3) return Colors.red.withValues(alpha: 0.08);
              if (rooms <= 5) return Colors.amber.withValues(alpha: 0.08);
              return Colors.green.withValues(alpha: 0.08);
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
}
