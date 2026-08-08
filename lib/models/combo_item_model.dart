class ComboCustomizationOptionModel {
  final String id;
  final String name;
  final double price;
  final bool isAvailable;

  const ComboCustomizationOptionModel({
    required this.id,
    required this.name,
    required this.price,
    this.isAvailable = true,
  });

  factory ComboCustomizationOptionModel.fromMap(Map<String, dynamic> data) {
    final priceVal = data['price'] ?? data['additionalPrice'] ?? 0;
    final double price = (priceVal is num)
        ? priceVal.toDouble()
        : double.tryParse(priceVal?.toString() ?? '0.0') ?? 0.0;

    final avail = data['isAvailable'] ?? data['available'] ?? data['isActive'] ?? data['active'] ?? true;

    return ComboCustomizationOptionModel(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? data['optionName'] ?? data['title'] ?? '').toString(),
      price: price,
      isAvailable: avail == true || avail.toString().toLowerCase() == 'true',
    );
  }
}

class ComboCustomizationGroupModel {
  final String id;
  final String name;
  final String selectionType; // 'SINGLE' or 'MULTI'
  final bool isRequired;
  final int minSelection;
  final int maxSelection;
  final List<ComboCustomizationOptionModel> options;

  const ComboCustomizationGroupModel({
    required this.id,
    required this.name,
    required this.selectionType,
    required this.isRequired,
    required this.minSelection,
    required this.maxSelection,
    required this.options,
  });

  factory ComboCustomizationGroupModel.fromMap(Map<String, dynamic> data) {
    final rawOptions = data['options'] as List? ?? [];
    final optionsList = <ComboCustomizationOptionModel>[];

    for (final item in rawOptions) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final opt = ComboCustomizationOptionModel.fromMap(map);
        if (opt.isAvailable) {
          optionsList.add(opt);
        }
      }
    }

    final selTypeRaw = (data['selectionType'] ?? data['type'] ?? 'single').toString().toUpperCase();
    final selType = selTypeRaw.contains('MULTI') ? 'MULTI' : 'SINGLE';

    final isReq = data['isRequired'] ?? data['required'] ?? true;
    final minSel = (data['minSelection'] is num)
        ? (data['minSelection'] as num).toInt()
        : (isReq ? 1 : 0);
    final maxSel = (data['maxSelection'] is num)
        ? (data['maxSelection'] as num).toInt()
        : (selType == 'SINGLE' ? 1 : 5);

    return ComboCustomizationGroupModel(
      id: (data['id'] ?? '').toString(),
      name: (data['title'] ?? data['name'] ?? data['groupName'] ?? 'Options').toString(),
      selectionType: selType,
      isRequired: isReq == true || isReq.toString().toLowerCase() == 'true',
      minSelection: minSel,
      maxSelection: maxSel,
      options: optionsList,
    );
  }
}

class ComboItemModel {
  final String id;
  final String comboId;
  final String restaurantId;
  final String? branchId;
  final List<String> branchIds;
  final String name;
  final String image;
  final String description;
  final double price;
  final double? originalPrice;
  final String foodType;
  final bool isVeg;
  final double rating;
  final int ratingCount;
  final bool isCustomisable;
  final List<ComboCustomizationGroupModel>? _customizationGroups;
  final DateTime? createdAt;

  const ComboItemModel({
    required this.id,
    required this.comboId,
    required this.restaurantId,
    this.branchId,
    required this.branchIds,
    required this.name,
    required this.image,
    required this.description,
    required this.price,
    this.originalPrice,
    this.foodType = 'Veg',
    this.isVeg = true,
    this.rating = 4.2,
    this.ratingCount = 569,
    this.isCustomisable = true,
    List<ComboCustomizationGroupModel>? customizationGroups,
    this.createdAt,
  }) : _customizationGroups = customizationGroups;

  List<ComboCustomizationGroupModel> get customizationGroups =>
      _customizationGroups ?? const [];

  factory ComboItemModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final branchIdsList = (data['branchIds'] as List?)
            ?.map((b) => b.toString().trim())
            .toList() ??
        [];

    final priceVal = data['price'] ?? data['displayPrice'] ?? data['basePrice'] ?? 0;
    final double price = (priceVal is num)
        ? priceVal.toDouble()
        : double.tryParse(priceVal?.toString() ?? '0.0') ?? 0.0;

    final origVal = data['originalPrice'] ?? data['mrp'] ?? data['regularPrice'];
    final double? originalPrice = (origVal is num)
        ? origVal.toDouble()
        : (origVal != null ? double.tryParse(origVal.toString()) : null);

    final String foodType = (data['foodType'] ?? (data['isVeg'] == false ? 'Non Veg' : 'Veg')).toString();
    final bool isVeg = data['isVeg'] ?? (foodType.toLowerCase() == 'veg');

    final ratingVal = data['rating'];
    final double rating = (ratingVal is num)
        ? ratingVal.toDouble()
        : double.tryParse(ratingVal?.toString() ?? '4.2') ?? 4.2;

    final countVal = data['ratingCount'];
    final int ratingCount = (countVal is num)
        ? countVal.toInt()
        : int.tryParse(countVal?.toString() ?? '569') ?? 569;

    final rawGroups = data['customizationGroups'] as List? ?? data['customizations'] as List? ?? [];
    final parsedGroups = <ComboCustomizationGroupModel>[];
    for (final item in rawGroups) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        parsedGroups.add(ComboCustomizationGroupModel.fromMap(map));
      }
    }

    DateTime? createdAt;
    if (data['createdAt'] is String) {
      createdAt = DateTime.tryParse(data['createdAt']);
    }

    return ComboItemModel(
      id: docId,
      comboId: (data['comboId'] ?? '').toString(),
      restaurantId: (data['restaurantId'] ?? '').toString(),
      branchId: data['branchId']?.toString(),
      branchIds: branchIdsList,
      name: (data['name'] ?? data['title'] ?? 'Item').toString(),
      image: (data['image'] ?? data['imageUrl'] ?? 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop').toString(),
      description: (data['description'] ?? '').toString(),
      price: price,
      originalPrice: originalPrice,
      foodType: foodType,
      isVeg: isVeg,
      rating: rating,
      ratingCount: ratingCount,
      isCustomisable: data['isCustomisable'] ?? (parsedGroups.isNotEmpty),
      customizationGroups: parsedGroups,
      createdAt: createdAt,
    );
  }
}
