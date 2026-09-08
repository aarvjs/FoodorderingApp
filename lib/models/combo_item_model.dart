import 'food_item.dart';

List<dynamic> _rawToList(dynamic val) {
  if (val is List) return val;
  if (val is Map) return val.values.toList();
  return [];
}

class ComboVariantOption {
  final String id;
  final String name;
  final double additionalPrice;
  final double basePrice;
  final double extraPrice;
  final int minQuantity;
  final int maxQuantity;
  final int quantityStep;
  final bool allowQuantity;
  final bool isActive;

  const ComboVariantOption({
    required this.id,
    required this.name,
    required this.additionalPrice,
    this.basePrice = 0.0,
    this.extraPrice = 0.0,
    this.minQuantity = 1,
    this.maxQuantity = 10,
    this.quantityStep = 1,
    this.allowQuantity = true,
    this.isActive = true,
  });

  double get unitPrice => (basePrice > 0 ? basePrice : 0.0) + (extraPrice > 0 ? extraPrice : additionalPrice);

  factory ComboVariantOption.fromMap(Map<String, dynamic> data) {
    final priceVal = data['additionalPrice'] ?? data['extraPrice'] ?? data['price'] ?? 0;
    final double price = (priceVal is num)
        ? priceVal.toDouble()
        : double.tryParse(priceVal?.toString() ?? '0.0') ?? 0.0;

    final bpVal = data['basePrice'] ?? 0;
    final double basePrice = (bpVal is num)
        ? bpVal.toDouble()
        : double.tryParse(bpVal?.toString() ?? '0.0') ?? 0.0;

    final epVal = data['extraPrice'] ?? data['additionalPrice'] ?? price;
    final double extraPrice = (epVal is num)
        ? epVal.toDouble()
        : double.tryParse(epVal?.toString() ?? '0.0') ?? price;

    final minQ = data['minQuantity'] ?? data['minQty'] ?? 1;
    final maxQ = data['maxQuantity'] ?? data['maxQty'] ?? 10;
    final stepQ = data['quantityStep'] ?? data['step'] ?? 1;
    final active = data['isActive'] ?? data['isAvailable'] ?? data['active'] ?? true;

    return ComboVariantOption(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      additionalPrice: price,
      basePrice: basePrice,
      extraPrice: extraPrice,
      minQuantity: (minQ is num) ? minQ.toInt() : 1,
      maxQuantity: (maxQ is num) ? maxQ.toInt() : 10,
      quantityStep: (stepQ is num) ? stepQ.toInt() : 1,
      allowQuantity: data['allowQuantity'] != false,
      isActive: active == true || active.toString().toLowerCase() == 'true',
    );
  }
}

class ComboVariantItem {
  final String id;
  final String name;
  final String description;
  final bool isActive;
  final String selectionType; // 'SINGLE' or 'MULTI'
  final bool isRequired;
  final int minSelection;
  final int maxSelection;
  final List<ComboVariantOption> options;

  const ComboVariantItem({
    required this.id,
    required this.name,
    this.description = '',
    this.isActive = true,
    this.selectionType = 'SINGLE',
    this.isRequired = true,
    this.minSelection = 1,
    this.maxSelection = 1,
    required this.options,
  });

  factory ComboVariantItem.fromMap(Map<String, dynamic> data) {
    final rawOptions = _rawToList(data['options']);
    final optionsList = <ComboVariantOption>[];
    for (final item in rawOptions) {
      if (item is Map) {
        final opt = ComboVariantOption.fromMap(Map<String, dynamic>.from(item));
        if (opt.isActive) {
          optionsList.add(opt);
        }
      }
    }
    final active = data['isActive'] ?? data['active'] ?? true;
    final selTypeRaw = (data['selectionType'] ?? data['type'] ?? 'single').toString().toUpperCase();
    final selType = selTypeRaw.contains('MULTI') ? 'MULTI' : 'SINGLE';
    final isReq = data['isRequired'] ?? data['required'] ?? true;
    final isReqBool = isReq == true || isReq.toString().toLowerCase() == 'true';
    final minSel = (data['minSelection'] is num)
        ? (data['minSelection'] as num).toInt()
        : (int.tryParse(data['minSelection']?.toString() ?? '') ?? (isReqBool ? 1 : 0));
    final maxSel = (data['maxSelection'] is num)
        ? (data['maxSelection'] as num).toInt()
        : (int.tryParse(data['maxSelection']?.toString() ?? '') ?? (selType == 'SINGLE' ? 1 : 5));

    return ComboVariantItem(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      isActive: active == true || active.toString().toLowerCase() == 'true',
      selectionType: selType,
      isRequired: isReqBool,
      minSelection: minSel,
      maxSelection: maxSel,
      options: optionsList,
    );
  }
}

