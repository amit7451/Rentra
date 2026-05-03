import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/hostel_model.dart';
import '../../services/wishlist_service.dart';

class PremiumHostelCard extends StatelessWidget {
  final HostelModel hostel;
  final double? distance;
  final double width;
  final double height;
  final bool isWishlisted;
  final String? uid;
  final WishlistService? wishlistService;

  const PremiumHostelCard({
    super.key,
    required this.hostel,
    this.distance,
    this.width = 260,
    this.height = 216,
    this.isWishlisted = false,
    this.uid,
    this.wishlistService,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = width <= 160;

    final cardHeight = height;
    final imageHeight = isCompact ? 112.0 : 126.0;
    final contentPadding = isCompact ? 8.0 : 10.0;

    final nameFontSize = isCompact ? 12.5 : 14.0;
    final bodyFontSize = isCompact ? 10.5 : 12.0;
    final priceFontSize = isCompact ? 13.0 : 15.0;
    final ratingFontSize = isCompact ? 11.0 : 12.5;

    return SizedBox(
      width: width,
      height: cardHeight,
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.hotelDetail,
            arguments: {'hostelId': hostel.id, 'distance': distance},
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF224E58).withValues(alpha: 0.75),
                            const Color(0xFF14363F).withValues(alpha: 0.75),
                          ]
                        : [
                            const Color(0xFF14B8A6).withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.6),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        child: hostel.images.isNotEmpty
                            ? Image.network(
                                hostel.images.first,
                                height: imageHeight,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  height: imageHeight,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.hotel, size: 40),
                                ),
                              )
                            : Container(
                                height: imageHeight,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.hotel, size: 40),
                              ),
                      ),
                      if (distance != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: Colors.black.withValues(alpha: 0.35),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.near_me,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${distance!.toStringAsFixed(1)} km',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isCompact ? 9.5 : 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(contentPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            hostel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: nameFontSize,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F3F3E),
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: isCompact ? 12 : 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  hostel.city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Rs ${hostel.startingPrice.toStringAsFixed(0)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: priceFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.getPriceColor(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: isCompact ? 13 : 15,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    hostel.rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: ratingFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.06 : 0.25),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              if (uid != null && uid!.isNotEmpty && wishlistService != null)
                Positioned(
                  top: isCompact ? 8 : 10,
                  right: isCompact ? 8 : 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: GestureDetector(
                        onTap: () {
                          isWishlisted
                              ? wishlistService!.removeFromWishlist(
                                  uid!,
                                  hostel.id,
                                )
                              : wishlistService!.addToWishlist(uid!, hostel.id);
                        },
                        child: Container(
                          height: isCompact ? 30 : 36, // 👈 single size control
                          width: isCompact ? 30 : 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,

                            /// 🌊 clean frosted glass (no heavy layers)
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.35),

                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 0.6,
                            ),
                          ),

                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isWishlisted
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                key: ValueKey<bool>(isWishlisted),
                                size: isCompact ? 13 : 15,
                                color: isWishlisted
                                    ? const Color(0xFF14B8A6)
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
