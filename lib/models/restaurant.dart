import 'food_item.dart';
import '../core/utils/location_utils.dart';

class Restaurant {
  final String id;
  final String branchId;
  final String restaurantId;
  final String name;
  final String branchName;
  final String bannerUrl;
  final String logoUrl;
  final double rating;
  final int ratingCount;
  final String distance;
  final double distanceKm;
  final String deliveryTime;
  final String offerText;
  final bool isOpen;
  final List<String> categories;
  final List<FoodItem> items;
  final bool isFeatured;
  final double latitude;
  final double longitude;
  final double deliveryRadiusKm;
  final String address;
  final double minimumOrder;
  final double deliveryCharges;
  final bool hasDineIn;
  final bool hasTakeaway;
  final bool hasDelivery;

  const Restaurant({
    required this.id,
    this.branchId = '',
    this.restaurantId = '',
    required this.name,
    this.branchName = '',
    required this.bannerUrl,
    required this.logoUrl,
    required this.rating,
    required this.ratingCount,
    required this.distance,
    this.distanceKm = 0.0,
    required this.deliveryTime,
    required this.offerText,
    required this.isOpen,
    required this.categories,
    required this.items,
    this.isFeatured = false,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.deliveryRadiusKm = 10.0,
    this.address = '',
    this.minimumOrder = 0.0,
    this.deliveryCharges = 0.0,
    this.hasDineIn = true,
    this.hasTakeaway = true,
    this.hasDelivery = true,
  });

  /// Factory constructor to parse Firestore document (from `branches` or `restaurants` collections)
  factory Restaurant.fromFirestore({
    required Map<String, dynamic> docData,
    required String docId,
    double userLat = 0.0,
    double userLng = 0.0,
    List<FoodItem> menuItems = const [],
  }) {
    final String rName = (docData['restaurantName'] ?? docData['name'] ?? 'Restaurant').toString();
    final String bName = (docData['branchName'] ?? docData['name'] ?? '').toString();
    final String combinedName = (bName.isNotEmpty && bName != rName) ? '$rName ($bName)' : rName;

    final String logo = (docData['logo'] ?? docData['logoUrl'] ?? '').toString();
    final String banner = (docData['banner'] ?? docData['bannerUrl'] ?? docData['coverImage'] ?? '').toString();

    // Coordinates
    final double lat = parseDouble(docData['latitude'] ?? docData['location']?['latitude']);
    final double lng = parseDouble(docData['longitude'] ?? docData['location']?['longitude']);

    // Radius
    final double radius = parseDouble(
      docData['serviceRadiusKm'] ?? docData['deliveryRadiusKm'] ?? docData['deliveryRadius'] ?? docData['radius'],
      fallback: 5.0,
    );

    // Calculated distance in KM
    final double computedDistKm = (userLat != 0.0 && userLng != 0.0 && lat != 0.0 && lng != 0.0)
        ? LocationUtils.calculateDistance(userLat, userLng, lat, lng)
        : 1.5;

    final String formattedDist = LocationUtils.formatDistance(computedDistKm);

    // Delivery time estimate based on distance
    final int estMinutes = 20 + (computedDistKm * 4).round();
    final String delTime = '$estMinutes-${estMinutes + 10} min';

    final String statusStr = (docData['status'] ?? 'OPEN').toString().toUpperCase();
    final bool openStatus = statusStr == 'OPEN' || statusStr == 'ACTIVE';

    final List<String> categoryList = docData['cuisineType'] != null
        ? List<String>.from(docData['cuisineType'])
        : (docData['categories'] != null ? List<String>.from(docData['categories']) : ['North Indian', 'Fast Food']);

    final double rat = parseDouble(docData['rating'], fallback: 4.5);
    final String offer = (docData['offerText'] ?? docData['offer'] ?? '50% OFF up to ₹100').toString();

    return Restaurant(
      id: docId,
      branchId: (docData['branchId'] ?? docId).toString(),
      restaurantId: (docData['restaurantId'] ?? docId).toString(),
      name: combinedName,
      branchName: bName,
      logoUrl: logo.isNotEmpty ? logo : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=200&q=80&auto=format&fit=crop',
      bannerUrl: banner.isNotEmpty ? banner : 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80&auto=format&fit=crop',
      rating: rat,
      ratingCount: (docData['ratingCount'] is num) ? (docData['ratingCount'] as num).toInt() : 120,
      distance: formattedDist,
      distanceKm: computedDistKm,
      deliveryTime: delTime,
      offerText: offer,
      isOpen: openStatus,
      categories: categoryList.isEmpty ? ['North Indian', 'Fast Food'] : categoryList,
      items: menuItems,
      isFeatured: docData['isFeatured'] == true || docData['featured'] == true,
      latitude: lat,
      longitude: lng,
      deliveryRadiusKm: radius,
      address: (docData['address'] ?? docData['location']?['formattedAddress'] ?? '').toString(),
      minimumOrder: parseDouble(docData['minimumOrder']),
      deliveryCharges: parseDouble(docData['deliveryCharges']),
      hasDineIn: docData['tableBookingEnabled'] == null
          ? (docData['hasDineIn'] ?? docData['hasTableService'] ?? true)
          : (docData['tableBookingEnabled'] == true),
      hasTakeaway: docData['hasTakeaway'] ?? true,
      hasDelivery: docData['hasDelivery'] ?? true,
    );
  }

  static double parseDouble(dynamic val, {double fallback = 0.0}) {
    if (val is num) return val.toDouble();
    if (val != null) {
      final parsed = double.tryParse(val.toString());
      if (parsed != null) return parsed;
    }
    return fallback;
  }
}
