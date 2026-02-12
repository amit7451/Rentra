import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages the user wishlist stored in Firestore.
///
/// Wishlist is stored as an array field `wishlistHostelIds` on the user
/// document in the `users` collection. Each entry is a hostelId string.
class WishlistService {
  final _db = FirebaseFirestore.instance;

  // ── Stream: wishlist hostel IDs ─────────────────────────────────────────

  /// Emits the list of hostelIds that the user has wishlisted.
  /// Automatically filters out deleted/inactive hostels.
  Stream<List<String>> watchWishlist(String userId) {
    return _db.collection('users').doc(userId).snapshots().asyncMap((
      snap,
    ) async {
      if (!snap.exists) return <String>[];
      final data = snap.data();
      if (data == null) return <String>[];
      final raw = data['wishlistHostelIds'];
      if (raw == null) return <String>[];
      final ids = List<String>.from(raw as List);

      // Filter to only include active hostels
      final validIds = <String>[];
      for (final id in ids) {
        final hostelDoc = await _db.collection('hostels').doc(id).get();
        if (hostelDoc.exists && (hostelDoc.data()?['isActive'] != false)) {
          validIds.add(id);
        }
      }

      // If there were invalid IDs, clean them up in the background
      if (validIds.length != ids.length) {
        await _cleanupWishlist(userId, validIds);
      }

      return validIds;
    });
  }

  // ── Check ────────────────────────────────────────────────────────────────

  /// One-time check if a hostel is in the wishlist.
  Future<bool> isWishlisted(String userId, String hostelId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    final data = doc.data();
    if (data == null) return false;
    final ids = List<String>.from(data['wishlistHostelIds'] ?? []);
    return ids.contains(hostelId);
  }

  // ── Toggle ───────────────────────────────────────────────────────────────

  /// Adds or removes the hostelId from the wishlist and returns the new state.
  Future<bool> toggleWishlist(String userId, String hostelId) async {
    final ref = _db.collection('users').doc(userId);
    final snap = await ref.get();
    final ids = List<String>.from(
      (snap.data()?['wishlistHostelIds'] as List?) ?? [],
    );

    if (ids.contains(hostelId)) {
      await ref.update({
        'wishlistHostelIds': FieldValue.arrayRemove([hostelId]),
      });
      return false; // removed
    } else {
      await ref.update({
        'wishlistHostelIds': FieldValue.arrayUnion([hostelId]),
      });
      return true; // added
    }
  }

  // ── Add / Remove (explicit) ───────────────────────────────────────────────

  Future<void> addToWishlist(String userId, String hostelId) async {
    await _db.collection('users').doc(userId).update({
      'wishlistHostelIds': FieldValue.arrayUnion([hostelId]),
    });
  }

  Future<void> removeFromWishlist(String userId, String hostelId) async {
    await _db.collection('users').doc(userId).update({
      'wishlistHostelIds': FieldValue.arrayRemove([hostelId]),
    });
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────

  /// Removes invalid hostel IDs from the user's wishlist.
  /// Called automatically by watchWishlist when stale IDs are detected.
  Future<void> _cleanupWishlist(String userId, List<String> validIds) async {
    try {
      await _db.collection('users').doc(userId).update({
        'wishlistHostelIds': validIds,
      });
    } catch (_) {
      // Fail silently; this is a background operation
    }
  }
}
