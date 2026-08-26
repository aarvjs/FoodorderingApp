import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/quantity_selector.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/state_providers.dart';
import '../../core/services/delivery_charge_service.dart';
import '../address/widgets/address_selection_bottom_sheet.dart';

import '../rewards/repositories/reward_repository.dart';
import 'widgets/coupon_selection_bottom_sheet.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _couponController = TextEditingController();

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  void _applyCouponCode() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    
    final result = await ref.read(cartProvider.notifier).applyCoupon(code);
    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const Gap(8),
              Expanded(child: Text(result.message, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const Gap(8),
              Expanded(child: Text(result.message, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _couponController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final userPointsAsync = ref.watch(userRewardPointsStreamProvider);
    final userAvailablePoints = userPointsAsync.value ?? 0;

    final deliveryCalcAsync = ref.watch(deliveryChargeCalculationProvider);
    final deliveryCalcResult = deliveryCalcAsync.value;
    final double effectiveDeliveryFee = cartState.isTakeAway ? 0.0 : (deliveryCalcResult?.deliveryFee ?? cartState.deliveryFee);
    final double taxPercentage = deliveryCalcResult?.taxPercentage ?? 0.0;
    final double taxableAmount = (cartState.subtotal - cartState.couponDiscount - cartState.rewardDiscount).clamp(0.0, double.infinity);
    final double effectiveGstAmount = taxPercentage > 0 ? double.parse((taxableAmount * (taxPercentage / 100.0)).toStringAsFixed(2)) : 0.0;
    final double calculatedTotal = (cartState.subtotal - cartState.couponDiscount - cartState.rewardDiscount + effectiveDeliveryFee + effectiveGstAmount).clamp(0.0, double.infinity);
    final double effectiveGrandTotal = double.parse(calculatedTotal.toStringAsFixed(2));
    final bool isOutsideRadius = !cartState.isTakeAway && (deliveryCalcResult?.isOutsideRadius == true);




    // If empty state
    if (cartState.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your Cart')),
        body: EmptyState(
          title: 'Your cart is empty',
          description: 'Looks like you haven\'t added anything to your cart yet. Go ahead and explore top dishes nearby!',
          fallbackIcon: Iconsax.shopping_cart,
          actionText: 'Browse Restaurants',
          onActionPressed: () => context.go('/home'),
        ),
      );
    }

    final restaurantId = cartState.items.first.restaurantId;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Your Cart', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Ordering from ${cartState.items.first.restaurantName}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.trash, color: AppColors.error, size: 20),
            onPressed: () {
              cartNotifier.clearCart();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cart cleared.')),
              );
            },
          ),
          const Gap(10),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable list
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120, left: 16, right: 16, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Type Selection Segment (Delivery vs Take Away)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => cartNotifier.setOrderType('DELIVERY'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !cartState.isTakeAway
                                    ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Iconsax.truck_fast,
                                    size: 18,
                                    color: !cartState.isTakeAway
                                        ? (isDark ? AppColors.textDark : Colors.white)
                                        : (isDark ? Colors.grey.shade400 : AppColors.textLight),
                                  ),
                                  const Gap(8),
                                  Text(
                                    'Delivery',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: !cartState.isTakeAway
                                          ? (isDark ? AppColors.textDark : Colors.white)
                                          : (isDark ? Colors.grey.shade400 : AppColors.textDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => cartNotifier.setOrderType('TAKE_AWAY'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: cartState.isTakeAway
                                    ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Iconsax.bag_2,
                                    size: 18,
                                    color: cartState.isTakeAway
                                        ? (isDark ? AppColors.textDark : Colors.white)
                                        : (isDark ? Colors.grey.shade400 : AppColors.textLight),
                                  ),
                                  const Gap(8),
                                  Text(
                                    'Take Away',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: cartState.isTakeAway
                                          ? (isDark ? AppColors.textDark : Colors.white)
                                          : (isDark ? Colors.grey.shade400 : AppColors.textDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (cartState.isTakeAway) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Iconsax.shop, color: Colors.amber.shade900, size: 22),
                          const Gap(10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Self Pickup Order (Take Away)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  'You will pick up this order directly at ${cartState.items.first.restaurantName}. No delivery charges apply.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Itemized List Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cartState.items.length,
                          separatorBuilder: (context, index) => const Divider(height: 24),
                          itemBuilder: (context, index) {
                            final item = cartState.items[index];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tiny Veg Indicator + Item Info
                                Icon(
                                  Icons.circle,
                                  color: item.foodItem.isVeg ? Colors.green : Colors.red,
                                  size: 14,
                                ),
                                const Gap(8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       Row(
                                         children: [
                                           Expanded(
                                             child: Text(
                                               item.foodItem.name,
                                               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                               maxLines: 2,
                                               overflow: TextOverflow.ellipsis,
                                             ),
                                           ),
                                           if (item.isCombo) ...[
                                             const Gap(6),
                                             Container(
                                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                               decoration: BoxDecoration(
                                                 color: Colors.amber.shade100,
                                                 borderRadius: BorderRadius.circular(6),
                                               ),
                                               child: Text(
                                                 'COMBO',
                                                 style: TextStyle(
                                                   fontSize: 9,
                                                   fontWeight: FontWeight.w900,
                                                   color: Colors.amber.shade900,
                                                 ),
                                               ),
                                             ),
                                           ],
                                         ],
                                       ),

                                       // Combo Breakdown Details
                                       if (item.removedItems.isNotEmpty)
                                         Padding(
                                           padding: const EdgeInsets.only(top: 2),
                                           child: Text(
                                             'Removed: ${item.removedItems.join(", ")}',
                                             style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500),
                                           ),
                                         ),

                                       if (item.replacements.isNotEmpty)
                                         Padding(
                                           padding: const EdgeInsets.only(top: 2),
                                           child: Text(
                                             'Replacements: ${item.replacements.join(", ")}',
                                             style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w600),
                                           ),
                                         ),

                                       if (item.selectedAddons.isNotEmpty)
                                         Padding(
                                           padding: const EdgeInsets.only(top: 2),
                                           child: Text(
                                             'Add-ons: ${item.selectedAddons.join(", ")}',
                                             style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                                           ),
                                         ),

                                       if (item.selectedCustomizations.isNotEmpty)
                                         Padding(
                                           padding: const EdgeInsets.only(top: 3),
                                           child: Column(
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: item.selectedCustomizations
                                                 .map((cust) => Padding(
                                                       padding: const EdgeInsets.only(bottom: 1.5),
                                                       child: Text(
                                                         '• $cust',
                                                         style: TextStyle(
                                                           fontSize: 11,
                                                           fontWeight: FontWeight.w600,
                                                           color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                                                         ),
                                                       ),
                                                     ))
                                                 .toList(),
                                           ),
                                         ),

                                       if (item.selectedSize != null)
                                         Text(
                                           'Size: ${item.selectedSize}',
                                           style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                         ),
                                       if (item.customInstructions != null)
                                         Text(
                                           'Note: "${item.customInstructions}"',
                                           style: const TextStyle(
                                             fontSize: 12,
                                             color: Colors.orange,
                                             fontStyle: FontStyle.italic,
                                           ),
                                         ),
                                       const Gap(4),
                                       Text(
                                         '₹${item.unitPrice.toStringAsFixed(0)}',
                                         style: TextStyle(
                                           fontWeight: FontWeight.w800,
                                           color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                         ),
                                       ),
                                    ],
                                  ),
                                ),
                                // Quantity Selector
                                 QuantitySelector(
                                   quantity: item.quantity,
                                   width: 80,
                                   height: 32,
                                   onChanged: (newQty) {
                                     cartNotifier.updateQuantityAtIndex(index, newQty);
                                   },
                                 ),
                              ],
                            );
                          },
                        ),
                        
                        const Gap(16),
                        const Divider(),
                        const Gap(12),
                        
                        // Add More Items row
                        GestureDetector(
                          onTap: () => context.push('/restaurant/$restaurantId'),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.add_circle, size: 18, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                              const Gap(6),
                              Text(
                                'Add more items',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(20),

                  // Restaurant-Specific Coupon Section
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: cartState.appliedCoupon != null
                            ? AppColors.success.withValues(alpha: 0.5)
                            : (isDark ? AppColors.darkDivider : Colors.grey.shade100),
                        width: cartState.appliedCoupon != null ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cartState.appliedCoupon != null
                              ? AppColors.success.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: cartState.appliedCoupon != null
                                    ? AppColors.success.withValues(alpha: 0.12)
                                    : AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Iconsax.ticket_discount,
                                color: cartState.appliedCoupon != null ? AppColors.success : AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const Gap(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cartState.appliedCoupon != null ? 'Coupon Applied' : 'Offers & Coupons',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    cartState.appliedCoupon != null
                                        ? 'Saving ₹${cartState.couponDiscount.toStringAsFixed(0)} on this order!'
                                        : 'Select restaurant coupon or enter promo code',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: cartState.appliedCoupon != null
                                          ? AppColors.success
                                          : (isDark ? Colors.grey.shade400 : AppColors.textLight),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (cartState.appliedCoupon != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
                                    Gap(4),
                                    Text(
                                      'Applied',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        if (cartState.appliedCoupon == null) ...[
                          const Gap(14),
                          // Select Coupon Dropdown Button
                          InkWell(
                            onTap: () {
                              CouponSelectionBottomSheet.show(
                                context,
                                restaurantId: restaurantId,
                                restaurantName: cartState.items.first.restaurantName,
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkBackground : Colors.orange.shade50.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Iconsax.discount_shape, color: AppColors.primary, size: 20),
                                  const Gap(10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Select Coupon ▼',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: AppColors.primary,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        Text(
                                          'Tap to view and apply available coupons',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Gap(12),
                          // Manual Code Entry
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkBackground : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _couponController,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter coupon code (e.g. FLAT20)',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      isDense: true,
                                    ),
                                    onSubmitted: (_) => _applyCouponCode(),
                                  ),
                                ),
                              ),
                              const Gap(10),
                              ElevatedButton(
                                onPressed: _applyCouponCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                                  foregroundColor: isDark ? AppColors.textDark : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  elevation: 0,
                                ),
                                child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                        ] else ...[
                          const Gap(12),
                          // Applied Coupon Details Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBackground : Colors.green.shade50.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.black38 : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.success.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    cartState.appliedCoupon!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 0.8,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                                const Gap(10),
                                Expanded(
                                  child: Text(
                                    'Discount: ₹${cartState.couponDiscount.toStringAsFixed(0)} OFF',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    CouponSelectionBottomSheet.show(
                                      context,
                                      restaurantId: restaurantId,
                                      restaurantName: cartState.items.first.restaurantName,
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    foregroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  child: const Text('Change ▼'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    cartNotifier.removeCoupon();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Coupon removed.'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    foregroundColor: AppColors.error,
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Gap(16),

                  // Reward Points Integration Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: cartState.appliedRewardPoints > 0
                            ? const Color(0xFFF59E0B)
                            : (isDark ? AppColors.darkDivider : Colors.grey.shade100),
                        width: cartState.appliedRewardPoints > 0 ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cartState.appliedRewardPoints > 0
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF3C7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Iconsax.award5,
                                color: Color(0xFFD97706),
                                size: 18,
                              ),
                            ),
                            const Gap(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Use Reward Points',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    userAvailablePoints > 0
                                        ? 'Available: $userAvailablePoints Pts • Max Value: ₹${(userAvailablePoints * cartState.pointValue).toStringAsFixed(2)}'
                                        : 'No reward points available currently',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (userAvailablePoints > 0) ...[
                              if (cartState.appliedRewardPoints > 0)
                                TextButton(
                                  onPressed: () {
                                    cartNotifier.removeRewardPoints();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Reward points removed.'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  child: const Text('Remove'),
                                )
                              else
                                ElevatedButton(
                                  onPressed: () async {
                                    final branchId = cartState.items.first.branchId.isNotEmpty
                                        ? cartState.items.first.branchId
                                        : cartState.items.first.restaurantId;
                                    final config = await ref
                                        .read(rewardRepositoryProvider)
                                        .getRewardConfigByBranch(branchId, cartState.items.first.restaurantId);
                                    final pVal = config?.pointValue ?? 0.25;

                                    cartNotifier.applyRewardPoints(userAvailablePoints, pVal);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('🎉 Applied $userAvailablePoints reward points! Saved ₹${cartState.rewardDiscount.toStringAsFixed(2)}'),
                                          backgroundColor: const Color(0xFF16A34A),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    elevation: 0,
                                  ),
                                  child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                            ],
                          ],
                        ),

                        if (cartState.appliedRewardPoints > 0) ...[
                          const Gap(10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFFD97706), size: 14),
                                const Gap(6),
                                Expanded(
                                  child: Text(
                                    'Applied ${cartState.appliedRewardPoints} Points • Saved ₹${cartState.rewardDiscount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Gap(20),

                  // Bill Details Summary Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bill Details',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Gap(16),
                        _buildBillRow('Item Subtotal', '₹${cartState.subtotal.toStringAsFixed(2)}', isDark),
                        if (cartState.couponDiscount > 0)
                          _buildBillRow(
                            'Coupon Discount', 
                            '- ₹${cartState.couponDiscount.toStringAsFixed(2)}', 
                            isDark,
                            isDiscount: true,
                          ),
                        if (cartState.rewardDiscount > 0)
                          _buildBillRow(
                            'Reward Points Discount (${cartState.appliedRewardPoints} Pts)', 
                            '- ₹${cartState.rewardDiscount.toStringAsFixed(2)}', 
                            isDark,
                            isDiscount: true,
                          ),
                        _buildBillRow(
                          deliveryCalcAsync.value?.distanceKm != null && deliveryCalcAsync.value!.distanceKm > 0
                              ? 'Delivery Charges (${deliveryCalcAsync.value!.distanceKm.toStringAsFixed(1)} km)'
                              : 'Delivery Charges', 
                          effectiveDeliveryFee == 0 ? 'FREE' : '₹${effectiveDeliveryFee.toStringAsFixed(2)}', 
                          isDark,
                          isFree: effectiveDeliveryFee == 0,
                        ),
                        if (taxPercentage > 0 && effectiveGstAmount > 0)
                          _buildBillRow(
                            'Govt Taxes & GST (${taxPercentage.toStringAsFixed(taxPercentage.truncateToDouble() == taxPercentage ? 0 : 1)}%)',
                            '₹${effectiveGstAmount.toStringAsFixed(2)}',
                            isDark,
                          ),

                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Grand Total',

                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                            Text(
                              '₹${effectiveGrandTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900, 
                                fontSize: 18,
                                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (isOutsideRadius) ...[
                    const Gap(16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                          const Gap(10),
                          Expanded(
                            child: Text(
                              deliveryCalcAsync.value?.errorMessage ??
                                  'Delivery unavailable: Your address exceeds the maximum delivery radius for this restaurant branch.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                ],
              ),
            ),

            // Sticky Bottom CTA Bar
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
                ),
                child: Row(
                  children: [
                    // Grand Total Indicator
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'GRAND TOTAL',
                          style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '₹${effectiveGrandTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Gap(20),
                    // Checkout Button
                    Expanded(
                      child: CustomButton(
                        text: isOutsideRadius ? 'Outside Delivery Area' : 'Proceed to Pay',
                        height: 48,
                        onPressed: () {
                          if (isOutsideRadius) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  deliveryCalcResult?.errorMessage ??
                                      'Delivery unavailable: Your address is outside the maximum delivery radius for this restaurant.',
                                ),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          final addressState = ref.read(addressProvider);
                          final selectedAddr = addressState.selectedAddress;

                          if (selectedAddr == null || selectedAddr.formattedAddress.isEmpty || selectedAddr.latitude == 0.0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a delivery address.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const AddressSelectionBottomSheet(),
                            );
                            return;
                          }

                          context.push('/checkout');
                        },
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value, bool isDark, {bool isDiscount = false, bool isFree = false}) {
    Color valColor = isDark ? Colors.white : AppColors.textDark;
    if (isDiscount) valColor = AppColors.success;
    if (isFree) valColor = Colors.green;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valColor),
          ),
        ],
      ),
    );
  }
}
