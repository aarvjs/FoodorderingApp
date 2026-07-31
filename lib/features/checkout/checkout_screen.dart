import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/state_providers.dart';
import '../../models/address.dart';
import '../../auth/providers/auth_provider.dart';
import '../address/widgets/address_selection_bottom_sheet.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedPaymentMethod = 'COD';
  String? _selectedAddressId;
  bool _isPlacingOrder = false;

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
        });
      }
    });
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

    final addressState = ref.read(addressProvider);
    Address? selectedAddr = addressState.selectedAddress;

    if (selectedAddr == null && addressState.addresses.isNotEmpty) {
      selectedAddr = addressState.addresses.firstWhere(
        (a) => a.id == _selectedAddressId,
        orElse: () => addressState.addresses.first,
      );
    }

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

    final authState = ref.read(authProvider);
    final customerId = authState.userModel?.uid ?? 'cust_guest_${DateTime.now().millisecondsSinceEpoch}';
    final customerName = authState.userModel?.fullName?.isNotEmpty == true
        ? authState.userModel!.fullName!
        : 'Guest Customer';
    final customerPhone = authState.userModel?.phone?.isNotEmpty == true
        ? authState.userModel!.phone!
        : '+91 9876543210';

    final fullAddress = selectedAddr.fullAddress;

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
        customerAddress: fullAddress,
        latitude: selectedAddr.latitude,
        longitude: selectedAddr.longitude,
        items: cartState.items,
        subtotal: cartState.subtotal,
        tax: cartState.gstTax,
        deliveryFee: cartState.deliveryFee,
        discount: cartState.couponDiscount,
        grandTotal: cartState.total,
        paymentMethod: _selectedPaymentMethod,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '₹${cartState.total}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const Gap(6),
                        Text(
                          'Includes taxes and delivery fees for ${cartState.items.length} items.',
                          style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
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
                  text: 'Confirm & Place Order (COD)',
                  isLoading: _isPlacingOrder,
                  onPressed: _onPlaceOrder,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