class ComboItemVariant {
  final String id;
  final String name;
  final bool isActive;
  final String selectionType; // 'SINGLE' or 'MULTI'
  final bool isRequired;
  final int minSelection;
  final int maxSelection;
  final List<ComboVariantItem> items;

  const ComboItemVariant({
    required this.id,
    required this.name,
    this.isActive = true,
    this.selectionType = 'SINGLE',
    this.isRequired = true,
    this.minSelection = 1,
    this.maxSelection = 1,
    required this.items,
  });

  factory ComboItemVariant.fromMap(Map<String, dynamic> data) {
    final active = data['isActive'] ?? data['active'] ?? true;
    final selTypeRaw = (data['selectionType'] ?? data['type'] ?? 'single').toString().toUpperCase();
    final selType = selTypeRaw.contains('MULTI') ? 'MULTI' : 'SINGLE';
    final isReq = data['isRequired'] ?? data['required'] ?? true;
    final isReqBool = isReq == true || isReq.toString().toLowerCase() == 'true';
    final minSel = (data['minSelection'] is num)
        ? (data['minSelection'] as num).toInt()
        : (int.tryParse(data['minSelection']?.toString() ?? '') ?? (isReqBool ? 1 : 0));
    final maxSel = (data['maxSelection'] is num)
        ? (data['maxSelection'] as num).toInt()
        : (int.tryParse(data['maxSelection']?.toString() ?? '') ?? (selType == 'SINGLE' ? 1 : 5));

    final rawItems = _rawToList(data['items']);
    final itemsList = <ComboVariantItem>[];
    for (final item in rawItems) {
      if (item is Map) {
        final varItem = ComboVariantItem.fromMap(Map<String, dynamic>.from(item));
        if (varItem.isActive) {
          itemsList.add(varItem);
        }
      }
    }

    if (itemsList.isEmpty && data['options'] != null) {
      final rawLegacyOptions = _rawToList(data['options']);
      final legacyOpts = <ComboVariantOption>[];
      for (final item in rawLegacyOptions) {
        if (item is Map) {
          final opt = ComboVariantOption.fromMap(Map<String, dynamic>.from(item));
          if (opt.isActive) {
            legacyOpts.add(opt);
          }
        }
      }
      if (legacyOpts.isNotEmpty) {
        itemsList.add(ComboVariantItem(
          id: 'vitem-default-${data['id'] ?? 'legacy'}',
          name: 'Items & Extras',
          description: '',
          isActive: true,
          selectionType: 'SINGLE',
          isRequired: true,
          minSelection: 1,
          maxSelection: 1,
          options: legacyOpts,
        ));
      }
    }

    return ComboItemVariant(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      isActive: active == true || active.toString().toLowerCase() == 'true',
      selectionType: selType,
      isRequired: isReqBool,
      minSelection: minSel,
      maxSelection: maxSel,
      items: itemsList,
    );
  }
}

class ComboCustomizationOptionModel {
  final String id;
  final String name;
  final double price;
  final double basePrice;
  final double extraPrice;
  final int minQuantity;
  final int maxQuantity;
  final int quantityStep;
  final bool allowQuantity;
  final bool isAvailable;

  const ComboCustomizationOptionModel({
    required this.id,
    required this.name,
    required this.price,
    this.basePrice = 0.0,
    this.extraPrice = 0.0,
    this.minQuantity = 1,
    this.maxQuantity = 10,
    this.quantityStep = 1,
    this.allowQuantity = true,
    this.isAvailable = true,
  });

  double get unitPrice => (basePrice > 0 ? basePrice : 0.0) + (extraPrice > 0 ? extraPrice : price);

