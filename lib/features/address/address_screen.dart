import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/empty_state.dart';
import 'providers/address_provider.dart';
import 'widgets/add_edit_address_modal.dart';

class AddressScreen extends ConsumerWidget {
  const AddressScreen({super.key});

  void _openAddModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddEditAddressModal(),
    );
  }

  void _openEditModal(BuildContext context, address) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditAddressModal(existingAddress: address),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addressState = ref.watch(addressProvider);
    final addresses = addressState.addresses;
    final selectedAddress = addressState.selectedAddress;
    final notifier = ref.read(addressProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Delivery Addresses', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: addresses.isEmpty
                  ? const EmptyState(
                      title: 'No addresses saved',
                      description: 'Save your delivery locations for faster checkout.',
                      fallbackIcon: Iconsax.location,
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: addresses.length,
                      itemBuilder: (context, index) {
                        final addr = addresses[index];
                        final isSelected = selectedAddress?.id == addr.id;

                        IconData labelIcon = Iconsax.home;
                        if (addr.label == 'Work') labelIcon = Iconsax.briefcase;
                        if (addr.label == 'Other') labelIcon = Iconsax.location;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                  : (isDark ? AppColors.darkDivider : Colors.grey.shade200),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    labelIcon,
                                    color: isSelected
                                        ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                        : AppColors.textLight,
                                  ),
                                  const Gap(10),
                                  Text(
                                    addr.label,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  if (isSelected) ...[
                                    const Gap(8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'DEFAULT',
                                        style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Iconsax.edit, size: 18),
                                    onPressed: () => _openEditModal(context, addr),
                                  ),
                                  IconButton(
                                    icon: const Icon(Iconsax.trash, color: AppColors.error, size: 18),
                                    onPressed: () {
                                      notifier.deleteAddress(addr.id, ref);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Address removed.')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const Gap(8),
                              Text(
                                addr.fullAddress,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                  height: 1.4,
                                ),
                              ),
                              if (!isSelected) ...[
                                const Gap(12),
                                OutlinedButton(
                                  onPressed: () {
                                    notifier.selectAddress(addr, ref);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Set as Default Address', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Add Address CTA
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomButton(
                text: 'Add New Address',
                onPressed: () => _openAddModal(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
