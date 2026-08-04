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
import '../address/widgets/address_selection_bottom_sheet.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _couponController = TextEditingController();
  String _selectedInstruction = '';

  final List<Map<String, dynamic>> _deliveryInstructions = [
    {'icon': Iconsax.notification, 'label': 'Avoid ringing bell'},
    {'icon': Iconsax.shield_security, 'label': 'Leave at gate'},
    {'icon': Iconsax.call, 'label': 'Avoid calling'},
    {'icon': Iconsax.house, 'label': 'Leave with security'},
  ];

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  void _applyCouponCode() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    
    final success = await ref.read(cartProvider.notifier).applyCoupon(code);
    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Coupon "$code" applied successfully!'), backgroundColor: AppColors.success),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid coupon code.'), backgroundColor: AppColors.error),
      );
    }
    _couponController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

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
                  // Itemized List Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
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
                                           Text(
                                             item.foodItem.name,
                                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                                    cartNotifier.updateQuantity(item.foodItem.id, newQty);
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

                  // Promo Coupon Code Input
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkDivider : Colors.grey.shade100),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Iconsax.ticket_discount, color: AppColors.accent, size: 22),
                            const Gap(10),
                            Text(
                              cartState.appliedCoupon != null
                                  ? 'Coupon "${cartState.appliedCoupon}" Applied'
                                  : 'Apply Promo Coupon',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (cartState.appliedCoupon != null) ...[
                              const Spacer(),
                              GestureDetector(
                                onTap: () => cartNotifier.removeCoupon(),
                                child: const Icon(Icons.cancel, color: AppColors.error, size: 20),
                              ),
                            ],
                          ],
                        ),
                        if (cartState.appliedCoupon == null) ...[
                          const Gap(12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _couponController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'Enter WELCOME50 or BINGE20',
                                    fillColor: isDark ? AppColors.darkBackground : Colors.grey.shade50,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),
                              const Gap(12),
                              ElevatedButton(
                                onPressed: _applyCouponCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                                  foregroundColor: isDark ? AppColors.textDark : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                ),
                                child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ] else ...[
                          const Gap(6),
                          Text(
                            'Saving ₹${cartState.couponDiscount.toStringAsFixed(0)} on this order!',
                            style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Gap(20),

                  // Delivery Instructions
                  Text(
                    'Delivery Instructions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const Gap(12),
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _deliveryInstructions.length,
                      itemBuilder: (context, index) {
                        final instruction = _deliveryInstructions[index];
                        final isSel = _selectedInstruction == instruction['label'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedInstruction = isSel ? '' : instruction['label'] as String;
                            });
                          },
                          child: Container(
                            width: 130,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(10),
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  instruction['icon'] as IconData,
                                  size: 18,
                                  color: isSel 
                                      ? (isDark ? AppColors.textDark : Colors.white) 
                                      : (isDark ? AppColors.darkPrimary : AppColors.primary),
                                ),
                                const Gap(6),
                                Text(
                                  instruction['label'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSel 
                                        ? (isDark ? AppColors.textDark : Colors.white) 
                                        : (isDark ? Colors.white : AppColors.textDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Gap(24),

                  // Bill Details Summary Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
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
                        _buildBillRow(
                          'Delivery Charges', 
                          cartState.deliveryFee == 0 ? 'FREE' : '₹${cartState.deliveryFee.toStringAsFixed(2)}', 
                          isDark,
                          isFree: cartState.deliveryFee == 0,
                        ),
                        _buildBillRow('Govt Taxes & GST (5%)', '₹${cartState.gstTax.toStringAsFixed(2)}', isDark),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Grand Total',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                            Text(
                              '₹${cartState.total}',
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
                          '₹${cartState.total}',
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
                        text: 'Proceed to Pay',
                        height: 48,
                        onPressed: () {
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
