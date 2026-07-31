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
  String _selectedSize = 'Medium';
  final List<String> _sizes = ['Regular', 'Medium', 'Large'];
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

    // Calculate price modifiers
    double finalPrice = foodItem.price;
    if (_selectedSize == 'Regular') finalPrice -= 20;
    if (_selectedSize == 'Large') finalPrice += 40;

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
                        children: [
                          Expanded(
                            child: Text(
                              foodItem.name,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppColors.textDark,
                                letterSpacing: -0.5,
                              ),
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
                      const Gap(4),
                      Text(
                        'from ${restaurant?.name ?? 'Restaurant'}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                      ),
                      const Gap(16),
                      
                      // Description
                      Text(
                        foodItem.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                          height: 1.5,
                        ),
                      ),

                      const Gap(24),
                      const Divider(),
                      const Gap(16),

                      // Size Selection Row
                      Text(
                        'Select Size',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      const Gap(12),
                      Row(
                        children: _sizes.map((size) {
                          final isSel = _selectedSize == size;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedSize = size;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                      : (isDark ? AppColors.darkCard : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel 
                                        ? Colors.transparent 
                                        : (isDark ? AppColors.darkDivider : Colors.grey.shade200),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    size,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSel
                                          ? (isDark ? AppColors.textDark : Colors.white)
                                          : (isDark ? Colors.white : AppColors.textDark),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const Gap(24),
                      const Divider(),
                      const Gap(16),

                      // Ingredients
                      Text(
                        'Ingredients',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      const Gap(12),
                      SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: foodItem.ingredients.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
                              ),
                              child: Text(
                                foodItem.ingredients[index],
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            );
                          },
                        ),
                      ),

                      const Gap(24),
                      const Divider(),
                      const Gap(16),

                      // Nutrition Grid
                      Text(
                        'Nutrition Facts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      const Gap(12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: foodItem.nutrition.length,
                        itemBuilder: (context, index) {
                          final key = foodItem.nutrition.keys.elementAt(index);
                          final val = foodItem.nutrition[key]!;
                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  val,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  key,
                                  style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

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
                        final newItem = CartItem(
                          foodItem: foodItem.copyWith(price: finalPrice),
                          quantity: _quantity,
                          selectedSize: _selectedSize,
                          customInstructions: _instructionController.text.trim().isEmpty 
                              ? null 
                              : _instructionController.text.trim(),
                          restaurantId: restaurant?.id ?? widget.restaurantId,
                          restaurantName: restaurant?.name ?? 'Restaurant',
                        );

                        void doAdd() {
                          cartNotifier.addItem(newItem);
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
                          context.pop();
                        }

                        final targetResId = restaurant?.id ?? widget.restaurantId;
                        if (cartNotifier.isDifferentRestaurant(targetResId)) {
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
