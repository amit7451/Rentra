import 'package:flutter/material.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';

class HotelCard extends StatelessWidget {
  final HostelModel hostel;

  const HotelCard({super.key, required this.hostel});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.hotelDetail,
            arguments: hostel.id,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: hostel.images.isNotEmpty
                  ? Image.network(
                      hostel.images.first,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: AppTheme.lightGrey,
                          child: const Icon(
                            Icons.hotel,
                            size: 64,
                            color: AppTheme.grey,
                          ),
                        );
                      },
                    )
                  : Container(
                      height: 200,
                      color: AppTheme.lightGrey,
                      child: const Icon(
                        Icons.hotel,
                        size: 64,
                        color: AppTheme.grey,
                      ),
                    ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                hostel.name,
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Unit type chip (Flat vs Hostel/PG)
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
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFFFFB400), // yellow star
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hostel.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.black, // black rating text
                              fontWeight: FontWeight.bold,
                              fontSize:
                                  14, // same default size (keep/remove if already defined)
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppTheme.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${hostel.city}, ${hostel.country}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Price and availability
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hostel.unitType != 'flat')
                                    Text(
                                      'Starting from',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppTheme.grey,
                                            fontSize: 10,
                                          ),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${hostel.startingPrice.toStringAsFixed(0)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: AppTheme.primaryRed,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    hostel.rentPeriod == 'monthly'
                                        ? 'Monthly'
                                        : 'Yearly',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (() {
                            if (hostel.unitType.toLowerCase() == 'flat') {
                              return Colors.green.withValues(alpha: 0.08);
                            }
                            final rooms = hostel.availableRooms;
                            if (rooms <= 0) {
                              return AppTheme.grey.withValues(alpha: 0.1);
                            }
                            if (rooms <= 3) {
                              return Colors.red.withValues(alpha: 0.08);
                            }
                            if (rooms <= 5) {
                              return Colors.amber.withValues(alpha: 0.08);
                            }
                            return Colors.green.withValues(alpha: 0.08);
                          })(),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hostel.unitType.toLowerCase() == 'flat'
                              ? 'Capacity: ${hostel.flatCapacity ?? 0} person'
                              : (hostel.availableRooms > 0
                                    ? '${hostel.availableRooms} rooms available'
                                    : 'No rooms available'),
                          style: TextStyle(
                            color: (() {
                              if (hostel.unitType.toLowerCase() == 'flat') {
                                return Colors.green;
                              }
                              final rooms = hostel.availableRooms;
                              if (rooms <= 0) return AppTheme.grey;
                              if (rooms <= 3) return AppTheme.primaryRed;
                              if (rooms <= 5) return Colors.orange;
                              return Colors.green;
                            })(),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
}