  factory ComboCustomizationOptionModel.fromMap(Map<String, dynamic> data) {
    final priceVal = data['price'] ?? data['extraPrice'] ?? data['additionalPrice'] ?? 0;
    final double price = (priceVal is num)
        ? priceVal.toDouble()
        : double.tryParse(priceVal?.toString() ?? '0.0') ?? 0.0;

    final bpVal = data['basePrice'] ?? 0;
    final double basePrice = (bpVal is num)
        ? bpVal.toDouble()
        : double.tryParse(bpVal?.toString() ?? '0.0') ?? 0.0;

    final epVal = data['extraPrice'] ?? data['additionalPrice'] ?? price;
    final double extraPrice = (epVal is num)
        ? epVal.toDouble()
        : double.tryParse(epVal?.toString() ?? '0.0') ?? price;

    final minQ = data['minQuantity'] ?? data['minQty'] ?? 1;
    final maxQ = data['maxQuantity'] ?? data['maxQty'] ?? 10;
    final stepQ = data['quantityStep'] ?? data['step'] ?? 1;
    final avail = data['isAvailable'] ?? data['available'] ?? data['isActive'] ?? data['active'] ?? true;

    return ComboCustomizationOptionModel(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? data['optionName'] ?? data['title'] ?? '').toString(),
      price: price,
      basePrice: basePrice,
      extraPrice: extraPrice,
      minQuantity: (minQ is num) ? minQ.toInt() : (int.tryParse(minQ?.toString() ?? '1') ?? 1),
      maxQuantity: (maxQ is num) ? maxQ.toInt() : (int.tryParse(maxQ?.toString() ?? '10') ?? 10),
      quantityStep: (stepQ is num) ? stepQ.toInt() : (int.tryParse(stepQ?.toString() ?? '1') ?? 1),
      allowQuantity: data['allowQuantity'] != false,
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
    final rawOptions = _rawToList(data['options']);
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
    final isReqBool = isReq == true || isReq.toString().toLowerCase() == 'true';
    final minSel = (data['minSelection'] is num)
        ? (data['minSelection'] as num).toInt()
        : (int.tryParse(data['minSelection']?.toString() ?? '') ?? (isReqBool ? 1 : 0));
    final maxSel = (data['maxSelection'] is num)
        ? (data['maxSelection'] as num).toInt()
        : (int.tryParse(data['maxSelection']?.toString() ?? '') ?? (selType == 'SINGLE' ? 1 : 5));

    return ComboCustomizationGroupModel(
      id: (data['id'] ?? '').toString(),
      name: (data['title'] ?? data['name'] ?? data['groupName'] ?? 'Options').toString(),
      selectionType: selType,
      isRequired: isReqBool,
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
  final bool isActive;
  final String? availableFrom;
  final String? availableUntil;
  final List<String>? availableDays;
  final Map<String, dynamic>? branchAvailability;
  final bool isCustomisable;
  final List<ComboCustomizationGroupModel>? _customizationGroups;
  final bool isVariantEnabled;
  final List<ComboItemVariant> variants;
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
    this.isActive = true,
    this.availableFrom,
    this.availableUntil,
    this.availableDays,
    this.branchAvailability,
    this.isCustomisable = true,
    List<ComboCustomizationGroupModel>? customizationGroups,
    this.isVariantEnabled = false,
    this.variants = const [],
    this.createdAt,
  }) : _customizationGroups = customizationGroups;

  List<ComboCustomizationGroupModel> get customizationGroups =>
      _customizationGroups ?? const [];

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
    bool bActive = isActive;
    String sFrom = availableFrom ?? '';
    String sUntil = availableUntil ?? '';
    List<dynamic>? days = availableDays;

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

        if (map['availableDays'] is List) {
          days = List<String>.from((map['availableDays'] as List).map((e) => e.toString()));
        }
      }
    }

    if (!bActive) return false;
    if (!FoodItem.isDayAvailable(days)) return false;
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

  factory ComboItemModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final branchIdsList = _rawToList(data['branchIds'])
        .map((b) => b.toString().trim())
        .where((b) => b.isNotEmpty)
        .toList();

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

    final bool isActive = (data['isActive'] != false) && (data['isAvailable'] != false) && (data['status'] == null || data['status'] == 'ACTIVE');
    final String? availableFrom = data['availableFrom']?.toString();
    final String? availableUntil = data['availableUntil']?.toString();
    final Map<String, dynamic>? branchAvailability = data['branchAvailability'] is Map
        ? Map<String, dynamic>.from(data['branchAvailability'])
        : null;

    final rawGroupsData = data['customizationGroups'] ?? data['customizations'];
    final rawGroups = _rawToList(rawGroupsData);
    final parsedGroups = <ComboCustomizationGroupModel>[];
    for (final item in rawGroups) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        parsedGroups.add(ComboCustomizationGroupModel.fromMap(map));
      }
    }

    final bool isVariantEnabled = data['isVariantEnabled'] == true ||
        data['isVariantEnabled'].toString().toLowerCase() == 'true';

    final rawVariants = _rawToList(data['variants']);
    final parsedVariants = <ComboItemVariant>[];
    for (final item in rawVariants) {
      if (item is Map) {
        final variant = ComboItemVariant.fromMap(Map<String, dynamic>.from(item));
        if (variant.isActive) {
          parsedVariants.add(variant);
        }
      }
    }

    DateTime? createdAt;
    if (data['createdAt'] is String) {
      createdAt = DateTime.tryParse(data['createdAt']);
    }
    final List<String>? availableDays = data['availableDays'] != null
        ? _rawToList(data['availableDays']).map((e) => e.toString()).toList()
        : null;

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
      isActive: isActive,
      availableFrom: availableFrom,
      availableUntil: availableUntil,
      availableDays: availableDays,
      branchAvailability: branchAvailability,
      isCustomisable: data['isCustomisable'] ?? (parsedGroups.isNotEmpty || isVariantEnabled),
      customizationGroups: parsedGroups,
      isVariantEnabled: isVariantEnabled,
      variants: parsedVariants,
      createdAt: createdAt,
    );
  }
}

