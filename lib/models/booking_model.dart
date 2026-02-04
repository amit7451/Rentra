enum BookingStatus {
  pending,
  confirmed,
  cancelled,
  completed,
}

class BookingModel {
  final String id;
  final String userId;
  final String hostelId;
  final String hostelName;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int numberOfGuests;
  final double totalPrice;
  final BookingStatus status;
  final DateTime bookingDate;
  final String? specialRequests;
  final String? cancellationReason;

  BookingModel({
    required this.id,
    required this.userId,
    required this.hostelId,
    required this.hostelName,
    required this.checkInDate,
    required this.checkOutDate,
    required this.numberOfGuests,
    required this.totalPrice,
    required this.status,
    required this.bookingDate,
    this.specialRequests,
    this.cancellationReason,
  });

  int get numberOfNights {
    return checkOutDate.difference(checkInDate).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'hostelId': hostelId,
      'hostelName': hostelName,
      'checkInDate': checkInDate.millisecondsSinceEpoch,
      'checkOutDate': checkOutDate.millisecondsSinceEpoch,
      'numberOfGuests': numberOfGuests,
      'totalPrice': totalPrice,
      'status': status.name,
      'bookingDate': bookingDate.millisecondsSinceEpoch,
      'specialRequests': specialRequests,
      'cancellationReason': cancellationReason,
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      hostelId: map['hostelId'] ?? '',
      hostelName: map['hostelName'] ?? '',
      checkInDate: DateTime.fromMillisecondsSinceEpoch(map['checkInDate'] ?? 0),
      checkOutDate: DateTime.fromMillisecondsSinceEpoch(map['checkOutDate'] ?? 0),
      numberOfGuests: map['numberOfGuests'] ?? 1,
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
      status: BookingStatus.values.firstWhere(
            (e) => e.name == map['status'],
        orElse: () => BookingStatus.pending,
      ),
      bookingDate: DateTime.fromMillisecondsSinceEpoch(map['bookingDate'] ?? 0),
      specialRequests: map['specialRequests'],
      cancellationReason: map['cancellationReason'],
    );
  }

  BookingModel copyWith({
    String? id,
    String? userId,
    String? hostelId,
    String? hostelName,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    int? numberOfGuests,
    double? totalPrice,
    BookingStatus? status,
    DateTime? bookingDate,
    String? specialRequests,
    String? cancellationReason,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      hostelId: hostelId ?? this.hostelId,
      hostelName: hostelName ?? this.hostelName,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      numberOfGuests: numberOfGuests ?? this.numberOfGuests,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      bookingDate: bookingDate ?? this.bookingDate,
      specialRequests: specialRequests ?? this.specialRequests,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}
