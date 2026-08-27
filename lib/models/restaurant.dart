import 'food_item.dart';
import 'home_hero_slider_model.dart';
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
  final double packagingCharge;
  final bool hasDineIn;
  final bool hasTakeaway;
  final bool hasDelivery;
  final String description;
  final String phone;
  final String openingTime;
  final String closingTime;
  final String fssaiNo;
  final List<String> gallery;
  final List<String>? _rawSliderImages;
  final List<HomeHeroSliderModel>? _rawHomeHeroSliders;

  List<String> get sliderImages {
    final list = _rawSliderImages;
    if (list != null && list.isNotEmpty) {
      return list;
    }
    return const [
      'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&q=80&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800&q=80&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80&auto=format&fit=crop',
    ];
  }

  List<HomeHeroSliderModel> get homeHeroSliders {
    final list = _rawHomeHeroSliders;
    if (list != null && list.isNotEmpty) {
      return list;
    }
    return kDefaultHomeHeroSliders;
  }

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
    this.packagingCharge = 0.0,
    this.hasDineIn = true,
    this.hasTakeaway = true,
    this.hasDelivery = true,
    this.description = '',
    this.phone = '',
    this.openingTime = '10:00 AM',
    this.closingTime = '11:00 PM',
    this.fssaiNo = '',
    this.gallery = const [],
    List<String>? sliderImages,
    List<HomeHeroSliderModel>? homeHeroSliders,
  })  : _rawSliderImages = sliderImages,
        _rawHomeHeroSliders = homeHeroSliders;



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

    final String desc = (docData['description'] ?? docData['about'] ?? '').toString();
    final String phoneNo = (docData['phone'] ?? docData['managerPhone'] ?? docData['branchPhone'] ?? '').toString();
    final String openTime = (docData['openingTime'] ?? docData['opening_time'] ?? '10:00 AM').toString();
    final String closeTime = (docData['closingTime'] ?? docData['closing_time'] ?? '11:00 PM').toString();

    final List<String> configuredSliderImages = [];
    final rawSlider = docData['sliderImages'] ?? docData['themeSliderImages'];
    if (rawSlider is List) {
      for (final item in rawSlider) {
        if (item is Map) {
          final bool isActive = item['active'] ?? item['enabled'] ?? true;
          final String url = (item['url'] ?? item['imageUrl'] ?? '').toString().trim();
          if (isActive && url.isNotEmpty) {
            configuredSliderImages.add(url);
          }
        } else if (item != null && item.toString().trim().isNotEmpty) {
          configuredSliderImages.add(item.toString().trim());
        }
      }
    }

    final List<String> activeThemeSliderImages = configuredSliderImages.isNotEmpty
        ? configuredSliderImages
        : const [
            'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&q=80&auto=format&fit=crop',
            'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800&q=80&auto=format&fit=crop',
            'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80&auto=format&fit=crop',
          ];

    final String primaryBanner = activeThemeSliderImages.isNotEmpty
        ? activeThemeSliderImages.first
        : (banner.isNotEmpty
            ? banner
            : 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&q=80&auto=format&fit=crop');

    final List<String> galleryImages = [];
    final rawGallery = docData['gallery'] ?? docData['galleryImages'];
    if (rawGallery is List) {
      for (final img in rawGallery) {
        if (img != null && img.toString().trim().isNotEmpty) {
          galleryImages.add(img.toString().trim());
        }
      }
    }


    final List<String> categoryList = [];
    final rawCategories = docData['cuisineType'] ?? docData['categories'];
    if (rawCategories is List) {
      for (final cat in rawCategories) {
        if (cat != null && cat.toString().trim().isNotEmpty) {
          categoryList.add(cat.toString().trim());
        }
      }
    } else if (rawCategories is String && rawCategories.trim().isNotEmpty) {
      categoryList.add(rawCategories.trim());
    }

    if (categoryList.isEmpty) {
      categoryList.addAll(['North Indian', 'Fast Food']);
    }

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

    final double rat = parseDouble(docData['rating'], fallback: 4.5);
    final String offer = (docData['offerText'] ?? docData['offer'] ?? '').toString();


    final List<HomeHeroSliderModel> activeHeroSliders = [];
    final rawHeroes = docData['homeHeroSliders'] ?? docData['heroSliders'];
    if (rawHeroes is List) {
      for (final h in rawHeroes) {
        if (h is Map) {
          final hero = HomeHeroSliderModel.fromMap(Map<String, dynamic>.from(h));
          if (hero.active) {
            activeHeroSliders.add(hero);
          }
        }
      }
    }

    final String fssaiNum = (docData['fssaiNumber'] ?? docData['fssai'] ?? docData['fssaiNo'] ?? docData['fssai_number'] ?? docData['fssaiLicense'] ?? docData['licenseNumber'] ?? docData['fssaiLicenseNumber'] ?? docData['global_fssai_number'] ?? '').toString().trim();

    return Restaurant(
      id: docId,
      branchId: (docData['branchId'] ?? docId).toString(),
      restaurantId: (docData['restaurantId'] ?? docId).toString(),
      name: combinedName,
      branchName: bName,
      logoUrl: logo.isNotEmpty ? logo : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=200&q=80&auto=format&fit=crop',
      bannerUrl: primaryBanner,
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
      packagingCharge: parseDouble(docData['packagingCharge'] ?? docData['packagingCharges'] ?? docData['packagingFee']),
      hasDineIn: docData['tableBookingEnabled'] == null
          ? (docData['hasDineIn'] ?? docData['hasTableService'] ?? true)
          : (docData['tableBookingEnabled'] == true),
      hasTakeaway: docData['hasTakeaway'] ?? true,
      hasDelivery: docData['hasDelivery'] ?? true,
      description: desc,
      phone: phoneNo,
      openingTime: openTime,
      closingTime: closeTime,
      fssaiNo: fssaiNum,
      gallery: galleryImages,
      sliderImages: activeThemeSliderImages,
      homeHeroSliders: activeHeroSliders.isNotEmpty ? activeHeroSliders : kDefaultHomeHeroSliders,
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
