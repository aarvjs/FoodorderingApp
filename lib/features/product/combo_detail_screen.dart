import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/state_providers.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../models/cart_item.dart';
import '../../models/combo_model.dart';
import '../../models/combo_item_model.dart';
import '../../models/food_item.dart';
import '../../models/restaurant.dart';
import '../home/providers/restaurant_providers.dart';
import 'combo_customization_sheet.dart';

class ComboDetailScreen extends ConsumerWidget {
  final ComboModel combo;
  final Restaurant? restaurant;

  const ComboDetailScreen({
    super.key,
    required this.combo,
    this.restaurant,
  });

  void _onAddItem(BuildContext context, WidgetRef ref, ComboItemModel item) {
    final groups = item.customizationGroups;
    if (groups.isNotEmpty || item.isCustomisable) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ComboProductCustomizationSheet(
          item: item,
          combo: combo,
          restaurantId: restaurant?.id ?? item.restaurantId,
          restaurantName: restaurant?.name ?? 'Restaurant',
        ),
      );
    } else {
      final foodItem = FoodItem(
        id: item.id,
        name: '${combo.name} - ${item.name}',
        description: item.description,
        price: item.price,
        imageUrl: item.image,
        isVeg: item.isVeg,
        rating: item.rating,
        reviewCount: item.ratingCount,
        ingredients: const [],
        nutrition: const {},
        reviews: const [],
        restaurantId: restaurant?.id ?? item.restaurantId,
        category: 'Combos',
        isAvailable: true,
      );

      final cartItem = CartItem(
        foodItem: foodItem,
        quantity: 1,
        restaurantId: restaurant?.id ?? item.restaurantId,
        restaurantName: restaurant?.name ?? 'Restaurant',
        isCombo: true,
        comboId: combo.id,
        comboName: combo.name,
        comboItemId: item.id,
        unitPrice: item.price,
      );

      ref.read(cartProvider.notifier).addItem(cartItem);

      TopToast.show(
        context,
        'Added "${item.name}" to cart!',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemsAsync = ref.watch(comboItemsStreamProvider(combo.id));
    final List<ComboItemModel> comboItems = itemsAsync.value ?? [];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Collapsible Image Header
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    combo.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Center(
                        child: Icon(Icons.fastfood, size: 64, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black54, Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Combo Header Info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant Name Tag
                  if (restaurant != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.shop, size: 13, color: AppColors.primary),
                          const Gap(6),
                          Text(
                            restaurant!.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),
                  ],

                  // Combo Name
                  Text(
                    combo.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textDark,
                      letterSpacing: -0.4,
                    ),
                  ),

                  // Description
                  if (combo.description.isNotEmpty) ...[
                    const Gap(6),
                    Text(
                      combo.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                        height: 1.4,
                      ),
                    ),
                  ],

                  const Gap(14),
                  const Divider(),
                  const Gap(10),

                  // Section Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        'Products / Items in this Combo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      const Spacer(),
                      if (comboItems.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${comboItems.length} Items',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey.shade300 : AppColors.textDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Items List Sliver
          SliverPadding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
            sliver: itemsAsync.isLoading && comboItems.isEmpty
                ? SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                          child: Container(
                            height: 110,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      childCount: 3,
                    ),
                  )
                : (comboItems.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.fastfood_outlined,
                                  size: 48,
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                ),
                                const Gap(12),
                                Text(
                                  'No items in this combo yet',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.textDark,
                                  ),
                                ),
                                const Gap(4),
                                Text(
                                  'Items created specifically for "${combo.name}" will appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = comboItems[index];

                            return Container(
                              key: ValueKey(item.id),
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Left Details Column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Veg / Non-Veg Indicator
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: item.isVeg ? Colors.green.shade50 : Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: item.isVeg ? Colors.green.shade600 : Colors.red.shade600,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.circle,
                                                    size: 7,
                                                    color: item.isVeg ? Colors.green.shade700 : Colors.red.shade700,
                                                  ),
                                                  const Gap(4),
                                                  Text(
                                                    item.foodType.isNotEmpty ? item.foodType : (item.isVeg ? 'Veg' : 'Non Veg'),
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: item.isVeg ? Colors.green.shade800 : Colors.red.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Gap(6),

                                            // Item Name
                                            Text(
                                              item.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: isDark ? Colors.white : AppColors.textDark,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            const Gap(4),

                                            // Short Description / Summary
                                            if (item.description.isNotEmpty) ...[
                                              Text(
                                                item.description,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF2563EB),
                                                  height: 1.3,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const Gap(6),
                                            ],

                                            // Price display & Rating
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (item.originalPrice != null && item.originalPrice! > item.price)
                                                  Text(
                                                    '₹${item.originalPrice!.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      decoration: TextDecoration.lineThrough,
                                                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                Text(
                                                  '₹${item.price.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                const Gap(4),
                                                // Star Rating
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFEAB308)),
                                                    const Gap(2),
                                                    Text(
                                                      '${item.rating.toStringAsFixed(1)} (${item.ratingCount})',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const Gap(12),

                                      // Right Image Thumbnail + ADD Button
                                      Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(14),
                                            child: Image.network(
                                              item.image,
                                              height: 80,
                                              width: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                height: 80,
                                                width: 80,
                                                color: AppColors.primary.withValues(alpha: 0.08),
                                                child: const Icon(Icons.fastfood, size: 28, color: AppColors.primary),
                                              ),
                                            ),
                                          ),
                                          const Gap(8),
                                          // Prominent ADD button
                                          ElevatedButton(
                                            onPressed: () => _onAddItem(context, ref, item),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                              minimumSize: const Size(80, 32),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              elevation: 1,
                                            ),
                                            child: const Text(
                                              'ADD',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          if (item.isCustomisable || item.customizationGroups.isNotEmpty) ...[
                                            const Gap(3),
                                            Text(
                                              'CUSTOMISABLE',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: comboItems.length,
                        ),
                      )),
          ),
        ],
      ),
    );
  }
}