/// Helper class for calculating Combo Variant base prices and unit prices
class ComboCalculator {
  /// Calculates the dynamic base price for a specific size variant based on its REQUIRED items/options.
  static double calculateVariantBasePrice(
    ComboItemVariant variant, [
    Map<String, Set<String>>? selectedVariantOptions,
    Map<String, int>? optionQuantities,
  ]) {
    double basePrice = 0.0;

    for (final varItem in variant.items) {
      if (!varItem.isActive) continue;

      if (varItem.isRequired) {
        final selectedSet = selectedVariantOptions?[varItem.id];

        if (selectedSet != null && selectedSet.isNotEmpty) {
          for (final option in varItem.options) {
            if (option.isActive && selectedSet.contains(option.id)) {
              final qKey = '${varItem.id}:${option.id}';
              final qty = optionQuantities?[qKey] ?? 1;
              basePrice += option.unitPrice * qty;
            }
          }
        } else if (varItem.options.isNotEmpty) {
          final isSingle = varItem.selectionType == 'SINGLE';
          final countToTake = isSingle ? 1 : (varItem.minSelection > 0 ? varItem.minSelection : 1);
          final defaultOpts = varItem.options.where((o) => o.isActive).take(countToTake);
          for (final opt in defaultOpts) {
            final qKey = '${varItem.id}:${opt.id}';
            final qty = optionQuantities?[qKey] ?? 1;
            basePrice += opt.unitPrice * qty;
          }
        }
      }
    }

    return basePrice;
  }

  /// Calculates the final combo unit price.
  static double calculateComboFinalPrice({
    required ComboItemModel currentItem,
    ComboItemVariant? selectedVariant,
    Map<String, Set<String>>? selectedVariantOptions,
    Map<String, Set<String>>? selectedGroupOptions,
    Map<String, int>? optionQuantities,
  }) {
    if (currentItem.isVariantEnabled && selectedVariant != null) {
      final basePrice = calculateVariantBasePrice(selectedVariant, selectedVariantOptions, optionQuantities);
      double optionalAdditions = 0.0;

      for (final varItem in selectedVariant.items) {
        if (!varItem.isActive) continue;
        if (!varItem.isRequired) {
          final selectedSet = selectedVariantOptions?[varItem.id];
          if (selectedSet != null && selectedSet.isNotEmpty) {
            for (final option in varItem.options) {
              if (option.isActive && selectedSet.contains(option.id)) {
                final qKey = '${varItem.id}:${option.id}';
                final qty = optionQuantities?[qKey] ?? 1;
                optionalAdditions += option.unitPrice * qty;
              }
            }
          }
        }
      }

      return basePrice + optionalAdditions;
    } else {
      double total = currentItem.price;
      if (selectedGroupOptions != null) {
        for (final group in currentItem.customizationGroups) {
          final selectedSet = selectedGroupOptions[group.id];
          if (selectedSet != null && selectedSet.isNotEmpty) {
            for (final option in group.options) {
              if (option.isAvailable && selectedSet.contains(option.id)) {
                final qKey = '${group.id}:${option.id}';
                final qty = optionQuantities?[qKey] ?? 1;
                total += option.unitPrice * qty;
              }
            }
          }
        }
      }
      return total;
    }
  }
}

