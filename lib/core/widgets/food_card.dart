import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/food_item.dart';
import '../../models/cart_item.dart';
import '../config/app_colors.dart';
import '../services/state_providers.dart';
import '../utils/snackbar_utils.dart';
import 'quantity_selector.dart';

class FoodCard extends ConsumerWidget {
  final FoodItem foodItem;
  final String restaurantId;
  final String restaurantName;
  final VoidCallback onTap;

  const FoodCard({
    super.key,
    required this.foodItem,
    required this.restaurantId,
    required this.restaurantName,
    required this.onTap,
  });

  void _onAddItem(BuildContext context, WidgetRef ref) {
    final cartState = ref.read(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    final newItem = CartItem(
      foodItem: foodItem,
      quantity: 1,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );

    void showSnackbar() {
      AppSnackbar.show(
        context,
        '${foodItem.name} added to cart!',
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.orange,
          onPressed: () {
            AppSnackbar.clear(context);
            context.push('/cart');
          },
        ),
      );
    }

    if (cartNotifier.isDifferentRestaurant(restaurantId)) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Replace cart items?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Your cart contains items from ${cartState.items.first.restaurantName}. Do you want to discard your selection and add items from $restaurantName?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                cartNotifier.forceAddItem(newItem);
                showSnackbar();
              },
              child: const Text('Yes, Replace'),
            ),
          ],
        ),
      );
    } else {
      cartNotifier.addItem(newItem);
      showSnackbar();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Check if item is already in cart
    final cartState = ref.watch(cartProvider);
    final cartItemIndex = cartState.items.indexWhere(
      (item) => item.foodItem.id == foodItem.id,
    );
    final inCartQty = cartItemIndex >= 0 ? cartState.items[cartItemIndex].quantity : 0;
    
    final cartNotifier = ref.read(cartProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Details side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Veg/Non Veg Indicator
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: foodItem.isVeg ? Colors.green : Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      if (foodItem.rating > 4.2)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.star, color: Colors.orange, size: 10),
                              SizedBox(width: 2),
                              Text(
                                'Bestseller',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    foodItem.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${foodItem.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    foodItem.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Image + Add Button Stack
            Column(
              children: [
                Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // Dish Image
                    Hero(
                      tag: 'food_image_${foodItem.id}',
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(foodItem.imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    // Add Button or Quantity Selector
                    Positioned(
                      bottom: -15,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: inCartQty == 0
                            ? GestureDetector(
                                onTap: () => _onAddItem(context, ref),
                                child: Container(
                                  width: 80,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkCard : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'ADD',
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.add,
                                        size: 14,
                                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : QuantitySelector(
                                quantity: inCartQty,
                                width: 85,
                                height: 34,
                                onChanged: (newQty) {
                                  cartNotifier.updateQuantity(foodItem.id, newQty);
                                },
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15), // Cushion spacer for overlay
              ],
            ),
          ],
        ),
      ),
    );
  }
}
