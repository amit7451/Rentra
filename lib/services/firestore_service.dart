import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/hostel_model.dart';
import '../models/booking_model.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  final String _usersCollection = 'users';
  final String _hostelsCollection = 'hostels';
  final String _bookingsCollection = 'bookings';

  // ==================== USER OPERATIONS ====================

  // Create user
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set(user.toMap());
    } catch (e) {
      throw 'Failed to create user: $e';
    }
  }

  // Get user
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw 'Failed to get user: $e';
    }
  }

  // Update user
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update(data);
    } catch (e) {
      throw 'Failed to update user: $e';
    }
  }

  // Soft delete user
  Future<void> softDeleteUser(String uid) async {
    try {
      final batch = _firestore.batch();

      // 1. Update user document
      final userRef = _firestore.collection(_usersCollection).doc(uid);
      batch.update(userRef, {
        'accountStatus': 'deleted',
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      // 2. Deactivate all hostels owned by this user
      final hostelsQuery = await _firestore
          .collection(_hostelsCollection)
          .where('ownerId', isEqualTo: uid)
          .get();

      for (var doc in hostelsQuery.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      await batch.commit();
    } catch (e) {
      throw 'Failed to soft delete user: $e';
    }
  }

  // Reactivate user
  Future<void> reactivateUser(String uid) async {
    try {
      final batch = _firestore.batch();

      // 1. Update user document
      final userRef = _firestore.collection(_usersCollection).doc(uid);
      batch.update(userRef, {
        'accountStatus': 'active',
        'isActive': true,
        'deletedAt': null,
      });

      // 2. Reactivate all hostels owned by this user
      final hostelsQuery = await _firestore
          .collection(_hostelsCollection)
          .where('ownerId', isEqualTo: uid)
          .get();

      for (var doc in hostelsQuery.docs) {
        batch.update(doc.reference, {'isActive': true});
      }

      await batch.commit();
    } catch (e) {
      throw 'Failed to reactivate user: $e';
    }
  }

  // Delete user (Standard delete)
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).delete();
    } catch (e) {
      throw 'Failed to delete user: $e';
    }
  }

  // Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw 'Failed to get user by email: $e';
    }
  }

  // Hard delete user data (Removes everything permanently)
  Future<void> hardDeleteUserData(String uid) async {
    try {
      final batch = _firestore.batch();

      // 1. Delete user doc
      batch.delete(_firestore.collection(_usersCollection).doc(uid));

      // 2. Delete hostels owned by user
      final hostelsQuery = await _firestore
          .collection(_hostelsCollection)
          .where('ownerId', isEqualTo: uid)
          .get();
      for (var doc in hostelsQuery.docs) {
        batch.delete(doc.reference);
      }

      // 3. Delete bookings related to user (as tenant or host)
      // As Tenant
      final tenantBookings = await _firestore
          .collection(_bookingsCollection)
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in tenantBookings.docs) {
        batch.delete(doc.reference);
      }

      // As Host
      final hostBookings = await _firestore
          .collection(_bookingsCollection)
          .where('adminId', isEqualTo: uid)
          .get();
      for (var doc in hostBookings.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw 'Failed to hard delete user data: $e';
    }
  }

  // Migrate user data to new UID (for account recovery)
  Future<void> migrateUser(String oldUid, String newUid) async {
    try {
      final batch = _firestore.batch();

      // 1. Get old user data
      final oldUserDoc = await _firestore
          .collection(_usersCollection)
          .doc(oldUid)
          .get();
      if (!oldUserDoc.exists) return; // Should not happen if checked before

      final userData = oldUserDoc.data()!;
      // Update UID in data
      userData['uid'] = newUid;
      userData['accountStatus'] = 'active'; // Reactivate
      userData['isActive'] = true;
      userData['deletedAt'] = null;

      // 2. Set new user doc
      final newUserRef = _firestore.collection(_usersCollection).doc(newUid);
      batch.set(newUserRef, userData);

      // 3. Migrate Hostels
      final hostelsQuery = await _firestore
          .collection(_hostelsCollection)
          .where('ownerId', isEqualTo: oldUid)
          .get();
      for (var doc in hostelsQuery.docs) {
        batch.update(doc.reference, {
          'ownerId': newUid,
          'isActive': true,
        }); // Also reactivate hostels
      }

      // 4. Migrate Bookings (as Tenant)
      final tenantBookings = await _firestore
          .collection(_bookingsCollection)
          .where('userId', isEqualTo: oldUid)
          .get();
      for (var doc in tenantBookings.docs) {
        batch.update(doc.reference, {'userId': newUid});
      }

      // 5. Migrate Bookings (as Host)
      final hostBookings = await _firestore
          .collection(_bookingsCollection)
          .where('adminId', isEqualTo: oldUid)
          .get();
      for (var doc in hostBookings.docs) {
        batch.update(doc.reference, {'adminId': newUid});
      }

      // 6. Delete old user doc
      batch.delete(_firestore.collection(_usersCollection).doc(oldUid));

      await batch.commit();
    } catch (e) {
      throw 'Failed to migrate user data: $e';
    }
  }

  // ==================== HOSTEL OPERATIONS ====================

  // Add new hostel (for admin)
  Future<String> addHostel(HostelModel hostel) async {
    try {
      final docRef = _firestore.collection(_hostelsCollection).doc();

      final data = hostel.toMap();
      final id = docRef.id;
      data['id'] = id;
      data['createdAt'] = FieldValue.serverTimestamp();

      await docRef.set(data);
      return id;
    } catch (e) {
      throw 'Failed to add hostel: $e';
    }
  }

  // Get all hostels
  Stream<List<HostelModel>> getHostels({String? unitType}) {
    var query = _firestore
        .collection(_hostelsCollection)
        .where('isActive', isEqualTo: true);

    if (unitType != null) {
      query = query.where('unitType', isEqualTo: unitType);
    }

    return query.snapshots().map((snapshot) {
      final hostels = snapshot.docs
          .map((doc) => HostelModel.fromMap(doc.data()))
          .where((h) => h.availableRooms > 0)
          .toList();

      // Sort by rating client-side to avoid complex index requirements
      hostels.sort((a, b) => b.rating.compareTo(a.rating));

      // Limit to 30 client-side
      return hostels.take(30).toList();
    });
  }

  // In getHostel method:
  Future<HostelModel?> getHostel(String hostelId) async {
    try {
      final doc = await _firestore
          .collection(_hostelsCollection)
          .doc(hostelId)
          .get();
      if (doc.exists) {
        return HostelModel.fromMap(doc.data()!); // This calls fromMap
      }
      return null;
    } catch (e) {
      throw 'Failed to get hostel: $e';
    }
  }

  // Stream a single hostel
  Stream<HostelModel?> watchHostel(String hostelId) {
    return _firestore
        .collection(_hostelsCollection)
        .doc(hostelId)
        .snapshots()
        .map((doc) => doc.exists ? HostelModel.fromMap(doc.data()!) : null);
  }

  // Search hostels
  Stream<List<HostelModel>> searchHostels(String query) {
    return _firestore
        .collection(_hostelsCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final hostels = snapshot.docs
              .map((doc) => HostelModel.fromMap(doc.data()))
              .toList();

          // Filter by availability and query (search in name, city, country)
          final filtered = hostels.where((hostel) {
            if (hostel.availableRooms <= 0) return false;
            final searchQuery = query.toLowerCase();
            return hostel.name.toLowerCase().contains(searchQuery) ||
                hostel.city.toLowerCase().contains(searchQuery) ||
                hostel.country.toLowerCase().contains(searchQuery);
          }).toList();

          // Sort by rating client-side
          filtered.sort((a, b) => b.rating.compareTo(a.rating));
          return filtered;
        });
  }

  // Advanced search/filter/sort
  Stream<List<HostelModel>> getEnhancedHostels({
    String? query,
    String? unitType,
    String? sortBy, // 'price_asc', 'price_desc', 'rating_desc', 'distance'
    double? lat,
    double? lng,
    double? radiusInKm,
  }) {
    return _firestore
        .collection(_hostelsCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final hostels = snapshot.docs
              .map((doc) => HostelModel.fromMap(doc.data()))
              .where((h) => h.availableRooms > 0)
              .toList();

          List<HostelModel> filtered = hostels;

          // 1. Filter by unitType
          if (unitType != null && unitType != 'all') {
            filtered = filtered
                .where(
                  (h) => h.unitType.toLowerCase() == unitType.toLowerCase(),
                )
                .toList();
          }

          // 2. Filter by search query (Multi-word support)
          if (query != null && query.isNotEmpty) {
            final searchWords = query
                .toLowerCase()
                .split(' ')
                .where((w) => w.isNotEmpty)
                .toList();
            filtered = filtered.where((h) {
              final content = "${h.name} ${h.city} ${h.country}".toLowerCase();
              // Check if ALL search words are present in the property content
              return searchWords.every((word) => content.contains(word));
            }).toList();
          }

          // 3. Helper for starting price (Logic from HotelCard)
          double getStartingPrice(HostelModel h) {
            if (h.unitType.toLowerCase() == 'flat') return h.rentPrice;
            final prices = [
              h.price1Seater,
              h.price2Seater,
              h.price3Seater,
            ].where((p) => p != null && p > 0).map((p) => p!).toList();
            return prices.isEmpty
                ? h.rentPrice
                : prices.reduce((a, b) => a < b ? a : b);
          }

          // 4. Filter by Location (Radius)
          if (lat != null && lng != null && radiusInKm != null) {
            filtered = filtered.where((h) {
              if (h.latitude == null || h.longitude == null) return false;
              final dist =
                  Geolocator.distanceBetween(
                    lat,
                    lng,
                    h.latitude!,
                    h.longitude!,
                  ) /
                  1000; // convert to km
              return dist <= radiusInKm;
            }).toList();
          }

          // 5. Sort
          if (sortBy == 'distance' && lat != null && lng != null) {
            filtered.sort((a, b) {
              if (a.latitude == null || a.longitude == null) return 1;
              if (b.latitude == null || b.longitude == null) return -1;
              final distA = Geolocator.distanceBetween(
                lat,
                lng,
                a.latitude!,
                a.longitude!,
              );
              final distB = Geolocator.distanceBetween(
                lat,
                lng,
                b.latitude!,
                b.longitude!,
              );
              return distA.compareTo(distB);
            });
          } else if (sortBy == 'price_asc') {
            filtered.sort(
              (a, b) => getStartingPrice(a).compareTo(getStartingPrice(b)),
            );
          } else if (sortBy == 'price_desc') {
            filtered.sort(
              (a, b) => getStartingPrice(b).compareTo(getStartingPrice(a)),
            );
          } else if (sortBy == 'rating_desc') {
            filtered.sort((a, b) => b.rating.compareTo(a.rating));
          } else {
            // Default sort by rating
            filtered.sort((a, b) => b.rating.compareTo(a.rating));
          }

          return filtered;
        });
  }

  // Filter hostels by price range (Moved to client-side to prevent indexing errors)
  Stream<List<HostelModel>> filterHostelsByPrice({
    required double minPrice,
    required double maxPrice,
  }) {
    return _firestore
        .collection(_hostelsCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final hostels = snapshot.docs
              .map((doc) => HostelModel.fromMap(doc.data()))
              .where(
                (h) =>
                    h.availableRooms > 0 &&
                    h.rentPrice >= minPrice &&
                    h.rentPrice <= maxPrice,
              )
              .toList();
          hostels.sort((a, b) => b.rating.compareTo(a.rating));
          return hostels;
        });
  }

  // Get hostels by owner
  Stream<List<HostelModel>> getHostelsByOwner(String ownerId) {
    return _firestore
        .collection(_hostelsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HostelModel.fromMap(doc.data()))
              .toList(),
        );
  }

  // Update hostel
  Future<void> updateHostel(HostelModel hostel) async {
    try {
      await _firestore
          .collection(_hostelsCollection)
          .doc(hostel.id)
          .update(hostel.toMap());
    } catch (e) {
      throw 'Failed to update hostel: $e';
    }
  }

  // ==================== BOOKING OPERATIONS ====================

  // Create booking
  Future<String> createBooking(BookingModel booking) async {
    try {
      final docRef = await _firestore
          .collection(_bookingsCollection)
          .add(booking.toMap());
      return docRef.id;
    } catch (e) {
      throw 'Failed to create booking: $e';
    }
  }

  // Get user bookings
  Stream<List<BookingModel>> getUserBookings(String userId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs
              .map((doc) => BookingModel.fromMap({...doc.data(), 'id': doc.id}))
              .toList();
          // Sort by bookingDate descending in dart instead of relying on index
          bookings.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
          return bookings;
        });
  }

  // Get booking by ID
  Future<BookingModel?> getBooking(String bookingId) async {
    try {
      final doc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();
      if (doc.exists) {
        return BookingModel.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      throw 'Failed to get booking: $e';
    }
  }

  // Update booking status
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    try {
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': status.name,
      });
    } catch (e) {
      throw 'Failed to update booking status: $e';
    }
  }

  // Cancel booking
  Future<void> cancelBooking(
    String bookingId,
    String? reason,
    String cancelledBy,
  ) async {
    try {
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': BookingStatus.cancelled.name,
        'cancellationReason': reason,
        'cancelledBy': cancelledBy,
      });
    } catch (e) {
      throw 'Failed to cancel booking: $e';
    }
  }

  // Delete booking
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _firestore.collection(_bookingsCollection).doc(bookingId).delete();
    } catch (e) {
      throw 'Failed to delete booking: $e';
    }
  }

  // Get bookings for owner (by admin ID - SECURE and EFFICIENT)
  Stream<List<BookingModel>> getBookingsForOwner(String adminId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('adminId', isEqualTo: adminId)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs
              .map((doc) => BookingModel.fromMap({...doc.data(), 'id': doc.id}))
              .toList();
          // Sort by bookingDate descending in dart instead of relying on index
          bookings.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
          return bookings;
        });
  }

  // Get all active hostels (for fallback queries)
  Stream<List<HostelModel>> getAllActiveHostels() {
    return _firestore
        .collection(_hostelsCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HostelModel.fromMap(doc.data()))
              .toList(),
        );
  }

  // Update room availability (overall and seater-specific)
  Future<void> updateSeaterAvailability({
    required String hostelId,
    required int overallCount,
    required int seaterType, // 1, 2, or 3
    required int seaterCount,
  }) async {
    try {
      final Map<String, dynamic> updates = {'availableRooms': overallCount};

      if (seaterType == 1) updates['rooms1Seater'] = seaterCount;
      if (seaterType == 2) updates['rooms2Seater'] = seaterCount;
      if (seaterType == 3) updates['rooms3Seater'] = seaterCount;

      await _firestore
          .collection(_hostelsCollection)
          .doc(hostelId)
          .update(updates);
    } catch (e) {
      throw 'Failed to update availability: $e';
    }
  }

  // For compatibility with firestore_service_additions or other callers
  Future<void> updateAvailableRooms(String hostelId, int rooms) async {
    await _firestore.collection(_hostelsCollection).doc(hostelId).update({
      'availableRooms': rooms,
    });
  }

  // Get Hostels Sorted by Distance
  Stream<List<HostelModel>> getHostelsNearLocation({
    required double? lat,
    required double? lng,
    double radiusInKm = 5000, // Large default to show all sorted
  }) {
    return _firestore
        .collection(_hostelsCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final hostels = snapshot.docs
              .map((doc) => HostelModel.fromMap(doc.data()))
              .where((h) => h.availableRooms > 0)
              .toList();

          if (lat == null || lng == null) {
            return hostels;
          }

          // Calculate distances and sort
          hostels.sort((a, b) {
            if (a.latitude == null || a.longitude == null) return 1;
            if (b.latitude == null || b.longitude == null) return -1;

            final distA = Geolocator.distanceBetween(
              lat,
              lng,
              a.latitude!,
              a.longitude!,
            );
            final distB = Geolocator.distanceBetween(
              lat,
              lng,
              b.latitude!,
              b.longitude!,
            );
            return distA.compareTo(distB);
          });

          return hostels;
        });
  }
  // ==================== NOTIFICATION OPERATIONS ====================

  // Save notification to Firestore
  Future<void> saveNotification(
    String userId,
    Map<String, dynamic> notificationData,
  ) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('notifications')
          .add({
            ...notificationData,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
    } catch (e) {
      throw 'Failed to save notification: $e';
    }
  }

  // Get user notifications stream
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data()};
          }).toList();
        });
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(
    String userId,
    String notificationId,
  ) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      throw 'Failed to mark notification as read: $e';
    }
  }

  // Delete a notification
  Future<void> deleteUserNotification(
    String userId,
    String notificationId,
  ) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      throw 'Failed to delete notification: $e';
    }
  }

  /// Comprehensive notification helper
  Future<void> sendAppNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type, // 'booking', 'system', 'offer'
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // 1. Save to Firestore (In-App)
      await saveNotification(recipientId, {
        'title': title,
        'body': body,
        'type': type,
        if (additionalData != null) ...additionalData,
      });

      // 2. Send Push Notification
      await NotificationService().sendPushNotification(
        playerId: recipientId,
        title: title,
        content: body,
        additionalData: {
          'type': type,
          if (additionalData != null) ...additionalData,
        },
      );
    } catch (e) {
      debugPrint("Error in sendAppNotification: $e");
    }
  }

  /// Broadcast notification to all users about a new property
  Future<void> broadcastNewPropertyNotification({
    required HostelModel hostel,
    double? maxDistanceKm, // For future range filtering
  }) async {
    try {
      final notificationService = NotificationService();
      final currentUserId = hostel.ownerId;

      // 1. Fetch all active users
      final usersSnapshot = await _firestore
          .collection(_usersCollection)
          .where('accountStatus', isEqualTo: 'active')
          .get();

      final recipientIds = <String>[];

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        if (userId == currentUserId) continue; // Skip the owner

        // FUTURE: Range filtering logic
        /*
        final userData = userDoc.data();
        final userLat = userData['latitude'] as double?;
        final userLng = userData['longitude'] as double?;
        
        if (maxDistanceKm != null && 
            hostel.latitude != null && 
            hostel.longitude != null && 
            userLat != null && 
            userLng != null) {
          final dist = Geolocator.distanceBetween(
                hostel.latitude!, 
                hostel.longitude!, 
                userLat, 
                userLng,
              ) / 1000; // to km
          if (dist > maxDistanceKm) continue;
        }
        */

        recipientIds.add(userId);

        // 2. Save In-App Notification (Firestore)
        // Note: For large user bases, use a Cloud Function and Batched Writes
        await saveNotification(userId, {
          'title': 'New Property Added! 🏠',
          'body':
              '${hostel.name} is now available in ${hostel.city}. Check it out!',
          'type': 'property',
          'hostelId': hostel.id,
        });
      }

      // 3. Send Batch Push Notification via OneSignal
      if (recipientIds.isNotEmpty) {
        await notificationService.sendPushToUsers(
          playerIds: recipientIds,
          title: 'New Property Alert! 🏠',
          content:
              '${hostel.name} is now available in ${hostel.city}. Check it out!',
          additionalData: {'type': 'property', 'hostelId': hostel.id},
        );
      }
    } catch (e) {
      debugPrint("Error in broadcastNewPropertyNotification: $e");
    }
  }

  /// Pre-load app data (hostels, location, etc.) during splash
  Future<void> preLoadAppData() async {
    try {
      // 1. Get current position (needed for distances)
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission != LocationPermission.deniedForever &&
            permission != LocationPermission.denied) {
          // Use a time limit for position to avoid hanging splash if GPS is slow
          try {
            await Geolocator.getCurrentPosition(
              timeLimit: const Duration(seconds: 5),
            );
          } catch (_) {
            debugPrint("Location pre-load timed out or failed");
          }
        }
      }

      // 2. Prefetch first batch of hostels (into Firestore cache)
      // This might fail if offline, so we wrap it
      try {
        await _firestore
            .collection(_hostelsCollection)
            .where('isActive', isEqualTo: true)
            .limit(20)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        debugPrint("Hostel pre-fetch timed out or failed (likely offline)");
      }

      debugPrint("✅ App Data Pre-load attempt finished");
    } catch (e) {
      debugPrint("❌ Error during pre-load: $e");
    }
  }
}
