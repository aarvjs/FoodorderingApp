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

  // Selected Size Variant IDs (supports selecting multiple size variants!)
  final Set<String> _selectedVariantIds = {};

  // Active Variant ID currently being configured in the UI tab/editor
  String? _activeConfigVariantId;

  // Selected options map per Variant: variantId -> (varItemId -> Set of option IDs)
  final Map<String, Map<String, Set<String>>> _variantOptionsMap = {};

  // Selected option IDs in Standard Mode: groupId -> Set of option IDs
  final Map<String, Set<String>> _selectedGroupOptions = {};

  // Option Quantities map: key "${variantId}:${varItemId}:${optionId}" -> quantity
  final Map<String, int> _optionQuantities = {};

  @override
  void initState() {
    super.initState();
    _initDefaults(widget.item);
  }

  int _getOptionQuantity(String key, int minQty) {
    return 1;
  }

  List<ComboItemVariant> _getSelectedVariants(ComboItemModel currentItem) {
    if (!currentItem.isVariantEnabled || currentItem.variants.isEmpty) return [];
    return currentItem.variants.where((v) => _selectedVariantIds.contains(v.id)).toList();
  }

  void _ensureVariantOptionsInit(ComboItemVariant variant) {
    final varOptions = _variantOptionsMap.putIfAbsent(variant.id, () => <String, Set<String>>{});
    for (final varItem in variant.items) {
      if (!varItem.isActive) continue;
      if (!varOptions.containsKey(varItem.id)) {
        final targetSet = varOptions.putIfAbsent(varItem.id, () => <String>{});
        if (varItem.isRequired && varItem.options.isNotEmpty) {
          final isSingle = varItem.selectionType == 'SINGLE';
          if (isSingle) {
            final firstOpt = varItem.options.first;
            targetSet.add(firstOpt.id);
            _optionQuantities['${variant.id}:${varItem.id}:${firstOpt.id}'] = firstOpt.minQuantity > 0 ? firstOpt.minQuantity : 1;
          } else {
            final countToTake = varItem.minSelection > 0 ? varItem.minSelection : 1;
            final defaultOpts = varItem.options.take(countToTake);
            for (final opt in defaultOpts) {
              targetSet.add(opt.id);
              _optionQuantities['${variant.id}:${varItem.id}:${opt.id}'] = opt.minQuantity > 0 ? opt.minQuantity : 1;
            }
          }
        }
      }
    }
  }

  void _onToggleVariantSelection(ComboItemVariant variant, ComboItemModel currentItem) {
    setState(() {
      if (_selectedVariantIds.contains(variant.id)) {
        if (_selectedVariantIds.length > 1) {
          _selectedVariantIds.remove(variant.id);
          if (_activeConfigVariantId == variant.id) {
            final remaining = _getSelectedVariants(currentItem);
            _activeConfigVariantId = remaining.isNotEmpty ? remaining.first.id : null;
          }
        } else {
          AppSnackbar.show(
            context,
            'At least one size variant must be selected.',
            backgroundColor: Colors.amber.shade900,
          );
        }
      } else {
        _selectedVariantIds.add(variant.id);
        _activeConfigVariantId = variant.id;
        _ensureVariantOptionsInit(variant);
      }
    });
  }

  void _onSelectActiveConfigVariant(String variantId) {
    setState(() {
      _activeConfigVariantId = variantId;
    });
  }

  bool _initializedFromCart = false;

  void _initDefaults(ComboItemModel currentItem) {
    if (!_initializedFromCart) {
      final cartState = ref.read(cartProvider);
      final lastCartIndex = cartState.items.lastIndexWhere(
        (i) => i.isCombo &&
            (i.comboItemId == currentItem.id || i.foodItem.id == currentItem.id) &&
            (i.customizationSelections.isNotEmpty || i.selectedSize != null),
      );

      if (lastCartIndex >= 0) {
        final existingItem = cartState.items[lastCartIndex];
        if (existingItem.customizationSelections.isNotEmpty || existingItem.selectedSize != null) {
          if (currentItem.isVariantEnabled && currentItem.variants.isNotEmpty) {
            _selectedVariantIds.clear();
            _variantOptionsMap.clear();

            final sizeNames = existingItem.selectedSize?.split(',').map((s) => s.trim()).toList() ?? [];
            for (final variant in currentItem.variants) {
              final isMatch = sizeNames.contains(variant.name) ||
                  existingItem.customizationSelections.any((c) => c.variantId == variant.id || c.groupName.startsWith('${variant.name} -'));
              if (isMatch) {
                _selectedVariantIds.add(variant.id);
                _ensureVariantOptionsInit(variant);
              }
            }

            if (_selectedVariantIds.isEmpty) {
              _selectedVariantIds.add(currentItem.variants.first.id);
              _ensureVariantOptionsInit(currentItem.variants.first);
            }
            _activeConfigVariantId = _selectedVariantIds.first;

            for (final sel in existingItem.customizationSelections) {
              final vId = sel.variantId ?? _activeConfigVariantId;
              if (vId != null && _selectedVariantIds.contains(vId)) {
                final targetVariant = currentItem.variants.firstWhere((v) => v.id == vId, orElse: () => currentItem.variants.first);
                final varOptions = _variantOptionsMap.putIfAbsent(targetVariant.id, () => <String, Set<String>>{});
                for (final varItem in targetVariant.items) {
                  for (final opt in varItem.options) {
                    if (opt.id == sel.optionId || opt.name == sel.optionName) {
                      final set = varOptions.putIfAbsent(varItem.id, () => <String>{});
                      set.add(opt.id);
                    }
                  }
                }
              }
            }
          } else {
            _selectedGroupOptions.clear();
            for (final sel in existingItem.customizationSelections) {
              for (final group in currentItem.customizationGroups) {
                for (final opt in group.options) {
                  if (opt.id == sel.optionId || opt.name == sel.optionName) {
                    final set = _selectedGroupOptions.putIfAbsent(group.id, () => <String>{});
                    set.add(opt.id);
                  }
                }
              }
            }
          }

          _initializedFromCart = true;
          return;
        }
      }
    }

    if (currentItem.isVariantEnabled && currentItem.variants.isNotEmpty) {
      if (_selectedVariantIds.isEmpty) {
        final firstVar = currentItem.variants.first;
        _selectedVariantIds.add(firstVar.id);
        _activeConfigVariantId = firstVar.id;
        _ensureVariantOptionsInit(firstVar);
      } else {
        if (_activeConfigVariantId == null || !_selectedVariantIds.contains(_activeConfigVariantId)) {
          _activeConfigVariantId = _selectedVariantIds.first;
        }
        for (final vId in _selectedVariantIds) {
          final matched = currentItem.variants.firstWhere((v) => v.id == vId, orElse: () => currentItem.variants.first);
          _ensureVariantOptionsInit(matched);
        }
      }
    } else {
      for (final group in currentItem.customizationGroups) {
        final isSingle = group.selectionType == 'SINGLE';
        final isReq = group.isRequired && group.minSelection >= 1;

        if (!_selectedGroupOptions.containsKey(group.id)) {
          final targetSet = _selectedGroupOptions.putIfAbsent(group.id, () => <String>{});
          if (isReq && group.options.isNotEmpty) {
            final firstOpt = group.options.first;
            targetSet.add(firstOpt.id);
          }
        } else {
          final currentSet = _selectedGroupOptions[group.id] ?? <String>{};
          if (isSingle && currentSet.length > 1) {
            _selectedGroupOptions[group.id] = {currentSet.first};
          }
        }
      }
    }
    _initializedFromCart = true;
  }

  double _calculateUnitPrice(ComboItemModel currentItem) {
    if (currentItem.isVariantEnabled && _selectedVariantIds.isNotEmpty) {
      final selectedVars = _getSelectedVariants(currentItem);
      return ComboCalculator.calculateMultiVariantComboPrice(
        currentItem: currentItem,
        selectedVariants: selectedVars,
        variantOptionsMap: _variantOptionsMap,
        optionQuantities: _optionQuantities,
      );
    }
    return ComboCalculator.calculateComboFinalPrice(
      currentItem: currentItem,
      selectedGroupOptions: _selectedGroupOptions,
      optionQuantities: _optionQuantities,
    );
  }

  void _toggleVariantOption(ComboItemVariant variant, ComboVariantItem varItem, ComboVariantOption option) {
    setState(() {
      final varOptions = _variantOptionsMap.putIfAbsent(variant.id, () => <String, Set<String>>{});
      final currentSet = varOptions[varItem.id] ?? <String>{};
      final isSingle = varItem.selectionType == 'SINGLE';
      final isReq = varItem.isRequired && varItem.minSelection >= 1;
      final qKey = '${variant.id}:${varItem.id}:${option.id}';

      if (isSingle) {
        if (isReq) {
          varOptions[varItem.id] = {option.id};
          _optionQuantities[qKey] = option.minQuantity > 0 ? option.minQuantity : 1;
        } else {
          if (currentSet.contains(option.id)) {
            varOptions[varItem.id] = <String>{};
            _optionQuantities.remove(qKey);
          } else {
            varOptions[varItem.id] = {option.id};
            _optionQuantities[qKey] = option.minQuantity > 0 ? option.minQuantity : 1;
          }
        }
      } else {
        final newSet = Set<String>.from(currentSet);
        if (newSet.contains(option.id)) {
          if (!isReq || newSet.length > varItem.minSelection) {
            newSet.remove(option.id);
            _optionQuantities.remove(qKey);
          } else {
            AppSnackbar.show(
              context,
              'Please keep at least ${varItem.minSelection} option(s) selected for "${varItem.name}".',
              backgroundColor: Colors.amber.shade900,
            );
          }
        } else {
          if (newSet.length < varItem.maxSelection) {
            newSet.add(option.id);
            _optionQuantities[qKey] = option.minQuantity > 0 ? option.minQuantity : 1;
          } else {
            AppSnackbar.show(
              context,
              'You can select maximum ${varItem.maxSelection} option(s) for "${varItem.name}".',
              backgroundColor: Colors.amber.shade900,
            );
          }
        }
        varOptions[varItem.id] = newSet;
      }
    });
  }

  void _toggleGroupOption(ComboCustomizationGroupModel group, ComboCustomizationOptionModel option) {
    setState(() {
      final currentSet = _selectedGroupOptions[group.id] ?? <String>{};
      final isSingle = group.selectionType == 'SINGLE';
      final isReq = group.isRequired && group.minSelection >= 1;
      final qKey = '${group.id}:${option.id}';

      if (isSingle) {
        if (isReq) {
          _selectedGroupOptions[group.id] = {option.id};
          _optionQuantities[qKey] = option.minQuantity > 0 ? option.minQuantity : 1;
        } else {
          if (currentSet.contains(option.id)) {
            _selectedGroupOptions[group.id] = <String>{};
            _optionQuantities.remove(qKey);
          } else {
            _selectedGroupOptions[group.id] = {option.id};
            _optionQuantities[qKey] = option.minQuantity > 0 ? option.minQuantity : 1;
          }
        }
      } else {
        final newSet = Set<String>.from(currentSet);
        if (newSet.contains(option.id)) {
          if (!isReq || newSet.length > group.minSelection) {
            newSet.remove(option.id);
            _optionQuantities.remove(qKey);
          } else {
            AppSnackbar.show(
              context,
              'Please keep at least ${group.minSelection} option(s) selected for "${group.name}".',
              backgroundColor: Colors.amber.shade900,
            );
          }
        } else {
          if (newSet.length < group.maxSelection) {
            newSet.add(option.id);
            _optionQuantities[qKey] = option.minQuantity > 0 ? option.minQuantity : 1;
          } else {
            AppSnackbar.show(
              context,
              'You can select maximum ${group.maxSelection} option(s) for "${group.name}".',
              backgroundColor: Colors.amber.shade900,
            );
          }
        }
        _selectedGroupOptions[group.id] = newSet;
      }
    });
  }

  List<String> _buildSelectedCustomizationSummaries(ComboItemModel currentItem) {
    final List<String> summaries = [];

    if (currentItem.isVariantEnabled && _selectedVariantIds.isNotEmpty) {
      final selectedVars = _getSelectedVariants(currentItem);
      final isMulti = selectedVars.length > 1;

      for (final variant in selectedVars) {
        final varOptions = _variantOptionsMap[variant.id] ?? {};
        summaries.add('Size: ${variant.name}');

        for (final varItem in variant.items) {
          final selectedSet = varOptions[varItem.id] ?? <String>{};
          for (final option in varItem.options) {
            if (selectedSet.contains(option.id)) {
              final unitP = option.unitPrice;
              final prefix = isMulti ? '${variant.name} - ${varItem.name}' : varItem.name;
              if (unitP > 0) {
                summaries.add('$prefix: ${option.name} (+₹${unitP.toStringAsFixed(0)})');
              } else {
                summaries.add('$prefix: ${option.name}');
              }
            }
          }
        }
      }
    } else {
      for (final group in currentItem.customizationGroups) {
        final selectedSet = _selectedGroupOptions[group.id] ?? <String>{};
        for (final option in group.options) {
          if (selectedSet.contains(option.id)) {
            final unitP = option.unitPrice;
            if (unitP > 0) {
              summaries.add('${group.name}: ${option.name} (+₹${unitP.toStringAsFixed(0)})');
            } else {
              summaries.add('${group.name}: ${option.name}');
            }
          }
        }
      }
    }

    return summaries;
  }

  bool _validateRequiredSelections(BuildContext context, ComboItemModel currentItem) {
    if (currentItem.isVariantEnabled) {
      if (_selectedVariantIds.isEmpty) {
        AppSnackbar.show(
          context,
          'Please select at least one size variant.',
          backgroundColor: Colors.red.shade700,
        );
        return false;
      }
      final selectedVars = _getSelectedVariants(currentItem);
      for (final variant in selectedVars) {
        final varOptions = _variantOptionsMap[variant.id] ?? {};
        for (final varItem in variant.items) {
          if (!varItem.isActive) continue;
          final selectedSet = varOptions[varItem.id] ?? <String>{};
          if (varItem.isRequired && selectedSet.length < varItem.minSelection) {
            setState(() {
              _activeConfigVariantId = variant.id;
            });
            AppSnackbar.show(
              context,
              'Size "${variant.name}": Please select at least ${varItem.minSelection} option(s) for "${_cleanGroupName(varItem.name)}".',
              backgroundColor: Colors.red.shade700,
            );
            return false;
          }
          if (selectedSet.length > varItem.maxSelection) {
            setState(() {
              _activeConfigVariantId = variant.id;
            });
            AppSnackbar.show(
              context,
              'Size "${variant.name}": You can select maximum ${varItem.maxSelection} option(s) for "${_cleanGroupName(varItem.name)}".',
              backgroundColor: Colors.red.shade700,
            );
            return false;
          }
        }
      }
    } else {
      for (final group in currentItem.customizationGroups) {
        final selectedSet = _selectedGroupOptions[group.id] ?? <String>{};
        if (group.isRequired && selectedSet.length < group.minSelection) {
          AppSnackbar.show(
            context,
            'Please make a selection for "${group.name}".',
            backgroundColor: Colors.red.shade700,
          );
          return false;
        }
      }
    }
    return true;
  }

  List<ComboCustomizationSelection> _buildSelectedCustomizationObjects(ComboItemModel currentItem) {
    final List<ComboCustomizationSelection> list = [];

    if (currentItem.isVariantEnabled && _selectedVariantIds.isNotEmpty) {
      final selectedVars = _getSelectedVariants(currentItem);
      final isMulti = selectedVars.length > 1;

      for (final variant in selectedVars) {
        final varOptions = _variantOptionsMap[variant.id] ?? {};
        for (final varItem in variant.items) {
          if (!varItem.isActive) continue;
          final selectedSet = varOptions[varItem.id] ?? <String>{};
          for (final option in varItem.options) {
            if (selectedSet.contains(option.id)) {
              final unitP = option.unitPrice;
              final groupNameStr = isMulti ? '${variant.name} - ${varItem.name}' : varItem.name;
              list.add(ComboCustomizationSelection(
                groupName: groupNameStr,
                optionId: option.id,
                optionName: option.name,
                additionalPrice: option.additionalPrice,
                basePrice: option.basePrice,
                extraPrice: option.extraPrice,
                quantity: 1,
                unitPrice: unitP,
                subtotal: unitP,
                comboId: currentItem.comboId,
                variantId: variant.id,
              ));
            }
          }
        }
      }
    } else {
      for (final group in currentItem.customizationGroups) {
        final selectedSet = _selectedGroupOptions[group.id] ?? <String>{};
        for (final option in group.options) {
          if (selectedSet.contains(option.id)) {
            final unitP = option.unitPrice;
            list.add(ComboCustomizationSelection(
              groupName: group.name,
              optionId: option.id,
              optionName: option.name,
              additionalPrice: option.price,
              basePrice: option.basePrice,
              extraPrice: option.extraPrice,
              quantity: 1,
              unitPrice: unitP,
              subtotal: unitP,
              comboId: currentItem.comboId,
            ));
          }
        }
      }
    }

    return list;
  }

  void _handleProceedToCart(ComboItemModel currentItem) {
    if (!_validateRequiredSelections(context, currentItem)) return;

    final String targetBranchId = (widget.branchId != null && widget.branchId!.isNotEmpty)
        ? widget.branchId!
        : widget.restaurantId;

    final liveComboAsync = ref.read(singleComboStreamProvider(widget.combo.id));
    final liveCombo = liveComboAsync.value ?? widget.combo;

    if (!liveCombo.isCurrentlyAvailableForBranch(targetBranchId)) {
      AppSnackbar.show(
        context,
        'This combo deal is currently unavailable.',
        backgroundColor: Colors.red.shade900,
      );
      Navigator.of(context).pop();
      return;
    }

    if (!currentItem.isCurrentlyAvailableForBranch(targetBranchId)) {
      AppSnackbar.show(
        context,
        'This product inside the combo is currently unavailable.',
        backgroundColor: Colors.red.shade900,
      );
      return;
    }

    final unitPrice = _calculateUnitPrice(currentItem);
    final customizations = _buildSelectedCustomizationSummaries(currentItem);
    final customizationObjects = _buildSelectedCustomizationObjects(currentItem);

    final selectedVars = _getSelectedVariants(currentItem);
    final selectedSizeStr = currentItem.isVariantEnabled && selectedVars.isNotEmpty
        ? selectedVars.map((v) => v.name).join(', ')
        : null;

    final double calculatedBasePrice = currentItem.isVariantEnabled && selectedVars.isNotEmpty
        ? selectedVars.fold(0.0, (sum, v) => sum + ComboCalculator.calculateVariantBasePrice(v, _variantOptionsMap[v.id], _optionQuantities))
        : currentItem.price;

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

    final cartNotifier = ref.read(cartProvider.notifier);
    final cartState = ref.read(cartProvider);

    final existingIndex = cartState.items.indexWhere(
      (i) => i.isCombo && (i.comboItemId == currentItem.id || i.foodItem.id == currentItem.id),
    );

    if (existingIndex >= 0) {
      final existingItem = cartState.items[existingIndex];
      final updatedItem = existingItem.copyWith(
        foodItem: foodItem,
        selectedSize: selectedSizeStr,
        basePrice: calculatedBasePrice,
        unitPrice: unitPrice,
        selectedCustomizations: customizations,
        customizationSelections: customizationObjects,
        quantity: existingItem.quantity > 0 ? existingItem.quantity : 1,
      );
      cartNotifier.updateItemAtIndex(existingIndex, updatedItem);
    } else {
      final cartItem = CartItem(
        foodItem: foodItem,
        quantity: 1,
        selectedSize: selectedSizeStr,
        restaurantId: widget.restaurantId,
        branchId: targetBranchId,
        restaurantName: widget.restaurantName,
        isCombo: true,
        comboId: widget.combo.id,
        comboName: widget.combo.name,
        comboItemId: currentItem.id,
        basePrice: calculatedBasePrice,
        unitPrice: unitPrice,
        selectedCustomizations: customizations,
        customizationSelections: customizationObjects,
      );
      cartNotifier.addItem(cartItem);
    }

    Navigator.of(context).pop();

    final sizeInfo = selectedSizeStr != null ? ' ($selectedSizeStr)' : '';
    TopToast.show(
      context,
      'Saved "${currentItem.name}"$sizeInfo customization!',
    );
  }

  String _cleanGroupName(String rawName) {
    return rawName
        .replaceAll(RegExp(r'\s*REQUIRED\s*•?\s*SELECT\s*\d*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*REQUIRED\s*•?\s*CHOOSE\s*\d*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*REQUIRED\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*OPTIONAL\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+', caseSensitive: false), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Real-time live Firestore stream for this specific combo item document
    final liveItemAsync = ref.watch(singleComboItemStreamProvider(widget.item.id));
    final ComboItemModel item = liveItemAsync.value ?? widget.item;

    _initDefaults(item);

    final unitPrice = _calculateUnitPrice(item);

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
                          Builder(
                            builder: (context) {
                              if (item.isVariantEnabled && _selectedVariantIds.isNotEmpty) {
                                final selectedVars = _getSelectedVariants(item);
                                final totalBasePrice = selectedVars.fold(0.0, (sum, v) => sum + ComboCalculator.calculateVariantBasePrice(v, _variantOptionsMap[v.id], _optionQuantities));
                                final sizeNames = selectedVars.map((v) => v.name).join(' + ');
                                return Text(
                                  'Selected Sizes ($sizeNames): Base ₹${totalBasePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                );
                              } else {
                                return Text(
                                  'Base Price: ₹${item.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                );
                              }
                            },
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
                        errorBuilder: (context, error, stackTrace) => Container(
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
                if (liveItemAsync.isLoading && !item.isVariantEnabled && item.customizationGroups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),

                // -----------------------------------------------------
                // VARIANT CONFIGURATION MODE (isVariantEnabled == true)
                // -----------------------------------------------------
                if (item.isVariantEnabled && item.variants.isNotEmpty) ...[
                  // 1. Choose Size Selector (Multi-Select Supported)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Choose Sizes & Variants',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Select multiple',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const Gap(10),

                  SizedBox(
                    height: 46,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: item.variants.length,
                      itemBuilder: (context, vIdx) {
                        final variant = item.variants[vIdx];
                        final isIncluded = _selectedVariantIds.contains(variant.id);
                        final isActiveConfig = _activeConfigVariantId == variant.id;

                        return GestureDetector(
                          onTap: () {
                            _onToggleVariantSelection(variant, item);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isIncluded
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkBackground : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isIncluded
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkDivider : Colors.grey.shade300),
                                width: isIncluded ? 1.8 : 1.0,
                              ),
                              boxShadow: isIncluded
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isIncluded ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                  size: 18,
                                  color: isIncluded ? Colors.white : Colors.grey.shade500,
                                ),
                                const Gap(6),
                                Text(
                                  variant.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isIncluded ? FontWeight.w900 : FontWeight.w700,
                                    color: isIncluded
                                        ? Colors.white
                                        : (isDark ? Colors.grey.shade300 : AppColors.textDark),
                                  ),
                                ),
                                if (isActiveConfig && _selectedVariantIds.length > 1) ...[
                                  const Gap(4),
                                  const Icon(Icons.edit, size: 12, color: Colors.white70),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Gap(16),

                  // 2. Active Variant Configuration Switcher (if multiple selected)
                  if (_selectedVariantIds.length > 1) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 14, color: Colors.amber.shade900),
                              const Gap(6),
                              Text(
                                'Configure Options For:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const Gap(8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _getSelectedVariants(item).map((variant) {
                              final isSelectedConfig = _activeConfigVariantId == variant.id;
                              return ChoiceChip(
                                label: Text(
                                  variant.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelectedConfig ? Colors.white : (isDark ? Colors.grey.shade300 : AppColors.textDark),
                                  ),
                                ),
                                selected: isSelectedConfig,
                                selectedColor: AppColors.primary,
                                backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                                onSelected: (sel) {
                                  if (sel) {
                                    _onSelectActiveConfigVariant(variant.id);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                  ],

                  // 3. Items & Options belonging specifically to Active Selected Size Variant
                  Builder(
                    builder: (context) {
                      final selectedVars = _getSelectedVariants(item);
                      if (selectedVars.isEmpty) return const SizedBox.shrink();

                      final activeVariant = selectedVars.firstWhere(
                        (v) => v.id == _activeConfigVariantId,
                        orElse: () => selectedVars.first,
                      );

                      final varOptions = _variantOptionsMap[activeVariant.id] ?? {};

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedVariantIds.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Customizing ${activeVariant.name} Variant:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ...activeVariant.items.map((varItem) {
                            final selectedSet = varOptions[varItem.id] ?? <String>{};
                            final isSingle = varItem.selectionType == 'SINGLE';

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
                                  // Item Header inside Size
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _cleanGroupName(varItem.name),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: isDark ? Colors.white : AppColors.textDark,
                                                height: 1.25,
                                              ),
                                            ),
                                            if (varItem.description.isNotEmpty) ...[
                                              const Gap(2),
                                              Text(
                                                varItem.description,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const Gap(8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: varItem.isRequired
                                              ? AppColors.primary.withValues(alpha: 0.12)
                                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          varItem.isRequired
                                              ? (isSingle ? 'REQUIRED • CHOOSE 1' : 'REQUIRED (MIN ${varItem.minSelection})')
                                              : (isSingle ? 'OPTIONAL' : 'OPTIONAL (MAX ${varItem.maxSelection})'),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: varItem.isRequired ? AppColors.primary : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Gap(10),

                                  // Options inside Item
                                  if (varItem.options.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Text(
                                        'Standard item included',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                        ),
                                      ),
                                    )
                                  else
                                    ...varItem.options.map((option) {
                                      final isSelected = selectedSet.contains(option.id);
                                      final qKey = '${activeVariant.id}:${varItem.id}:${option.id}';
                                      final qty = _getOptionQuantity(qKey, option.minQuantity);
                                      final unitP = option.unitPrice;
                                      final subtotal = unitP * qty;

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primary.withValues(alpha: 0.06)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              InkWell(
                                                onTap: () => _toggleVariantOption(activeVariant, varItem, option),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
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
                                                  ],
                                                ),
                                              ),

                                              Expanded(
                                                child: InkWell(
                                                  onTap: () => _toggleVariantOption(activeVariant, varItem, option),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        option.name,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                                          color: isSelected
                                                              ? (isDark ? Colors.white : AppColors.textDark)
                                                              : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              Text(
                                                unitP > 0
                                                    ? '+₹${unitP.toStringAsFixed(0)}'
                                                    : 'Free',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: unitP > 0
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
                        ],
                      );
                    },
                  ),
                ] else ...[
                  // -----------------------------------------------------
                  // STANDARD CUSTOMIZATION GROUPS (isVariantEnabled == false)
                  // -----------------------------------------------------
                  if (!liveItemAsync.isLoading && item.customizationGroups.isEmpty)
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
                    ...item.customizationGroups.map((group) {
                      final isSingle = group.selectionType == 'SINGLE';
                      final selectedSet = _selectedGroupOptions[group.id] ?? <String>{};

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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    _cleanGroupName(group.name),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : AppColors.textDark,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                const Gap(8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: group.isRequired
                                        ? AppColors.primary.withValues(alpha: 0.12)
                                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    group.isRequired
                                        ? (isSingle ? 'REQUIRED • SELECT 1' : 'REQUIRED')
                                        : (isSingle ? 'OPTIONAL • CHOOSE 1' : 'OPTIONAL (UP TO ${group.maxSelection})'),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: group.isRequired ? AppColors.primary : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Gap(10),

                            ...group.options.map((option) {
                              final isSelected = selectedSet.contains(option.id);
                              final qKey = '${group.id}:${option.id}';
                              final qty = _getOptionQuantity(qKey, option.minQuantity);
                              final unitP = option.unitPrice;
                              final subtotal = unitP * qty;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withValues(alpha: 0.06)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () => _toggleGroupOption(group, option),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
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
                                          ],
                                        ),
                                      ),

                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _toggleGroupOption(group, option),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                option.name,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                                  color: isSelected
                                                      ? (isDark ? Colors.white : AppColors.textDark)
                                                      : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      Text(
                                        unitP > 0
                                            ? '+₹${unitP.toStringAsFixed(0)}'
                                            : 'Free',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: unitP > 0
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
                ],

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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleProceedToCart(item),
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
                        'Proceed to Cart  •  ₹${unitPrice.toStringAsFixed(0)}',
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
            ),
          ),
        ],
      ),
    );
  }
}
