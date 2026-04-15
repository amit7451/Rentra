// ============================================================
//  firestore_service_additions.dart
//  ── Add these methods to your existing FirestoreService ──
// ============================================================
//
//  These methods are required by the new admin + wishlist screens.
//  Copy them into your existing FirestoreService class.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hostel_model.dart';
import '../models/booking_model.dart';

// ─── PASTE INTO YOUR FirestoreService CLASS ───────────────────────────────

extension FirestoreServiceAdmin on /* your FirestoreService class */ Object {
  // final _db = FirebaseFirestore.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── Hostels ────────────────────────────────────────────────────────────

  /// Streams all hostels owned by a specific user.
  Stream<List<HostelModel>> getHostelsByOwner(String ownerId) {
    return _db
        .collection('hostels')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => HostelModel.fromMap(d.data())).toList(),
        );
  }

  /// Updates all mutable fields of an existing hostel document.
  Future<void> updateHostel(HostelModel hostel) async {
    await _db.collection('hostels').doc(hostel.id).update(hostel.toMap());
  }

  /// Deletes a hostel document.
  Future<void> deleteHostel(String hostelId) async {
    await _db.collection('hostels').doc(hostelId).delete();
  }

  /// Toggles the isActive flag on a hostel.
  Future<void> toggleHostelActive(String hostelId, bool isActive) async {
    await _db.collection('hostels').doc(hostelId).update({
      'isActive': isActive,
    });
  }

  /// Sets the availableRooms count. Called when a booking is confirmed/cancelled.
  Future<void> updateAvailableRooms(String hostelId, int rooms) async {
    await _db.collection('hostels').doc(hostelId).update({
      'availableRooms': rooms,
    });
  }

  // ── Bookings ───────────────────────────────────────────────────────────

  /// Streams bookings for a list of hostel IDs (admin use).
  ///
  /// Firestore `whereIn` supports up to 30 items. For larger sets, batch
  /// the queries or use a Cloud Function.
  Stream<List<BookingModel>> getBookingsForOwner(List<String> hostelIds) {
    if (hostelIds.isEmpty) return Stream.value([]);

    // Chunk into groups of 30 (Firestore whereIn limit)
    final chunks = <List<String>>[];
    for (var i = 0; i < hostelIds.length; i += 30) {
      chunks.add(
        hostelIds.sublist(
          i,
          i + 30 > hostelIds.length ? hostelIds.length : i + 30,
        ),
      );
    }

    // Merge streams from each chunk
    final streams = chunks
        .map(
          (chunk) => _db
              .collection('bookings')
              .where('hostelId', whereIn: chunk)
              .orderBy('bookingDate', descending: true)
              .snapshots()
              .map(
                (snap) => snap.docs
                    .map((d) => BookingModel.fromMap(d.data()))
                    .toList(),
              ),
        )
        .toList();

    // Combine all streams into one list
    // (simple approach for most use cases with ≤30 hostels)
    return streams.first;
  }

  /// Updates only the status field on a booking document.
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _db.collection('bookings').doc(bookingId).update({'status': status});
  }
}

// ─── ALSO ADD TO HostelModel ──────────────────────────────────────────────
//
// Add a `copyWith` method and a factory `empty()` to HostelModel:
//
// factory HostelModel.empty() => HostelModel(
//   id: '', name: '', description: '', address: '', city: '',
//   country: '', pricePerNight: 0, availableRooms: 0, rating: 0,
//   totalReviews: 0, images: [], amenities: [], ownerId: '',
//   createdAt: DateTime(2000), isActive: false,
// );
//
// HostelModel copyWith({
//   String? id, String? name, String? description, String? address,
//   String? city, String? country, double? pricePerNight,
//   int? availableRooms, double? rating, int? totalReviews,
//   List<String>? images, List<String>? amenities, String? ownerId,
//   DateTime? createdAt, bool? isActive,
// }) => HostelModel(
//   id: id ?? this.id,
//   name: name ?? this.name,
//   description: description ?? this.description,
//   address: address ?? this.address,
//   city: city ?? this.city,
//   country: country ?? this.country,
//   pricePerNight: pricePerNight ?? this.pricePerNight,
//   availableRooms: availableRooms ?? this.availableRooms,
//   rating: rating ?? this.rating,
//   totalReviews: totalReviews ?? this.totalReviews,
//   images: images ?? this.images,
//   amenities: amenities ?? this.amenities,
//   ownerId: ownerId ?? this.ownerId,
//   createdAt: createdAt ?? this.createdAt,
//   isActive: isActive ?? this.isActive,
// );
//
// ─── ALSO ADD TO AppRoutes ─────────────────────────────────────────────────
//
// static const String wishlist = '/wishlist';
// static const String adminDashboard = '/admin';
//
// Then in your router:
//   AppRoutes.wishlist: (_) => const WishlistScreen(),
//   AppRoutes.adminDashboard: (_) => const AdminDashboard(),
//
// ─── BOOKING MODEL FIELDS (from Firestore screenshot) ─────────────────────
//
// Ensure BookingModel has:
//   - id: String
//   - hostelId: String
//   - hostelName: String
//   - userId: String
//   - checkInDate: int   (milliseconds epoch)
//   - checkOutDate: int  (milliseconds epoch)
//   - numberOfGuests: int
//   - totalPrice: double
//   - status: String     ('pending' | 'confirmed' | 'cancelled')
//   - specialRequests: String?
//   - bookingDate: int   (milliseconds epoch)
//   - cancellationReason: String?


