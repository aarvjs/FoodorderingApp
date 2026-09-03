import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/quantity_selector.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/state_providers.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../models/cart_item.dart';
import '../../models/food_item.dart';
import '../home/providers/restaurant_providers.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  final String foodId;

  const ProductDetailsScreen({
    super.key,
    required this.restaurantId,
    required this.foodId,
  });

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _quantity = 1;
  final TextEditingController _instructionController = TextEditingController();

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Find restaurant and food item dynamically via streams
    final restDetailsAsync = ref.watch(restaurantDetailsStreamProvider(widget.restaurantId));
    final restMenuAsync = ref.watch(restaurantMenuStreamProvider(widget.restaurantId));

    final restaurant = restDetailsAsync.value;
    final dynamicMenu = (restMenuAsync.value != null && restMenuAsync.value!.isNotEmpty)
        ? restMenuAsync.value!
        : (restaurant?.items ?? []);

    final foodItem = dynamicMenu.firstWhere(
      (f) => f.id == widget.foodId,
      orElse: () => dynamicMenu.isNotEmpty
          ? dynamicMenu.first
          : FoodItem(
              id: widget.foodId,
              name: 'Food Item',
              description: '',
              imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500&q=80',
              price: 0.0,
              rating: 4.5,
              reviewCount: 10,
              isVeg: true,
              ingredients: const [],
              nutrition: const {},
              reviews: const [],
              category: '',
            ),
    );
    
    // Watch cart notifier
    final cartNotifier = ref.read(cartProvider.notifier);

    // Calculate real item price from database
    final double finalPrice = (foodItem.discountPrice != null && foodItem.discountPrice! > 0)
        ? foodItem.discountPrice!
        : foodItem.price;

    return Scaffold(
      body: Stack(
        children: [
          // Scrollable view
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image and Back/Favorite Actions
                Stack(
                  children: [
                    Hero(
                      tag: 'food_image_${foodItem.id}',
                      child: Image.network(
                        foodItem.imageUrl,
                        width: double.infinity,
                        height: 320,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Ambient bottom shadows
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.4)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Back Trigger
                    Positioned(
                      top: 50,
                      left: 16,
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.4),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          onPressed: () => context.pop(),
                        ),
                      ),
                    ),
                    // Veg/Non-veg Flag Overlay
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: foodItem.isVeg ? Colors.green : Colors.red,
                              size: 14,
                            ),
                            const Gap(6),
                            Text(
                              foodItem.isVeg ? 'VEGETARIAN' : 'NON-VEG',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Info Details Container
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  foodItem.name,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : AppColors.textDark,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const Gap(6),
                                Row(
                                  children: [
                                    Text(
                                      '₹${finalPrice.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                      ),
                                    ),
                                    if (foodItem.discountPrice != null &&
                                        foodItem.discountPrice! > 0 &&
                                        foodItem.price > foodItem.discountPrice!) ...[
                                      const Gap(8),
                                      Text(
                                        '₹${foodItem.price.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          decoration: TextDecoration.lineThrough,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.orange, size: 16),
                                const Gap(4),
                                Text(
                                  '${foodItem.rating}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(6),
                      Text(
                        'from ${restaurant?.name ?? 'Restaurant'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                      ),
                      if (foodItem.description.isNotEmpty) ...[
                        const Gap(16),
                        Text(
                          foodItem.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                            height: 1.5,
                          ),
                        ),
                      ],

                      const Gap(24),
                      const Divider(),
                      const Gap(16),

                      // Add Custom Instructions
                      Text(
                        'Custom Cooking Notes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      const Gap(12),
                      TextField(
                        controller: _instructionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Make it extra spicy, no onions, etc...',
                          hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 13),
                          fillColor: isDark ? AppColors.darkCard : Colors.grey.shade50,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Place Cart CTA bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                border: Border(
                  top: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.divider),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: Row(
                children: [
                  // Quantity adjustment
                  QuantitySelector(
                    quantity: _quantity,
                    onChanged: (newVal) {
                      if (newVal > 0) {
                        setState(() {
                          _quantity = newVal;
                        });
                      }
                    },
                    width: 105,
                    height: 48,
                  ),
                  const Gap(16),
                  
                  // Add Button
                  Expanded(
                    child: CustomButton(
                      text: 'Add to Cart • ₹${(finalPrice * _quantity).toStringAsFixed(0)}',
                      height: 48,
                      onPressed: () {
                        final String targetBranchId = (restaurant?.branchId.isNotEmpty == true)
                            ? restaurant!.branchId
                            : (restaurant?.id.isNotEmpty == true ? restaurant!.id : widget.restaurantId);
                        final String targetRestId = (restaurant?.restaurantId.isNotEmpty == true)
                            ? restaurant!.restaurantId
                            : targetBranchId;

                        final newItem = CartItem(
                          foodItem: foodItem.copyWith(price: finalPrice),
                          quantity: _quantity,
                          unitPrice: finalPrice,
                          selectedSize: null,
                          customInstructions: _instructionController.text.trim().isEmpty 
                              ? null 
                              : _instructionController.text.trim(),
                          restaurantId: targetRestId,
                          branchId: targetBranchId,
                          restaurantName: restaurant?.name ?? 'Restaurant',
                        );

                        void doAdd() {
                          cartNotifier.addItem(newItem);
                          TopToast.show(context, '${foodItem.name} added to cart');
                          context.pop();
                        }

                        if (cartNotifier.isDifferentRestaurant(targetRestId, branchId: targetBranchId)) {
                          final currentRestName = ref.read(cartProvider).items.first.restaurantName;
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Replace cart items?', style: TextStyle(fontWeight: FontWeight.bold)),
                              content: Text(
                                'Your cart contains items from $currentRestName. Do you want to discard your selection and add items from ${restaurant?.name ?? 'this outlet'}?',
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
                                    TopToast.show(context, '${foodItem.name} added to cart');
                                    context.pop();
                                  },
                                  child: const Text('Yes, Replace'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          doAdd();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
