import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/hostel_model.dart';
import '../models/booking_model.dart';

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

  // Delete user
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).delete();
    } catch (e) {
      throw 'Failed to delete user: $e';
    }
  }

  // ==================== HOSTEL OPERATIONS ====================

  // Add new hostel (for admin)
  Future<void> addHostel(HostelModel hostel) async {
    try {
      final docRef = _firestore.collection(_hostelsCollection).doc();

      // Create hostel data with auto-generated ID and active status
      final hostelData = {
        'id': docRef.id,
        'name': hostel.name,
        'description': hostel.description,
        'address': hostel.address,
        'city': hostel.city,
        'country': hostel.country,
        'pricePerNight': hostel.rentPrice,
        'price1Seater': hostel.price1Seater,
        'price2Seater': hostel.price2Seater,
        'price3Seater': hostel.price3Seater,
        'rooms1Seater': hostel.rooms1Seater,
        'rooms2Seater': hostel.rooms2Seater,
        'rooms3Seater': hostel.rooms3Seater,
        'flatCapacity': hostel.flatCapacity,
        'unitType': hostel.unitType,
        'rentPeriod': hostel.rentPeriod,
        'availableRooms': hostel.availableRooms,
        'rating': hostel.rating,
        'totalReviews': hostel.totalReviews,
        'images': hostel.images,
        'amenities': hostel.amenities,
        'ownerId': hostel.ownerId, // Critical: link hostel to owner
        'isActive': true, // Default active status
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(hostelData);
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

    // Server-side: match index #1 and #2. Client-side: filter out full rooms.
    query = query.orderBy('rating', descending: true).limit(30);

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => HostelModel.fromMap(doc.data()))
          .where((h) => h.availableRooms > 0)
          .toList(),
    );
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
    String? sortBy, // 'price_asc', 'price_desc', 'rating_desc'
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

          // 2. Filter by search query
          if (query != null && query.isNotEmpty) {
            final q = query.toLowerCase();
            filtered = filtered
                .where(
                  (h) =>
                      h.name.toLowerCase().contains(q) ||
                      h.city.toLowerCase().contains(q) ||
                      h.country.toLowerCase().contains(q),
                )
                .toList();
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

          // 4. Sort
          if (sortBy == 'price_asc') {
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
  Future<void> cancelBooking(String bookingId, String reason) async {
    try {
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': BookingStatus.cancelled.name,
        'cancellationReason': reason,
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
}
