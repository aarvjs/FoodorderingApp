import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/state_providers.dart';
import '../../core/services/delivery_charge_service.dart';
import '../../models/address.dart';
import '../../auth/providers/auth_provider.dart';


class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedPaymentMethod = 'COD';
  String? _selectedAddressId;
  bool _isPlacingOrder = false;
  final TextEditingController _deliveryAddressController = TextEditingController();

  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'COD', 'name': 'Cash on Delivery (COD)', 'icon': Iconsax.wallet_3},
    {'id': 'UPI', 'name': 'UPI (Google Pay / PhonePe)', 'icon': Iconsax.mobile},
    {'id': 'Card', 'name': 'Credit or Debit Card', 'icon': Iconsax.card},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final addressState = ref.read(addressProvider);
      final addresses = addressState.addresses;
      if (addresses.isNotEmpty) {
        final defaultAddr = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
        setState(() {
          _selectedAddressId = defaultAddr.id;
          if (_deliveryAddressController.text.trim().isEmpty) {
            _deliveryAddressController.text = defaultAddr.fullAddress;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _deliveryAddressController.dispose();
    super.dispose();
  }

  void _showAddAddressSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelController = TextEditingController(text: 'Home');
    final lineController = TextEditingController();
    final landmarkController = TextEditingController();
    final zipController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add New Address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Address Label (e.g. Home, Office)'),
            ),
            const Gap(12),
            TextField(
              controller: lineController,
              decoration: const InputDecoration(labelText: 'Flat No, Building, Street Line'),
            ),
            const Gap(12),
            TextField(
              controller: landmarkController,
              decoration: const InputDecoration(labelText: 'Landmark / Area'),
            ),
            const Gap(12),
            TextField(
              controller: zipController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Zip / Pincode'),
            ),
            const Gap(20),
            CustomButton(
              text: 'Save Address',
              onPressed: () {
                if (lineController.text.trim().isEmpty || zipController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields.')),
                  );
                  return;
                }
                
                final newAddress = Address(
                  id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
                  label: labelController.text.trim(),
                  addressLine: lineController.text.trim(),
                  landmark: landmarkController.text.trim(),
                  city: 'Bengaluru',
                  state: 'Karnataka',
                  zipCode: zipController.text.trim(),
                  isDefault: false,
                );

                ref.read(addressProvider.notifier).addAddress(newAddress);
                setState(() {
                  _selectedAddressId = newAddress.id;
                  _deliveryAddressController.text = newAddress.fullAddress;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onPlaceOrder() async {
    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty) return;

    final manualAddress = _deliveryAddressController.text.trim();
    if (manualAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your complete delivery address.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final addressState = ref.read(addressProvider);
    Address? selectedAddr = addressState.selectedAddress;

    if (selectedAddr == null && addressState.addresses.isNotEmpty) {
      selectedAddr = addressState.addresses.firstWhere(
        (a) => a.id == _selectedAddressId,
        orElse: () => addressState.addresses.first,
      );
    }

    final double lat = selectedAddr?.latitude ?? 12.9716;
    final double lng = selectedAddr?.longitude ?? 77.5946;

    final authState = ref.read(authProvider);
    final customerId = authState.userModel?.uid ?? 'cust_guest_${DateTime.now().millisecondsSinceEpoch}';
    final String? rawName = authState.userModel?.fullName;
    final customerName = (rawName != null && rawName.isNotEmpty) ? rawName : 'Guest Customer';

    final String? rawPhone = authState.userModel?.phone;
    final customerPhone = (rawPhone != null && rawPhone.isNotEmpty) ? rawPhone : '+91 9876543210';


    final deliveryCalcAsync = ref.read(deliveryChargeCalculationProvider);
    final deliveryCalcResult = deliveryCalcAsync.value;
    if (deliveryCalcResult?.isOutsideRadius == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deliveryCalcResult?.errorMessage ??
                'Delivery unavailable: Your address exceeds the maximum delivery radius for this restaurant branch.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final double effectiveDeliveryFee = deliveryCalcResult?.deliveryFee ?? cartState.deliveryFee;
    final double effectiveDistanceKm = deliveryCalcResult?.distanceKm ?? 0.0;
    final double taxPercentage = deliveryCalcResult?.taxPercentage ?? 0.0;
    final double taxableAmount = (cartState.subtotal - cartState.couponDiscount).clamp(0.0, double.infinity);
    final double effectiveGstAmount = taxPercentage > 0 ? double.parse((taxableAmount * (taxPercentage / 100.0)).toStringAsFixed(2)) : 0.0;
    final double computedTotal = cartState.subtotal - cartState.couponDiscount + effectiveDeliveryFee + effectiveGstAmount;
    final double effectiveGrandTotal = double.parse(computedTotal.toStringAsFixed(2));

    final firstItem = cartState.items.first;
    final String restId = firstItem.restaurantId;
    final String branchId = firstItem.foodItem.branchId ?? restId;
    final String restName = firstItem.restaurantName;

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final createdOrder = await orderRepo.createOrder(
        restaurantId: restId,
        branchId: branchId,
        branchName: restName,
        restaurantName: restName,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: manualAddress,
        latitude: lat,
        longitude: lng,
        items: cartState.items,
        subtotal: cartState.subtotal,
        tax: effectiveGstAmount,
        taxPercentage: taxPercentage,
        deliveryFee: effectiveDeliveryFee,
        deliveryDistanceKm: effectiveDistanceKm,
        discount: cartState.couponDiscount,
        grandTotal: effectiveGrandTotal,
        paymentMethod: _selectedPaymentMethod,
        appliedCoupon: cartState.appliedCoupon,
        appliedOfferId: cartState.appliedOfferId,
      );



      // Create in-app notification document
      final notificationRepo = ref.read(notificationRepositoryProvider);
      await notificationRepo.createNotification(
        userId: customerId,
        orderId: createdOrder.id,
        title: 'Order Placed! 🛵',
        body: 'Your order #${createdOrder.orderNumber} for $restName has been placed successfully via Cash on Delivery.',
        type: 'delivery',
      );

      // Save order in Riverpod history
      ref.read(ordersProvider.notifier).placeOrder(createdOrder);

      // Clear user cart
      ref.read(cartProvider.notifier).clearCart();

      if (!mounted) return;

      setState(() {
        _isPlacingOrder = false;
      });

      // Go to success
      context.go('/order-success');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPlacingOrder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: ${e.toString()}'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addressState = ref.watch(addressProvider);
    final addresses = addressState.addresses;
    final cartState = ref.watch(cartProvider);

    final deliveryCalcAsync = ref.watch(deliveryChargeCalculationProvider);
    final deliveryCalcResult = deliveryCalcAsync.value;
    final double effectiveDeliveryFee = deliveryCalcResult?.deliveryFee ?? cartState.deliveryFee;
    final double taxPercentage = deliveryCalcResult?.taxPercentage ?? 0.0;
    final double taxableAmount = (cartState.subtotal - cartState.couponDiscount).clamp(0.0, double.infinity);
    final double effectiveGstAmount = taxPercentage > 0 ? double.parse((taxableAmount * (taxPercentage / 100.0)).toStringAsFixed(2)) : 0.0;
    final double computedTotal = cartState.subtotal - cartState.couponDiscount + effectiveDeliveryFee + effectiveGstAmount;
    final double effectiveGrandTotal = double.parse(computedTotal.toStringAsFixed(2));
    final bool isOutsideRadius = deliveryCalcResult?.isOutsideRadius == true;



    return Scaffold(
      appBar: AppBar(title: const Text('Checkout Details')),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120, left: 16, right: 16, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Delivery Address
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delivery Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add New', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showAddAddressSheet(context),
                      ),
                    ],
                  ),
                  const Gap(8),

                  // Addresses List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final addr = addresses[index];
                      final isSelected = _selectedAddressId == addr.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAddressId = addr.id;
                            _deliveryAddressController.text = addr.fullAddress;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                  : (isDark ? AppColors.darkDivider : Colors.grey.shade100),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                addr.label == 'Home' ? Iconsax.house : Iconsax.briefcase,
                                color: isSelected 
                                    ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                    : AppColors.textLight,
                              ),
                              const Gap(16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          addr.label,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        if (addr.isDefault) ...[
                                          const Gap(8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.success.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'DEFAULT',
                                              style: TextStyle(color: AppColors.success, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const Gap(4),
                                    Text(
                                      '${addr.addressLine}, ${addr.landmark}, ${addr.city} - ${addr.zipCode}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(8),
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected
                                    ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                    : AppColors.textLight,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const Gap(8),

                  // Delivery Address Manual Input Card (Required)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Iconsax.location5, size: 18, color: AppColors.primary),
                            const Gap(8),
                            Text(
                              'Delivery Address *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        const Gap(10),
                        TextField(
                          controller: _deliveryAddressController,
                          maxLines: 3,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textDark,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your complete delivery address (e.g. Flat/House No, Street, Landmark, Area, City)',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(16),

                  // Section Payment Methods
                  Text(
                    'Select Payment Method',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const Gap(12),
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: _paymentMethods.map((method) {
                        final isSelected = _selectedPaymentMethod == method['id'];
                        return ListTile(
                          leading: Icon(
                            method['icon'] as IconData,
                            color: isSelected 
                                ? (isDark ? AppColors.darkPrimary : AppColors.primary) 
                                : AppColors.textLight,
                          ),
                          title: Text(
                            method['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          trailing: Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected
                                ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                : AppColors.textLight,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedPaymentMethod = method['id'] as String;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  const Gap(24),

                  // Section Order Summary Recap
                  Text(
                    'Order Recap',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const Gap(12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.darkDivider : Colors.grey.shade100),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRecapRow('Item Subtotal', '₹${cartState.subtotal.toStringAsFixed(2)}', isDark),
                        if (cartState.couponDiscount > 0)
                          _buildRecapRow(
                            'Coupon Discount',
                            '- ₹${cartState.couponDiscount.toStringAsFixed(2)}',
                            isDark,
                            isDiscount: true,
                          ),
                        _buildRecapRow(
                          deliveryCalcResult?.distanceKm != null && deliveryCalcResult!.distanceKm > 0
                              ? 'Delivery Charge (${deliveryCalcResult.distanceKm.toStringAsFixed(1)} km)'
                              : 'Delivery Charge',
                          effectiveDeliveryFee == 0 ? 'FREE' : '₹${effectiveDeliveryFee.toStringAsFixed(2)}',
                          isDark,
                        ),
                        if (taxPercentage > 0 && effectiveGstAmount > 0)
                          _buildRecapRow(
                            'Govt Taxes & GST (${taxPercentage.toStringAsFixed(taxPercentage.truncateToDouble() == taxPercentage ? 0 : 1)}%)',
                            '₹${effectiveGstAmount.toStringAsFixed(2)}',
                            isDark,
                          ),

                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
                              deliveryCalcResult?.errorMessage ??
                                  'Delivery unavailable: Your address exceeds the maximum delivery radius.',
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

            // Sticky bottom Place Order button
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
                child: CustomButton(
                  text: isOutsideRadius ? 'Outside Delivery Area' : 'Confirm & Place Order (COD)',
                  isLoading: _isPlacingOrder,
                  onPressed: isOutsideRadius
                      ? () {
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
                        }
                      : _onPlaceOrder,
                ),

              ),
            ),
          ],

        ),
      ),
    );
  }

  Widget _buildRecapRow(String label, String value, bool isDark, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDiscount ? AppColors.success : (isDark ? Colors.white : AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

