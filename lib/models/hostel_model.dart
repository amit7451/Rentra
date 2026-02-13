import 'package:cloud_firestore/cloud_firestore.dart';

class HostelModel {
  final String id;
  final String name;
  final String description;
  final String address;
  final String city;
  final String country;
  final double pricePerNight;
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
    required this.pricePerNight,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'country': country,
      'pricePerNight': pricePerNight,
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
      pricePerNight: 0.0,
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
      pricePerNight: (map['pricePerNight'] ?? 0.0).toDouble(),
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
    double? pricePerNight,
    String? unitType,
    String? rentPeriod,
    double? rating,
    int? totalReviews,
    List<String>? images,
    List<String>? amenities,
    int? availableRooms,
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
      pricePerNight: pricePerNight ?? this.pricePerNight,
      unitType: unitType ?? this.unitType,
      rentPeriod: rentPeriod ?? this.rentPeriod,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      images: images ?? this.images,
      amenities: amenities ?? this.amenities,
      availableRooms: availableRooms ?? this.availableRooms,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
