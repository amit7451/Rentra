enum BookingStatus { pending, confirmed, cancelled, completed }

class BookingModel {
  final String id;
  final String userId;
  final String hostelId;
  final String hostelName;
  final String adminId; // Admin who owns this hostel
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int numberOfGuests;
  final double totalPrice;
  final BookingStatus status;
  final DateTime bookingDate;
  final String? specialRequests;
  final String? cancellationReason;
  final String? cancelledBy; // 'user' or 'admin'
  final int? selectedSeater; // 1, 2, or 3 for hostels; null or 0 for flats
  final int? flatCapacity; // Added capacity for flats
  final double? bookingFee; // Amount paid as registration fee

  // Payment info
  final String? paymentStatus; // 'successful', 'failed', null (pending)
  final String? razorpayOrderId;
  final String? razorpayPaymentId;

  BookingModel({
    required this.id,
    required this.userId,
    required this.hostelId,
    required this.hostelName,
    required this.adminId,
    required this.checkInDate,
    required this.checkOutDate,
    required this.numberOfGuests,
    required this.totalPrice,
    required this.status,
    required this.bookingDate,
    this.specialRequests,
    this.cancellationReason,
    this.cancelledBy,
    this.selectedSeater,
    this.flatCapacity,
    this.bookingFee,
    this.paymentStatus,
    this.razorpayOrderId,
    this.razorpayPaymentId,
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
      'adminId': adminId,
      'checkInDate': checkInDate.millisecondsSinceEpoch,
      'checkOutDate': checkOutDate.millisecondsSinceEpoch,
      'numberOfGuests': numberOfGuests,
      'totalPrice': totalPrice,
      'status': status.name,
      'bookingDate': bookingDate.millisecondsSinceEpoch,
      'specialRequests': specialRequests,
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
      'selectedSeater': selectedSeater,
      'flatCapacity': flatCapacity,
      'bookingFee': bookingFee,
      'paymentStatus': paymentStatus,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      hostelId: map['hostelId'] ?? '',
      hostelName: map['hostelName'] ?? '',
      adminId: map['adminId'] ?? '',
      checkInDate: DateTime.fromMillisecondsSinceEpoch(map['checkInDate'] ?? 0),
      checkOutDate: DateTime.fromMillisecondsSinceEpoch(
        map['checkOutDate'] ?? 0,
      ),
      numberOfGuests: map['numberOfGuests'] ?? 1,
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => BookingStatus.pending,
      ),
      bookingDate: DateTime.fromMillisecondsSinceEpoch(map['bookingDate'] ?? 0),
      specialRequests: map['specialRequests'],
      cancellationReason: map['cancellationReason'],
      cancelledBy: map['cancelledBy'],
      selectedSeater: map['selectedSeater'],
      flatCapacity: map['flatCapacity'],
      bookingFee: (map['bookingFee'] ?? 0.0).toDouble(),
      paymentStatus: map['paymentStatus'],
      razorpayOrderId: map['razorpayOrderId'],
      razorpayPaymentId: map['razorpayPaymentId'],
    );
  }

  BookingModel copyWith({
    String? id,
    String? userId,
    String? hostelId,
    String? hostelName,
    String? adminId,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    int? numberOfGuests,
    double? totalPrice,
    BookingStatus? status,
    DateTime? bookingDate,
    String? specialRequests,
    String? cancellationReason,
    String? cancelledBy,
    int? selectedSeater,
    int? flatCapacity,
    double? bookingFee,
    String? paymentStatus,
    String? razorpayOrderId,
    String? razorpayPaymentId,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      hostelId: hostelId ?? this.hostelId,
      hostelName: hostelName ?? this.hostelName,
      adminId: adminId ?? this.adminId,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      numberOfGuests: numberOfGuests ?? this.numberOfGuests,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      bookingDate: bookingDate ?? this.bookingDate,
      specialRequests: specialRequests ?? this.specialRequests,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      selectedSeater: selectedSeater ?? this.selectedSeater,
      flatCapacity: flatCapacity ?? this.flatCapacity,
      bookingFee: bookingFee ?? this.bookingFee,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      razorpayOrderId: razorpayOrderId ?? this.razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
    );
  }
}
