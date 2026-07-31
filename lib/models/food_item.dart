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
    this.discountPrice,
    this.restaurantId,
    this.branchId,
    this.isBestseller = false,
    this.isRecommended = false,
  });

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

    final bool isAvailable = data['isAvailable'] ?? data['available'] ?? (data['stockStatus'] != 'OUT_OF_STOCK');

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
      discountPrice: discountPrice ?? this.discountPrice,
      restaurantId: restaurantId ?? this.restaurantId,
      branchId: branchId ?? this.branchId,
      isBestseller: isBestseller ?? this.isBestseller,
      isRecommended: isRecommended ?? this.isRecommended,
    );
  }
}
