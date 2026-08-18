import 'food_item.dart';

class ComboCustomizationSelection {
  final String groupName;
  final String optionId;
  final String optionName;
  final double additionalPrice;

  const ComboCustomizationSelection({
    required this.groupName,
    required this.optionId,
    required this.optionName,
    required this.additionalPrice,
  });

  Map<String, dynamic> toMap() => {
        'groupName': groupName,
        'optionId': optionId,
        'optionName': optionName,
        'additionalPrice': additionalPrice,
      };

  factory ComboCustomizationSelection.fromMap(Map<String, dynamic> data) {
    final priceVal = data['additionalPrice'] ?? data['price'] ?? 0;
    final double price = (priceVal is num)
        ? priceVal.toDouble()
        : double.tryParse(priceVal?.toString() ?? '0.0') ?? 0.0;
    return ComboCustomizationSelection(
      groupName: (data['groupName'] ?? data['group'] ?? 'Option').toString(),
      optionId: (data['optionId'] ?? data['id'] ?? '').toString(),
      optionName: (data['optionName'] ?? data['name'] ?? '').toString(),
      additionalPrice: price,
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
  }) : branchId = (branchId != null && branchId.isNotEmpty) ? branchId : restaurantId;

  double get displayBasePrice => basePrice > 0 ? basePrice : foodItem.price;

  double get totalPrice => unitPrice * quantity;

  double get addonsTotalPrice {
    if (customizationSelections.isNotEmpty) {
      return customizationSelections.fold(0.0, (sum, c) => sum + c.additionalPrice);
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
        .map((s) => '${s.groupName}:${s.optionName}:${s.additionalPrice}')
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
