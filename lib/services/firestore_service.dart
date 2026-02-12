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
        'pricePerNight': hostel.pricePerNight,
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
  Stream<List<HostelModel>> getHostels() {
    return _firestore
        .collection(_hostelsCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => HostelModel.fromMap(doc.data()),
              ) // This calls fromMap
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

          // Filter by query (search in name, city, country)
          return hostels.where((hostel) {
            final searchQuery = query.toLowerCase();
            return hostel.name.toLowerCase().contains(searchQuery) ||
                hostel.city.toLowerCase().contains(searchQuery) ||
                hostel.country.toLowerCase().contains(searchQuery);
          }).toList();
        });
  }

  // Filter hostels by price range
  Stream<List<HostelModel>> filterHostelsByPrice({
    required double minPrice,
    required double maxPrice,
  }) {
    return _firestore
        .collection(_hostelsCollection)
        .where('isActive', isEqualTo: true)
        .where('pricePerNight', isGreaterThanOrEqualTo: minPrice)
        .where('pricePerNight', isLessThanOrEqualTo: maxPrice)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HostelModel.fromMap(doc.data()))
              .toList(),
        );
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
}
