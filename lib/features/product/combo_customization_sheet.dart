import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/state_providers.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../models/cart_item.dart';
import '../../models/combo_model.dart';
import '../../models/food_item.dart';

class ComboCustomizationSheet extends ConsumerStatefulWidget {
  final ComboModel combo;
  final String restaurantId;
  final String restaurantName;

  const ComboCustomizationSheet({
    super.key,
    required this.combo,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  ConsumerState<ComboCustomizationSheet> createState() => _ComboCustomizationSheetState();
}

class _ComboCustomizationSheetState extends ConsumerState<ComboCustomizationSheet> {
  int _quantity = 1;

  // Track item removal states
  late Map<String, bool> _removedItemMap;

  // Track item replacement choices: productId -> selected ReplacementItem
  late Map<String, ComboReplacementItem?> _replacementMap;

  // Track selected add-on option IDs
  final Set<String> _selectedAddonIds = {};

  @override
  void initState() {
    super.initState();
    _removedItemMap = {
      for (var item in widget.combo.items) item.productId: false
    };

    _replacementMap = {
      for (var item in widget.combo.items) item.productId: null
    };
  }

  double _calculateUnitPrice() {
    double price = widget.combo.price;

    // Apply removal deductions
    for (var item in widget.combo.items) {
      if (_removedItemMap[item.productId] == true) {
        price -= item.priceDeductionOnRemoval;
      } else {
        // Apply replacement extra charge if replaced
        final replacement = _replacementMap[item.productId];
        if (replacement != null) {
          price += replacement.extraPrice;
        }
      }
    }

    // Apply add-ons
    for (var group in widget.combo.addonGroups) {
      for (var opt in group.options) {
        if (_selectedAddonIds.contains(opt.id)) {
          price += opt.price;
        }
      }
    }

    return price > 0 ? price : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unitPrice = _calculateUnitPrice();
    final totalPrice = unitPrice * _quantity;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),

          // Title & Base Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.combo.image,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 70,
                    height: 70,
                    color: AppColors.primary.withOpacity(0.1),
                    child: const Icon(Icons.fastfood, color: AppColors.primary),
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.combo.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      widget.combo.description,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(6),
                    Text(
                      'Base Price: ₹${widget.combo.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Gap(16),
          const Divider(),

          // Scrollable Customization Content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Included Items Section
                  const Text(
                    'Included Items (Customize / Replace)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const Gap(8),

                  ...widget.combo.items.map((item) {
                    final isRemoved = _removedItemMap[item.productId] ?? false;
                    final selectedReplacement = _replacementMap[item.productId];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isRemoved
                            ? Colors.red.withOpacity(0.05)
                            : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.06)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRemoved
                              ? Colors.red.withOpacity(0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isRemoved ? Icons.remove_circle : Icons.check_circle,
                                color: isRemoved ? Colors.red : AppColors.success,
                                size: 20,
                              ),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    decoration: isRemoved ? TextDecoration.lineThrough : null,
                                    color: isRemoved ? Colors.red : (isDark ? Colors.white : AppColors.textPrimary),
                                  ),
                                ),
                              ),

                              // Remove Switch if allowed
                              if (item.canRemove) ...[
                                Text(
                                  isRemoved ? 'Removed' : 'Remove',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isRemoved ? Colors.red : AppColors.textSecondary,
                                  ),
                                ),
                                Checkbox(
                                  value: isRemoved,
                                  activeColor: Colors.red,
                                  onChanged: (val) {
                                    setState(() {
                                      _removedItemMap[item.productId] = val ?? false;
                                      if (val == true) {
                                        _replacementMap[item.productId] = null;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),

                          // Replacements list if not removed and replacements exist
                          if (!isRemoved && item.allowedReplacements.isNotEmpty) ...[
                            const Gap(8),
                            const Text(
                              'Replace item with:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            const Gap(4),

                            Wrap(
                              spacing: 8,
                              children: [
                                // Default choice
                                ChoiceChip(
                                  label: Text('Original (${item.productName})'),
                                  selected: selectedReplacement == null,
                                  selectedColor: AppColors.primary.withOpacity(0.2),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _replacementMap[item.productId] = null;
                                      });
                                    }
                                  },
                                ),
                                ...item.allowedReplacements.map((rep) {
                                  final isSelected = selectedReplacement?.productId == rep.productId;
                                  final priceTag = rep.extraPrice > 0 ? ' (+₹${rep.extraPrice.toStringAsFixed(0)})' : ' (Free)';
                                  return ChoiceChip(
                                    label: Text('${rep.productName}$priceTag'),
                                    selected: isSelected,
                                    selectedColor: AppColors.primary.withOpacity(0.2),
                                    onSelected: (selected) {
                                      setState(() {
                                        _replacementMap[item.productId] = selected ? rep : null;
                                      });
                                    },
                                  );
                                }),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  // 2. Combo Add-ons & Customization Groups Section
                  if (widget.combo.addonGroups.isNotEmpty) ...[
                    const Gap(16),
                    const Text(
                      'Customizations & Add-ons',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Gap(8),

                    ...widget.combo.addonGroups.map((group) {
                      final isSingle = group.type == 'single';
                      final groupOptions = group.options;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: group.isRequired && groupOptions.every((o) => !_selectedAddonIds.contains(o.id))
                                ? Colors.amber.withOpacity(0.5)
                                : (isDark ? AppColors.darkDivider : Colors.grey.shade200),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  group.title,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                if (group.isRequired)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'REQUIRED',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                    ),
                                  )
                                else
                                  Text(
                                    isSingle ? 'Choose 1' : (group.maxSelection > 0 ? 'Choose up to ${group.maxSelection}' : 'Optional'),
                                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                            const Gap(8),

                            ...groupOptions.map((opt) {
                              final isSelected = _selectedAddonIds.contains(opt.id);
                              final priceStr = opt.price > 0 ? '+₹${opt.price.toStringAsFixed(0)}' : 'FREE';

                              if (isSingle) {
                                return RadioListTile<String>(
                                  value: opt.id,
                                  groupValue: groupOptions.firstWhere((o) => _selectedAddonIds.contains(o.id), orElse: () => ComboAddonOption(id: '', name: '', price: 0, isAvailable: true)).id,
                                  title: Text(opt.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: Text(priceStr, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                  activeColor: AppColors.primary,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        for (var o in groupOptions) {
                                          _selectedAddonIds.remove(o.id);
                                        }
                                        _selectedAddonIds.add(val);
                                      });
                                    }
                                  },
                                );
                              } else {
                                return CheckboxListTile(
                                  value: isSelected,
                                  title: Text(opt.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: Text(priceStr, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                  activeColor: AppColors.primary,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        final currentSelectedInGroup = groupOptions.where((o) => _selectedAddonIds.contains(o.id)).length;
                                        if (group.maxSelection > 0 && currentSelectedInGroup >= group.maxSelection) {
                                          TopToast.show(context, 'Maximum ${group.maxSelection} selections allowed for ${group.title}');
                                          return;
                                        }
                                        _selectedAddonIds.add(opt.id);
                                      } else {
                                        _selectedAddonIds.remove(opt.id);
                                      }
                                    });
                                  },
                                );
                              }
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),

          const Gap(16),
          const Divider(),
          const Gap(12),

          // Total Price & Add to Cart Button
          Row(
            children: [
              // Quantity selector
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppColors.primary,
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  ),
                  Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),

              const Spacer(),

              // Add to Cart Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  // Validate required groups
                  for (var group in widget.combo.addonGroups) {
                    final selectedInGroup = group.options.where((o) => _selectedAddonIds.contains(o.id));
                    if (group.isRequired && selectedInGroup.isEmpty) {
                      TopToast.show(context, 'Please select an option for "${group.title}"');
                      return;
                    }
                    if (group.minSelection > 0 && selectedInGroup.length < group.minSelection) {
                      TopToast.show(context, 'Please select at least ${group.minSelection} option(s) for "${group.title}"');
                      return;
                    }
                  }

                  // Build summary strings
                  final List<String> removed = [];
                  final List<String> reps = [];
                  final List<String> addons = [];
                  final List<String> customList = [];

                  for (var item in widget.combo.items) {
                    if (_removedItemMap[item.productId] == true) {
                      removed.add(item.productName);
                      customList.add('Removed: ${item.productName}');
                    } else {
                      final rep = _replacementMap[item.productId];
                      if (rep != null) {
                        final extraText = rep.extraPrice > 0 ? ' (+₹${rep.extraPrice.toStringAsFixed(0)})' : '';
                        reps.add('${item.productName} -> ${rep.productName}$extraText');
                        customList.add('Replaced: ${item.productName} with ${rep.productName}');
                      }
                    }
                  }

                  for (var group in widget.combo.addonGroups) {
                    for (var opt in group.options) {
                      if (_selectedAddonIds.contains(opt.id)) {
                        final extraText = opt.price > 0 ? ' (+₹${opt.price.toStringAsFixed(0)})' : '';
                        addons.add('${opt.name}$extraText');
                        customList.add('${group.title}: ${opt.name}');
                      }
                    }
                  }

                  final foodItem = FoodItem(
                    id: widget.combo.id,
                    name: widget.combo.name,
                    description: widget.combo.description,
                    imageUrl: widget.combo.image,
                    price: unitPrice,
                    rating: 4.8,
                    reviewCount: 25,
                    isVeg: true,
                    ingredients: const [],
                    nutrition: const {},
                    reviews: const [],
                    category: 'Combos',
                  );

                  final cartItem = CartItem(
                    foodItem: foodItem,
                    quantity: _quantity,
                    restaurantId: widget.restaurantId,
                    restaurantName: widget.restaurantName,
                    isCombo: true,
                    comboId: widget.combo.id,
                    unitPrice: unitPrice,
                    removedItems: removed,
                    replacements: reps,
                    selectedAddons: addons,
                    selectedCustomizations: customList,
                  );

                  ref.read(cartProvider.notifier).addItem(cartItem);
                  Navigator.of(context).pop();

                  TopToast.show(
                    context,
                    '${widget.combo.name} added to cart!',
                  );
                },
                child: Text(
                  'Add to Cart • ₹${totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
