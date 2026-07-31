import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phone;
  final String? fullName;
  final String? email;
  final String? photoUrl;
  final String? formattedAddress;
  final String? area;
  final String? city;
  final String? state;
  final String? pincode;
  final double? latitude;
  final double? longitude;
  final String? locationSource;
  final String? selectedAddressId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.phone,
    this.fullName,
    this.email,
    this.photoUrl,
    this.formattedAddress,
    this.area,
    this.city,
    this.state,
    this.pincode,
    this.latitude,
    this.longitude,
    this.locationSource,
    this.selectedAddressId,
    this.createdAt,
    this.updatedAt,
  });

  // Backward compatibility getters
  String get name => fullName ?? 'Foodie';
  String? get photo => photoUrl;
  String? get profileImage => photoUrl;

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value);
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return UserModel(
      uid: id.isNotEmpty ? id : (map['uid'] ?? ''),
      phone: map['phone'] ?? '',
      fullName: map['fullName'] ?? map['name'],
      email: map['email'],
      photoUrl: map['photoUrl'] ?? map['profileImage'] ?? map['photo'],
      formattedAddress: map['formattedAddress'] ?? map['deliveryAddress'],
      area: map['area'],
      city: map['city'],
      state: map['state'],
      pincode: map['pincode'],
      latitude: parseDouble(map['latitude']),
      longitude: parseDouble(map['longitude']),
      locationSource: map['locationSource'],
      selectedAddressId: map['selectedAddressId'],
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'phone': phone,
      if (fullName != null) 'fullName': fullName,
      if (email != null) 'email': email,
      if (photoUrl != null) ...{
        'photoUrl': photoUrl,
        'profileImage': photoUrl,
      },
      if (formattedAddress != null) ...{
        'formattedAddress': formattedAddress,
        'deliveryAddress': formattedAddress,
      },
      if (area != null) 'area': area,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (pincode != null) 'pincode': pincode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationSource != null) 'locationSource': locationSource,
      if (selectedAddressId != null) 'selectedAddressId': selectedAddressId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return map;
  }

  UserModel copyWith({
    String? uid,
    String? phone,
    String? fullName,
    String? email,
    String? photoUrl,
    String? formattedAddress,
    String? area,
    String? city,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    String? locationSource,
    String? selectedAddressId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      area: area ?? this.area,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationSource: locationSource ?? this.locationSource,
      selectedAddressId: selectedAddressId ?? this.selectedAddressId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
