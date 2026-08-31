class FoodItem {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final double rating;
  final int reviewCount;
  final bool isVeg;
  final List<String> ingredients;
  final Map<String, String> nutrition;
  final List<String> reviews;
  final String category;
  final bool isAvailable;
  final String? availableFrom;
  final String? availableUntil;
  final Map<String, dynamic>? branchAvailability;
  final double? discountPrice;
  final String? restaurantId;
  final String? branchId;
  final bool isBestseller;
  final bool isRecommended;

  const FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.isVeg,
    required this.ingredients,
    required this.nutrition,
    required this.reviews,
    required this.category,
    this.isAvailable = true,
    this.availableFrom,
    this.availableUntil,
    this.branchAvailability,
    this.discountPrice,
    this.restaurantId,
    this.branchId,
    this.isBestseller = false,
    this.isRecommended = false,
  });

  static int? parseTimeToMinutes(String timeStr) {
    if (timeStr.isEmpty) return null;
    try {
      final cleaned = timeStr.trim().toUpperCase();
      final isPM = cleaned.contains('PM');
      final isAM = cleaned.contains('AM');
      final digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digitsOnly.split(':');
      if (parts.isEmpty || parts[0].isEmpty) return null;

      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 && parts[1].isNotEmpty ? int.parse(parts[1]) : 0;

      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return hour * 60 + minute;
    } catch (_) {
      return null;
    }
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  bool isCurrentlyAvailableForBranch(String? targetBranchId) {
    bool bActive = isAvailable;
    String sFrom = availableFrom ?? '';
    String sUntil = availableUntil ?? '';

    if (branchAvailability != null && branchAvailability!.isNotEmpty) {
      dynamic override;
      if (targetBranchId != null && targetBranchId.isNotEmpty) {
        override = branchAvailability![targetBranchId];
      }
      if (override == null) {
        override = branchAvailability!.values.firstWhere((v) => v is Map, orElse: () => null);
      }

      if (override is Map) {
        final Map map = override;
        if (map.containsKey('isActive')) {
          bActive = map['isActive'] == true;
        } else if (map.containsKey('isAvailable')) {
          bActive = map['isAvailable'] == true;
        }

        final fromMap = _firstNonEmpty([map['availableFrom']]);
        if (fromMap.isNotEmpty) sFrom = fromMap;

        final untilMap = _firstNonEmpty([map['availableUntil']]);
        if (untilMap.isNotEmpty) sUntil = untilMap;
      }
    }

    if (!bActive) return false;
    return _isWithinTimeSchedule(sFrom, sUntil);
  }

  bool _isWithinTimeSchedule(String sFrom, String sUntil) {
    final startMinutesParsed = parseTimeToMinutes(sFrom);
    final endMinutesParsed = parseTimeToMinutes(sUntil);

    if (startMinutesParsed == null && endMinutesParsed == null) return true;

    final startMinutes = startMinutesParsed ?? 0;
    final endMinutes = endMinutesParsed ?? 1439;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    if (endMinutes > startMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      return true;
    }
  }

  factory FoodItem.fromFirestore(Map<String, dynamic> data, String docId) {
    final name = (data['name'] ?? data['title'] ?? 'Food Item').toString();
    final description = (data['description'] ?? data['fullDescription'] ?? '').toString();
    final image = (data['image'] ?? data['imageUrl'] ?? '').toString();
    
    final priceVal = data['price'];
    final double price = (priceVal is num) ? priceVal.toDouble() : double.tryParse(priceVal?.toString() ?? '0') ?? 0.0;

    final discVal = data['discountPrice'] ?? data['offerPrice'];
    final double? discountPrice = (discVal is num) ? discVal.toDouble() : (discVal != null ? double.tryParse(discVal.toString()) : null);

    final ratingVal = data['rating'];
    final double rating = (ratingVal is num) ? ratingVal.toDouble() : double.tryParse(ratingVal?.toString() ?? '4.5') ?? 4.5;

    final isVegVal = data['isVeg'] ?? (data['veg'] == 'Veg' || data['foodType'] == 'Veg');
    final bool isVeg = isVegVal is bool ? isVegVal : true;

    final bool isAvailable = (data['status'] == null || data['status'] == 'ACTIVE') &&
        (data['isAvailable'] ?? data['available'] ?? (data['stockStatus'] != 'OUT_OF_STOCK'));

    final String? availableFrom = data['availableFrom']?.toString();
    final String? availableUntil = data['availableUntil']?.toString();
    final Map<String, dynamic>? branchAvailability = data['branchAvailability'] is Map
        ? Map<String, dynamic>.from(data['branchAvailability'])
        : null;

    final ingredientsList = (data['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final categoryStr = (data['category'] ?? data['subCategory'] ?? 'General').toString();

    return FoodItem(
      id: docId,
      name: name,
      description: description,
      imageUrl: image.isNotEmpty
          ? image
          : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500&q=80&auto=format&fit=crop',
      price: price,
      discountPrice: discountPrice,
      rating: rating,
      reviewCount: (data['reviewCount'] is num) ? (data['reviewCount'] as num).toInt() : 42,
      isVeg: isVeg,
      ingredients: ingredientsList,
      nutrition: const {'Calories': '350 kcal', 'Protein': '12g'},
      reviews: const ['Very delicious!', 'Fast preparation'],
      category: categoryStr,
      isAvailable: isAvailable,
      availableFrom: availableFrom,
      availableUntil: availableUntil,
      branchAvailability: branchAvailability,
      restaurantId: data['restaurantId']?.toString(),
      branchId: data['branchId']?.toString(),
      isBestseller: data['bestseller'] == true,
      isRecommended: data['recommended'] == true,
    );
  }

  FoodItem copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    double? price,
    double? rating,
    int? reviewCount,
    bool? isVeg,
    List<String>? ingredients,
    Map<String, String>? nutrition,
    List<String>? reviews,
    String? category,
    bool? isAvailable,
    String? availableFrom,
    String? availableUntil,
    Map<String, dynamic>? branchAvailability,
    double? discountPrice,
    String? restaurantId,
    String? branchId,
    bool? isBestseller,
    bool? isRecommended,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isVeg: isVeg ?? this.isVeg,
      ingredients: ingredients ?? this.ingredients,
      nutrition: nutrition ?? this.nutrition,
      reviews: reviews ?? this.reviews,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      branchAvailability: branchAvailability ?? this.branchAvailability,
      discountPrice: discountPrice ?? this.discountPrice,
      restaurantId: restaurantId ?? this.restaurantId,
      branchId: branchId ?? this.branchId,
      isBestseller: isBestseller ?? this.isBestseller,
      isRecommended: isRecommended ?? this.isRecommended,
    );
  }
}
