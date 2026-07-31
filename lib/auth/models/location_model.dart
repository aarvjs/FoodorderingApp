class UserLocation {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String area;
  final String city;
  final String state;
  final String pincode;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.area = '',
    required this.city,
    required this.state,
    required this.pincode,
  });

  factory UserLocation.fromMap(Map<String, dynamic> map) {
    return UserLocation(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      formattedAddress: map['formattedAddress'] as String? ?? map['deliveryAddress'] as String? ?? '',
      area: map['area'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      pincode: map['pincode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'formattedAddress': formattedAddress,
      'deliveryAddress': formattedAddress,
      'area': area,
      'city': city,
      'state': state,
      'pincode': pincode,
    };
  }

  UserLocation copyWith({
    double? latitude,
    double? longitude,
    String? formattedAddress,
    String? area,
    String? city,
    String? state,
    String? pincode,
  }) {
    return UserLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      area: area ?? this.area,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
    );
  }
}
