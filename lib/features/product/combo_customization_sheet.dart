import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/state_providers.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../models/cart_item.dart';
import '../../models/combo_model.dart';
import '../../models/combo_item_model.dart';
import '../../models/food_item.dart';
import '../home/providers/restaurant_providers.dart';

class ComboProductCustomizationSheet extends ConsumerStatefulWidget {
  final ComboItemModel item;
  final ComboModel combo;
  final String restaurantId;
  final String? branchId;
  final String restaurantName;

  const ComboProductCustomizationSheet({
    super.key,
    required this.item,
    required this.combo,
    required this.restaurantId,
    this.branchId,
    required this.restaurantName,
  });

  @override
  ConsumerState<ComboProductCustomizationSheet> createState() =>
      _ComboProductCustomizationSheetState();
}

class _ComboProductCustomizationSheetState
    extends ConsumerState<ComboProductCustomizationSheet> {
  int _quantity = 1;

  // Selected option IDs per group: groupId -> Set of option IDs
  final Map<String, Set<String>> _selectedOptions = {};

  @override
  void initState() {
    super.initState();
    _initDefaults(widget.item);
  }

  void _initDefaults(ComboItemModel currentItem) {
    for (final group in currentItem.customizationGroups) {
      if (!_selectedOptions.containsKey(group.id)) {
        _selectedOptions[group.id] = <String>{};
        if (group.isRequired && group.options.isNotEmpty) {
          _selectedOptions[group.id]!.add(group.options.first.id);
        }
      }
    }
  }

  double _calculateUnitPrice(ComboItemModel currentItem) {
    double total = currentItem.price;

    for (final group in currentItem.customizationGroups) {
      final selectedSet = _selectedOptions[group.id] ?? <String>{};
      for (final option in group.options) {
        if (selectedSet.contains(option.id)) {
          total += option.price;
        }
      }
    }

    return total;
  }

  void _toggleOption(ComboCustomizationGroupModel group, ComboCustomizationOptionModel option) {
    setState(() {
      final currentSet = _selectedOptions[group.id] ?? <String>{};

      if (group.selectionType == 'SINGLE') {
        // Single selection radio behaviour
        if (group.isRequired) {
          _selectedOptions[group.id] = {option.id};
        } else {
          if (currentSet.contains(option.id)) {
            _selectedOptions[group.id] = <String>{};
          } else {
            _selectedOptions[group.id] = {option.id};
          }
        }
      } else {
        // Multiple selection checkbox behaviour
        final newSet = Set<String>.from(currentSet);
        if (newSet.contains(option.id)) {
          if (!group.isRequired || newSet.length > group.minSelection) {
            newSet.remove(option.id);
          }
        } else {
          if (newSet.length < group.maxSelection) {
            newSet.add(option.id);
          }
        }
        _selectedOptions[group.id] = newSet;
      }
    });
  }

  List<String> _buildSelectedCustomizationSummaries(ComboItemModel currentItem) {
    final List<String> summaries = [];

    for (final group in currentItem.customizationGroups) {
      final selectedSet = _selectedOptions[group.id] ?? <String>{};
      for (final option in group.options) {
        if (selectedSet.contains(option.id)) {
          if (option.price > 0) {
            summaries.add('${group.name}: ${option.name} (+₹${option.price.toStringAsFixed(0)})');
          } else {
            summaries.add('${group.name}: ${option.name}');
          }
        }
      }
    }

    return summaries;
  }

  bool _validateRequiredGroups(BuildContext context, ComboItemModel currentItem) {
    for (final group in currentItem.customizationGroups) {
      final selectedSet = _selectedOptions[group.id] ?? <String>{};
      if (group.isRequired && selectedSet.length < group.minSelection) {
        AppSnackbar.show(
          context,
          'Please make a selection for "${group.name}".',
          backgroundColor: Colors.red.shade700,
        );
        return false;
      }
    }
    return true;
  }

  List<ComboCustomizationSelection> _buildSelectedCustomizationObjects(ComboItemModel currentItem) {
    final List<ComboCustomizationSelection> list = [];

    for (final group in currentItem.customizationGroups) {
      final selectedSet = _selectedOptions[group.id] ?? <String>{};
      for (final option in group.options) {
        if (selectedSet.contains(option.id)) {
          list.add(ComboCustomizationSelection(
            groupName: group.name,
            optionId: option.id,
            optionName: option.name,
            additionalPrice: option.price,
          ));
        }
      }
    }

    return list;
  }

  void _handleAddToCart(ComboItemModel currentItem) {
    if (!_validateRequiredGroups(context, currentItem)) return;

    final unitPrice = _calculateUnitPrice(currentItem);
    final customizations = _buildSelectedCustomizationSummaries(currentItem);
    final customizationObjects = _buildSelectedCustomizationObjects(currentItem);

    final foodItem = FoodItem(
      id: currentItem.id,
      name: '${widget.combo.name} - ${currentItem.name}',
      description: currentItem.description,
      price: currentItem.price,
      imageUrl: currentItem.image,
      rating: currentItem.rating,
      reviewCount: currentItem.ratingCount,
      isVeg: currentItem.isVeg,
      ingredients: const [],
      nutrition: const {},
      reviews: const [],
      category: 'Combos',
      isAvailable: true,
      restaurantId: widget.restaurantId,
      branchId: (widget.branchId != null && widget.branchId!.isNotEmpty)
          ? widget.branchId
          : widget.restaurantId,
    );

    final String targetBranchId = (widget.branchId != null && widget.branchId!.isNotEmpty)
        ? widget.branchId!
        : widget.restaurantId;

    final cartItem = CartItem(
      foodItem: foodItem,
      quantity: _quantity,
      restaurantId: widget.restaurantId,
      branchId: targetBranchId,
      restaurantName: widget.restaurantName,
      isCombo: true,
      comboId: widget.combo.id,
      comboName: widget.combo.name,
      comboItemId: currentItem.id,
      basePrice: currentItem.price,
      unitPrice: unitPrice,
      selectedCustomizations: customizations,
      customizationSelections: customizationObjects,
    );

    ref.read(cartProvider.notifier).addItem(cartItem);

    Navigator.of(context).pop();

    TopToast.show(
      context,
      'Added "${currentItem.name}" with customizations to cart!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Real-time live Firestore stream for this specific combo item document
    final liveItemAsync = ref.watch(singleComboItemStreamProvider(widget.item.id));
    final ComboItemModel item = liveItemAsync.value ?? widget.item;

    _initDefaults(item);

    final unitPrice = _calculateUnitPrice(item);
    final totalPrice = unitPrice * _quantity;
    final groups = item.customizationGroups;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const Gap(10),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const Gap(12),

          // Scrollable Customization Content
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // Product Header Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Veg/NonVeg Indicator + Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.isVeg ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: item.isVeg ? Colors.green.shade600 : Colors.red.shade600,
                                  ),
                                ),
                                child: Text(
                                  item.foodType.isNotEmpty
                                      ? item.foodType
                                      : (item.isVeg ? 'Veg' : 'Non Veg'),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: item.isVeg ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                              ),
                              const Gap(8),
                              Text(
                                widget.combo.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const Gap(6),
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                          if (item.description.isNotEmpty) ...[
                            const Gap(4),
                            Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                height: 1.3,
                              ),
                            ),
                          ],
                          const Gap(6),
                          Text(
                            'Base Price: ₹${item.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Gap(14),

                    // Thumbnail Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        item.image,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 76,
                          height: 76,
                          color: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.fastfood, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),

                const Gap(16),
                const Divider(),
                const Gap(10),

                // Real-time Loading Indicator
                if (liveItemAsync.isLoading && groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),

                // Customization Groups
                if (!liveItemAsync.isLoading && groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Standard combo item (Included as is)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  )
                else
                  ...groups.map((group) {
                    final isSingle = group.selectionType == 'SINGLE';
                    final selectedSet = _selectedOptions[group.id] ?? <String>{};

                    return Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group Title & Rule Badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                group.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : AppColors.textDark,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: group.isRequired
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  group.isRequired
                                      ? (isSingle ? 'REQUIRED • SELECT 1' : 'REQUIRED')
                                      : (isSingle ? 'OPTIONAL • CHOOSE 1' : 'OPTIONAL (UP TO ${group.maxSelection})'),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: group.isRequired ? AppColors.primary : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Gap(10),

                          // Option Items inside Group
                          ...group.options.map((option) {
                            final isSelected = selectedSet.contains(option.id);

                            return InkWell(
                              onTap: () => _toggleOption(group, option),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                child: Row(
                                  children: [
                                    // Radio / Checkbox Icon
                                    Icon(
                                      isSingle
                                          ? (isSelected
                                              ? Icons.radio_button_checked_rounded
                                              : Icons.radio_button_off_rounded)
                                          : (isSelected
                                              ? Icons.check_box_rounded
                                              : Icons.check_box_outline_blank_rounded),
                                      size: 20,
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                                    ),
                                    const Gap(10),

                                    // Option Name
                                    Expanded(
                                      child: Text(
                                        option.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                          color: isSelected
                                              ? (isDark ? Colors.white : AppColors.textDark)
                                              : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                                        ),
                                      ),
                                    ),

                                    // Option Additional Price
                                    Text(
                                      option.price > 0
                                          ? '+₹${option.price.toStringAsFixed(0)}'
                                          : 'Free',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: option.price > 0
                                            ? AppColors.primary
                                            : const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),

                const Gap(20),
              ],
            ),
          ),

          // Bottom Action Bar with Dynamic Live Price
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Quantity Counter
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        Text(
                          '$_quantity',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ),

                  const Gap(14),

                  // Add to Cart Button with Calculated Dynamic Price
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleAddToCart(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.shopping_bag, size: 18),
                          const Gap(8),
                          Text(
                            'Add to Cart  •  ₹${totalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
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
