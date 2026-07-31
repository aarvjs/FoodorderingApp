import 'food_item.dart';

class CartItem {
  final FoodItem foodItem;
  final int quantity;
  final String? selectedSize;
  final String? customInstructions;
  final String restaurantId;
  final String restaurantName;

  const CartItem({
    required this.foodItem,
    required this.quantity,
    this.selectedSize,
    this.customInstructions,
    required this.restaurantId,
    required this.restaurantName,
  });

  CartItem copyWith({
    FoodItem? foodItem,
    int? quantity,
    String? selectedSize,
    String? customInstructions,
    String? restaurantId,
    String? restaurantName,
  }) {
    return CartItem(
      foodItem: foodItem ?? this.foodItem,
      quantity: quantity ?? this.quantity,
      selectedSize: selectedSize ?? this.selectedSize,
      customInstructions: customInstructions ?? this.customInstructions,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
    );
  }
}
