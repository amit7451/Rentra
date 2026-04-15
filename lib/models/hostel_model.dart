import 'package:cloud_firestore/cloud_firestore.dart';

class HostelModel {
  final String id;
  final String name;
  final String description;
  final String address;
  final String city;
  final String country;
  final double rentPrice;
  final double? latitude;
  final double? longitude;
  final String? googleMapAddress;
  final String? state;
  final String? pincode;
  // For hostels: separate pricing per seater (1,2,3)
  final double? price1Seater;
  final double? price2Seater;
  final double? price3Seater;
  // Room counts for hostels
  final int rooms1Seater;
  final int rooms2Seater;
  final int rooms3Seater;
  // For flats: how many persons the flat can accommodate
  final int? flatCapacity;
  final String unitType; // 'hostel' or 'flat'
  final String rentPeriod; // 'yearly' or 'monthly'
  final double rating;
  final int totalReviews;
  final List<String> images;
  final List<String> amenities;
  final int availableRooms;
  final String ownerId;
  final DateTime createdAt;
  final bool isActive;

  HostelModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.country,
    required this.rentPrice,
    this.latitude,
    this.longitude,
    this.googleMapAddress,
    this.state,
    this.pincode,
    this.price1Seater,
    this.price2Seater,
    this.price3Seater,
    this.rooms1Seater = 0,
    this.rooms2Seater = 0,
    this.rooms3Seater = 0,
    this.flatCapacity,
    this.unitType = 'hostel',
    this.rentPeriod = 'yearly',
    this.rating = 0.0,
    this.totalReviews = 0,
    required this.images,
    required this.amenities,
    required this.availableRooms,
    required this.ownerId,
    required this.createdAt,
    this.isActive = true,
  });

  double get startingPrice {
    if (unitType.toLowerCase() == 'flat') return rentPrice;
    final prices = [
      price1Seater,
      price2Seater,
      price3Seater,
    ].where((p) => p != null && p > 0).map((p) => p!).toList();
    return prices.isEmpty ? rentPrice : prices.reduce((a, b) => a < b ? a : b);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'country': country,
      'pricePerNight': rentPrice,
      'latitude': latitude,
      'longitude': longitude,
      'googleMapAddress': googleMapAddress,
      'state': state,
      'pincode': pincode,
      'price1Seater': price1Seater,
      'price2Seater': price2Seater,
      'price3Seater': price3Seater,
      'rooms1Seater': rooms1Seater,
      'rooms2Seater': rooms2Seater,
      'rooms3Seater': rooms3Seater,
      'flatCapacity': flatCapacity,
      'unitType': unitType,
      'rentPeriod': rentPeriod,
      'rating': rating,
      'totalReviews': totalReviews,
      'images': images,
      'amenities': amenities,
      'availableRooms': availableRooms,
      'ownerId': ownerId,
      'isActive': isActive,
    };
  }

  factory HostelModel.empty() {
    return HostelModel(
      id: '',
      name: '',
      description: '',
      address: '',
      city: '',
      country: '',
      rentPrice: 0.0,
      latitude: null,
      longitude: null,
      googleMapAddress: null,
      state: null,
      pincode: null,
      price1Seater: null,
      price2Seater: null,
      price3Seater: null,
      rooms1Seater: 0,
      rooms2Seater: 0,
      rooms3Seater: 0,
      flatCapacity: null,
      unitType: 'hostel',
      rentPeriod: 'yearly',
      images: [],
      amenities: [],
      availableRooms: 0,
      ownerId: '',
      createdAt: DateTime.now(),
    );
  }

  factory HostelModel.fromMap(Map<String, dynamic> map) {
    DateTime parseCreatedAt(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    return HostelModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      country: map['country'] ?? '',
      rentPrice: (map['pricePerNight'] ?? 0.0).toDouble(),
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      googleMapAddress: map['googleMapAddress'],
      state: map['state'],
      pincode: map['pincode'],
      price1Seater: map['price1Seater'] == null
          ? null
          : (map['price1Seater'] as num).toDouble(),
      price2Seater: map['price2Seater'] == null
          ? null
          : (map['price2Seater'] as num).toDouble(),
      price3Seater: map['price3Seater'] == null
          ? null
          : (map['price3Seater'] as num).toDouble(),
      unitType: (map['unitType'] ?? 'hostel') as String,
      rentPeriod:
          (map['rentPeriod'] ??
                  ((map['unitType'] ?? 'hostel') == 'flat'
                      ? 'monthly'
                      : 'yearly'))
              as String,
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalReviews: map['totalReviews'] ?? 0,
      images: List<String>.from(map['images'] ?? []),
      amenities: List<String>.from(map['amenities'] ?? []),
      availableRooms: map['availableRooms'] ?? 0,
      rooms1Seater: map['rooms1Seater'] ?? 0,
      rooms2Seater: map['rooms2Seater'] ?? 0,
      rooms3Seater: map['rooms3Seater'] ?? 0,
      flatCapacity: map['flatCapacity'],
      ownerId: map['ownerId'] ?? '',
      createdAt: parseCreatedAt(map['createdAt']), // Use helper function
      isActive: map['isActive'] ?? true,
    );
  }

  HostelModel copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    String? city,
    String? country,
    double? rentPrice,
    double? latitude,
    double? longitude,
    String? googleMapAddress,
    String? state,
    String? pincode,
    double? price1Seater,
    double? price2Seater,
    double? price3Seater,
    String? unitType,
    String? rentPeriod,
    double? rating,
    int? totalReviews,
    List<String>? images,
    List<String>? amenities,
    int? availableRooms,
    int? rooms1Seater,
    int? rooms2Seater,
    int? rooms3Seater,
    int? flatCapacity,
    String? ownerId,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return HostelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      rentPrice: rentPrice ?? this.rentPrice,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      googleMapAddress: googleMapAddress ?? this.googleMapAddress,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      price1Seater: price1Seater ?? this.price1Seater,
      price2Seater: price2Seater ?? this.price2Seater,
      price3Seater: price3Seater ?? this.price3Seater,
      unitType: unitType ?? this.unitType,
      rentPeriod: rentPeriod ?? this.rentPeriod,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      images: images ?? this.images,
      amenities: amenities ?? this.amenities,
      availableRooms: availableRooms ?? this.availableRooms,
      rooms1Seater: rooms1Seater ?? this.rooms1Seater,
      rooms2Seater: rooms2Seater ?? this.rooms2Seater,
      rooms3Seater: rooms3Seater ?? this.rooms3Seater,
      flatCapacity: flatCapacity ?? this.flatCapacity,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}


