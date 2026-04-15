import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? phoneNumber;
  final String? photoUrl;
  final DateTime? dateOfBirth;
  final String? gender;
  final DateTime createdAt;
  final bool isAdmin;
  final String accountStatus; // 'active', 'deleted', 'suspended'
  final bool isActive;
  final DateTime? deletedAt;

  final List<Map<String, dynamic>>? savedPaymentMethods;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.phoneNumber,
    this.photoUrl,
    this.dateOfBirth,
    this.gender,
    required this.createdAt,
    this.isAdmin = false,
    this.accountStatus = 'active',
    this.isActive = true,
    this.deletedAt,
    this.savedPaymentMethods,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'dateOfBirth': dateOfBirth?.millisecondsSinceEpoch,
      'gender': gender,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isAdmin': isAdmin,
      'accountStatus': accountStatus,
      'isActive': isActive,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
      'savedPaymentMethods': savedPaymentMethods,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'],
      photoUrl: map['photoUrl'],
      dateOfBirth: _parseDate(map['dateOfBirth']),
      gender: map['gender'],
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      isAdmin: map['isAdmin'] ?? false,
      accountStatus: map['accountStatus'] ?? 'active',
      isActive: map['isActive'] ?? true,
      deletedAt: _parseDate(map['deletedAt']),
      savedPaymentMethods: map['savedPaymentMethods'] != null
          ? List<Map<String, dynamic>>.from(map['savedPaymentMethods'])
          : null,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? phoneNumber,
    String? photoUrl,
    DateTime? dateOfBirth,
    String? gender,
    DateTime? createdAt,
    bool? isAdmin,
    String? accountStatus,
    bool? isActive,
    DateTime? deletedAt,
    List<Map<String, dynamic>>? savedPaymentMethods,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      isAdmin: isAdmin ?? this.isAdmin,
      accountStatus: accountStatus ?? this.accountStatus,
      isActive: isActive ?? this.isActive,
      deletedAt: deletedAt ?? this.deletedAt,
      savedPaymentMethods: savedPaymentMethods ?? this.savedPaymentMethods,
    );
  }
}


