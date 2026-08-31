class ComboVariantOption {
  final String id;
  final String name;
  final double additionalPrice;
  final bool isActive;

  const ComboVariantOption({
    required this.id,
    required this.name,
    required this.additionalPrice,
    this.isActive = true,
  });

  factory ComboVariantOption.fromMap(Map<String, dynamic> data) {
    final priceVal = data['additionalPrice'] ?? data['price'] ?? 0;
    final double price = (priceVal is num)
        ? priceVal.toDouble()
        : double.tryParse(priceVal?.toString() ?? '0.0') ?? 0.0;
    final active = data['isActive'] ?? data['isAvailable'] ?? data['active'] ?? true;
    return ComboVariantOption(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      additionalPrice: price,
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
    final rawOptions = data['options'] as List? ?? [];
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
        : (isReqBool ? 1 : 0);
    final maxSel = (data['maxSelection'] is num)
        ? (data['maxSelection'] as num).toInt()
        : (selType == 'SINGLE' ? 1 : 5);

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
        : (isReqBool ? 1 : 0);
    final maxSel = (data['maxSelection'] is num)
        ? (data['maxSelection'] as num).toInt()
        : (selType == 'SINGLE' ? 1 : 5);

    final rawItems = data['items'] as List? ?? [];
    final itemsList = <ComboVariantItem>[];
    for (final item in rawItems) {
      if (item is Map) {
        final varItem = ComboVariantItem.fromMap(Map<String, dynamic>.from(item));
        if (varItem.isActive) {
          itemsList.add(varItem);
        }
      }
    }

    if (itemsList.isEmpty && data['options'] is List) {
      final rawLegacyOptions = data['options'] as List;
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
  final bool isActive;
  final String? availableFrom;
  final String? availableUntil;
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

    final bool isActive = (data['isActive'] != false) && (data['isAvailable'] != false) && (data['status'] == null || data['status'] == 'ACTIVE');
    final String? availableFrom = data['availableFrom']?.toString();
    final String? availableUntil = data['availableUntil']?.toString();
    final Map<String, dynamic>? branchAvailability = data['branchAvailability'] is Map
        ? Map<String, dynamic>.from(data['branchAvailability'])
        : null;

    final rawGroups = data['customizationGroups'] as List? ?? data['customizations'] as List? ?? [];
    final parsedGroups = <ComboCustomizationGroupModel>[];
    for (final item in rawGroups) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        parsedGroups.add(ComboCustomizationGroupModel.fromMap(map));
      }
    }

    final bool isVariantEnabled = data['isVariantEnabled'] == true ||
        data['isVariantEnabled'].toString().toLowerCase() == 'true';

    final rawVariants = data['variants'] as List? ?? [];
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
  /// 
  /// If [selectedVariantOptions] is provided, calculates using the selected options within required groups.
  /// If [selectedVariantOptions] is null or doesn't have a selection for a required group, defaults to the
  /// configured default required choice(s) (first option for single selection, or first minSelection options for multi selection).
  /// Optional items/groups are NEVER included in the Size Base Price.
  static double calculateVariantBasePrice(
    ComboItemVariant variant, [
    Map<String, Set<String>>? selectedVariantOptions,
  ]) {
    double basePrice = 0.0;

    for (final varItem in variant.items) {
      if (!varItem.isActive) continue;

      // Only REQUIRED items contribute to the Size Base Price
      if (varItem.isRequired) {
        final selectedSet = selectedVariantOptions?[varItem.id];

        if (selectedSet != null && selectedSet.isNotEmpty) {
          // Add prices of explicitly selected options in this required group
          for (final option in varItem.options) {
            if (option.isActive && selectedSet.contains(option.id)) {
              basePrice += option.additionalPrice;
            }
          }
        } else if (varItem.options.isNotEmpty) {
          // Fallback to default required selection(s) if no user selection is present yet
          final isSingle = varItem.selectionType == 'SINGLE';
          final countToTake = isSingle ? 1 : (varItem.minSelection > 0 ? varItem.minSelection : 1);
          final defaultOpts = varItem.options.where((o) => o.isActive).take(countToTake);
          for (final opt in defaultOpts) {
            basePrice += opt.additionalPrice;
          }
        }
      }
    }

    return basePrice;
  }

  /// Calculates the final combo unit price.
  /// 
  /// When [isVariantEnabled] is true:
  ///   UnitPrice = calculateVariantBasePrice(selectedVariant, selectedVariantOptions) + Sum(selected OPTIONAL options)
  /// When [isVariantEnabled] is false:
  ///   UnitPrice = currentItem.price + Sum(selected customization options)
  static double calculateComboFinalPrice({
    required ComboItemModel currentItem,
    ComboItemVariant? selectedVariant,
    Map<String, Set<String>>? selectedVariantOptions,
    Map<String, Set<String>>? selectedGroupOptions,
  }) {
    if (currentItem.isVariantEnabled && selectedVariant != null) {
      final basePrice = calculateVariantBasePrice(selectedVariant, selectedVariantOptions);
      double optionalAdditions = 0.0;

      for (final varItem in selectedVariant.items) {
        if (!varItem.isActive) continue;
        // Only OPTIONAL items add on top of the Size Base Price
        if (!varItem.isRequired) {
          final selectedSet = selectedVariantOptions?[varItem.id];
          if (selectedSet != null && selectedSet.isNotEmpty) {
            for (final option in varItem.options) {
              if (option.isActive && selectedSet.contains(option.id)) {
                optionalAdditions += option.additionalPrice;
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
                total += option.price;
              }
            }
          }
        }
      }
      return total;
    }
  }
}

