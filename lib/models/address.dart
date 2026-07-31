class Address {
  final String id;
  final String label; // Home, Work, Other, Current GPS
  final String formattedAddress;
  final String house;
  final String street;
  final String locality;
  final String subLocality;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final String landmark;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final bool isCurrent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Address({
    required this.id,
    required this.label,
    String formattedAddress = '',
    String? fullAddress,
    String? addressLine,
    String house = '',
    String? houseNumber,
    String? building,
    this.street = '',
    this.locality = '',
    String subLocality = '',
    String? area,
    required this.city,
    required this.state,
    this.country = 'India',
    String postalCode = '',
    String? pincode,
    String? zipCode,
    this.landmark = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.isDefault = false,
    this.isCurrent = false,
    this.createdAt,
    this.updatedAt,
  })  : formattedAddress = formattedAddress != '' ? formattedAddress : (fullAddress ?? addressLine ?? ''),
        house = house != '' ? house : (houseNumber ?? building ?? ''),
        subLocality = subLocality != '' ? subLocality : (area ?? locality),
        postalCode = postalCode != '' ? postalCode : (pincode ?? zipCode ?? '');

  // Backward compatibility getters
  String get fullAddress => formattedAddress;
  String get addressId => id;
  String get houseNumber => house;
  String get building => house;
  String get area => subLocality.isNotEmpty ? subLocality : locality;
  String get pincode => postalCode;
  String get zipCode => postalCode;
  String get addressLine => formattedAddress;

  factory Address.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDateTime(dynamic val) {
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    final double lat = (map['latitude'] as num?)?.toDouble() ?? 0.0;
    final double lng = (map['longitude'] as num?)?.toDouble() ?? 0.0;

    return Address(
      id: docId.isNotEmpty ? docId : (map['id'] ?? map['addressId'] ?? ''),
      label: map['label'] ?? 'Saved Location',
      formattedAddress: map['formattedAddress'] ?? map['deliveryAddress'] ?? map['fullAddress'] ?? map['addressLine'] ?? '',
      house: map['house'] ?? map['houseNumber'] ?? map['building'] ?? '',
      street: map['street'] ?? '',
      locality: map['locality'] ?? map['area'] ?? '',
      subLocality: map['subLocality'] ?? map['area'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? 'India',
      postalCode: map['postalCode'] ?? map['pincode'] ?? map['zipCode'] ?? '',
      landmark: map['landmark'] ?? '',
      latitude: lat,
      longitude: lng,
      isDefault: map['isDefault'] ?? false,
      isCurrent: map['isCurrent'] ?? false,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'addressId': id,
      'label': label,
      'formattedAddress': formattedAddress,
      'deliveryAddress': formattedAddress,
      'fullAddress': formattedAddress,
      'addressLine': formattedAddress,
      'house': house,
      'houseNumber': house,
      'street': street,
      'locality': locality,
      'subLocality': subLocality,
      'area': subLocality.isNotEmpty ? subLocality : locality,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'pincode': postalCode,
      'zipCode': pincode,
      'landmark': landmark,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'isCurrent': isCurrent,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  Address copyWith({
    String? id,
    String? label,
    String? formattedAddress,
    String? house,
    String? street,
    String? locality,
    String? subLocality,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? landmark,
    double? latitude,
    double? longitude,
    bool? isDefault,
    bool? isCurrent,
    DateTime? createdAt,
    DateTime? updatedAt,
    // Backward compatibility aliases
    String? fullAddress,
    String? addressLine,
    String? houseNumber,
    String? building,
    String? area,
    String? pincode,
    String? zipCode,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      formattedAddress: formattedAddress ?? fullAddress ?? addressLine ?? this.formattedAddress,
      house: house ?? houseNumber ?? building ?? this.house,
      street: street ?? this.street,
      locality: locality ?? this.locality,
      subLocality: subLocality ?? area ?? this.subLocality,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? pincode ?? zipCode ?? this.postalCode,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      isCurrent: isCurrent ?? this.isCurrent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
