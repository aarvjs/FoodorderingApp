import 'food_item.dart';

class CartItem {
  final FoodItem foodItem;
  final int quantity;
  final String? selectedSize;
  final String? customInstructions;
  final String restaurantId;
  final String restaurantName;

  // Combo & Customization Extensions
  final bool isCombo;
  final String? comboId;
  final double unitPrice;
  final List<String> removedItems;
  final List<String> replacements;
  final List<String> selectedAddons;
  final List<String> selectedCustomizations;

  const CartItem({
    required this.foodItem,
    required this.quantity,
    this.selectedSize,
    this.customInstructions,
    required this.restaurantId,
    required this.restaurantName,
    this.isCombo = false,
    this.comboId,
    required this.unitPrice,
    this.removedItems = const [],
    this.replacements = const [],
    this.selectedAddons = const [],
    this.selectedCustomizations = const [],
  });

  double get totalPrice => unitPrice * quantity;

  CartItem copyWith({
    FoodItem? foodItem,
    int? quantity,
    String? selectedSize,
    String? customInstructions,
    String? restaurantId,
    String? restaurantName,
    bool? isCombo,
    String? comboId,
    double? unitPrice,
    List<String>? removedItems,
    List<String>? replacements,
    List<String>? selectedAddons,
    List<String>? selectedCustomizations,
  }) {
    return CartItem(
      foodItem: foodItem ?? this.foodItem,
      quantity: quantity ?? this.quantity,
      selectedSize: selectedSize ?? this.selectedSize,
      customInstructions: customInstructions ?? this.customInstructions,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      isCombo: isCombo ?? this.isCombo,
      comboId: comboId ?? this.comboId,
      unitPrice: unitPrice ?? this.unitPrice,
      removedItems: removedItems ?? this.removedItems,
      replacements: replacements ?? this.replacements,
      selectedAddons: selectedAddons ?? this.selectedAddons,
      selectedCustomizations: selectedCustomizations ?? this.selectedCustomizations,
    );
  }
}
