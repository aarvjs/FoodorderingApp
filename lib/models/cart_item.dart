import 'food_item.dart';

class ComboCustomizationSelection {
  final String groupName;
  final String optionId;
  final String optionName;
  final double additionalPrice;
  final double basePrice;
  final double extraPrice;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? productId;
  final String? comboId;
  final String? variantId;

  const ComboCustomizationSelection({
    required this.groupName,
    required this.optionId,
    required this.optionName,
    required this.additionalPrice,
    this.basePrice = 0.0,
    this.extraPrice = 0.0,
    this.quantity = 1,
    double? unitPrice,
    double? subtotal,
    this.productId,
    this.comboId,
    this.variantId,
  })  : unitPrice = unitPrice ?? (extraPrice > 0 ? extraPrice : additionalPrice),
        subtotal = subtotal ?? ((unitPrice ?? (extraPrice > 0 ? extraPrice : additionalPrice)) * (quantity > 0 ? quantity : 1));

  Map<String, dynamic> toMap() => {
        'groupName': groupName,
        'optionId': optionId,
        'optionName': optionName,
        'additionalPrice': additionalPrice,
        'basePrice': basePrice,
        'extraPrice': extraPrice,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'subtotal': subtotal,
        if (productId != null) 'productId': productId,
        if (comboId != null) 'comboId': comboId,
        if (variantId != null) 'variantId': variantId,
      };

  factory ComboCustomizationSelection.fromMap(Map<String, dynamic> data) {
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

    final qVal = data['quantity'] ?? data['qty'] ?? 1;
    final int qty = (qVal is num) ? qVal.toInt() : 1;

    final calcUnitPrice = basePrice + extraPrice;
    final uPriceVal = data['unitPrice'] ?? (calcUnitPrice > 0 ? calcUnitPrice : price);
    final double unitPrice = (uPriceVal is num)
        ? uPriceVal.toDouble()
        : double.tryParse(uPriceVal?.toString() ?? '0.0') ?? (calcUnitPrice > 0 ? calcUnitPrice : price);

    final subVal = data['subtotal'] ?? (unitPrice * qty);
    final double subtotal = (subVal is num)
        ? subVal.toDouble()
        : double.tryParse(subVal?.toString() ?? '0.0') ?? (unitPrice * qty);

    return ComboCustomizationSelection(
      groupName: (data['groupName'] ?? data['group'] ?? 'Option').toString(),
      optionId: (data['optionId'] ?? data['id'] ?? '').toString(),
      optionName: (data['optionName'] ?? data['name'] ?? '').toString(),
      additionalPrice: price,
      basePrice: basePrice,
      extraPrice: extraPrice,
      quantity: qty > 0 ? qty : 1,
      unitPrice: unitPrice,
      subtotal: subtotal,
      productId: data['productId']?.toString(),
      comboId: data['comboId']?.toString(),
      variantId: data['variantId']?.toString(),
    );
  }
}

class CartItem {
  final FoodItem foodItem;
  final int quantity;
  final String? selectedSize;
  final String? customInstructions;
  final String restaurantId;
  final String branchId;
  final String restaurantName;
  final DateTime addedAt;

  // Combo & Customization Extensions
  final bool isCombo;
  final String? comboId;
  final String? comboName;
  final String? comboItemId;
  final double basePrice;
  final double unitPrice;
  final List<String> removedItems;
  final List<String> replacements;
  final List<String> selectedAddons;
  final List<String> selectedCustomizations;
  final List<ComboCustomizationSelection> customizationSelections;

  CartItem({
    required this.foodItem,
    required this.quantity,
    this.selectedSize,
    this.customInstructions,
    required this.restaurantId,
    String? branchId,
    required this.restaurantName,
    DateTime? addedAt,
    this.isCombo = false,
    this.comboId,
    this.comboName,
    this.comboItemId,
    this.basePrice = 0.0,
    required this.unitPrice,
    this.removedItems = const [],
    this.replacements = const [],
    this.selectedAddons = const [],
    this.selectedCustomizations = const [],
    this.customizationSelections = const [],
  })  : branchId = (branchId != null && branchId.isNotEmpty) ? branchId : restaurantId,
        addedAt = addedAt ?? DateTime.now();

  /// 5-Hour Cart Expiry Check
  bool get isExpired {
    final ageMs = DateTime.now().difference(addedAt).inMilliseconds;
    return ageMs >= (5 * 3600 * 1000); // 5 hours in milliseconds
  }

  double get displayBasePrice => basePrice > 0 ? basePrice : foodItem.price;

  double get totalPrice => unitPrice * quantity;

  double get addonsTotalPrice {
    if (customizationSelections.isNotEmpty) {
      return customizationSelections.fold(0.0, (sum, c) => sum + c.subtotal);
    }
    final diff = unitPrice - displayBasePrice;
    return diff > 0 ? diff : 0.0;
  }

  String get cartKey {
    final sizeStr = selectedSize ?? '';
    final cId = comboId ?? '';
    final customsStr = selectedCustomizations.join('_');
    final remStr = removedItems.join('_');
    final replStr = replacements.join('_');
    final addonsStr = selectedAddons.join('_');
    final selStr = customizationSelections
        .map((s) {
          final optId = s.optionId.isNotEmpty ? s.optionId : s.optionName;
          final varId = s.variantId ?? '';
          final prodId = s.productId ?? '';
          return '${s.groupName}:$optId:$varId:$prodId:${s.quantity}:${s.unitPrice}';
        })
        .join('_');
    final noteStr = customInstructions ?? '';
    return '${foodItem.id}_${isCombo}_${cId}_${sizeStr}_${customsStr}_${remStr}_${replStr}_${addonsStr}_${selStr}_$noteStr';
  }

  CartItem copyWith({
    FoodItem? foodItem,
    int? quantity,
    String? selectedSize,
    String? customInstructions,
    String? restaurantId,
    String? branchId,
    String? restaurantName,
    DateTime? addedAt,
    bool? isCombo,
    String? comboId,
    String? comboName,
    String? comboItemId,
    double? basePrice,
    double? unitPrice,
    List<String>? removedItems,
    List<String>? replacements,
    List<String>? selectedAddons,
    List<String>? selectedCustomizations,
    List<ComboCustomizationSelection>? customizationSelections,
  }) {
    return CartItem(
      foodItem: foodItem ?? this.foodItem,
      quantity: quantity ?? this.quantity,
      selectedSize: selectedSize ?? this.selectedSize,
      customInstructions: customInstructions ?? this.customInstructions,
      restaurantId: restaurantId ?? this.restaurantId,
      branchId: branchId ?? this.branchId,
      restaurantName: restaurantName ?? this.restaurantName,
      addedAt: addedAt ?? this.addedAt,
      isCombo: isCombo ?? this.isCombo,
      comboId: comboId ?? this.comboId,
      comboName: comboName ?? this.comboName,
      comboItemId: comboItemId ?? this.comboItemId,
      basePrice: basePrice ?? this.basePrice,
      unitPrice: unitPrice ?? this.unitPrice,
      removedItems: removedItems ?? this.removedItems,
      replacements: replacements ?? this.replacements,
      selectedAddons: selectedAddons ?? this.selectedAddons,
      selectedCustomizations: selectedCustomizations ?? this.selectedCustomizations,
      customizationSelections: customizationSelections ?? this.customizationSelections,
    );
  }
}
