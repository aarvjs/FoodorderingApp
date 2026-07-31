import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../../core/config/app_colors.dart';
import '../../../models/address.dart';
import '../providers/address_provider.dart';
import 'add_edit_address_modal.dart';

class AddressSelectionBottomSheet extends ConsumerStatefulWidget {
  const AddressSelectionBottomSheet({super.key});

  @override
  ConsumerState<AddressSelectionBottomSheet> createState() => _AddressSelectionBottomSheetState();
}

class _AddressSelectionBottomSheetState extends ConsumerState<AddressSelectionBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Address> _searchResults = [];
  bool _isSearchingPlaces = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) async {
    ref.read(addressProvider.notifier).setSearchQuery(val);
    if (val.trim().length >= 3) {
      setState(() => _isSearchingPlaces = true);
      final results = await ref.read(addressProvider.notifier).searchPlaces(val);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearchingPlaces = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearchingPlaces = false;
        });
      }
    }
  }

  void _openAddEditModal([Address? address]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditAddressModal(existingAddress: address),
    );
  }

  void _confirmDelete(Address address) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Address'),
        content: Text('Are you sure you want to delete "${address.label}" address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(addressProvider.notifier).deleteAddress(address.id, ref);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addressState = ref.watch(addressProvider);
    final selectedAddress = addressState.selectedAddress;
    final filteredList = addressState.filteredAddresses;
    final isFetchingGps = addressState.isFetchingGps;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const Gap(16),

          // Header Title & Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Delivery Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const Gap(12),

          // 🔍 Google / Swiggy style Search Bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search for area, street, city...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
              prefixIcon: Icon(
                Iconsax.search_normal_1,
                size: 18,
                color: isDark ? AppColors.darkPrimary : AppColors.primary,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),

          if (_isSearchingPlaces)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  Gap(10),
                  Text('Searching places...', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ],
              ),
            ),

          if (_searchResults.isNotEmpty) ...[
            const Gap(10),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final place = _searchResults[idx];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Iconsax.location5, color: AppColors.primary, size: 18),
                    title: Text(
                      place.area.isNotEmpty ? place.area : place.city,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppColors.textDark),
                    ),
                    subtitle: Text(
                      place.fullAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
                    ),
                    onTap: () {
                      ref.read(addressProvider.notifier).addAddress(place, ref);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],

          const Gap(16),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📍 Use Current Location Button
                  GestureDetector(
                    onTap: isFetchingGps
                        ? null
                        : () async {
                            final success = await ref
                                .read(addressProvider.notifier)
                                .fetchGpsLocationAndSelect(ref);
                            if (mounted && success) {
                              Navigator.pop(context);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: isFetchingGps
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : const Icon(
                                    Iconsax.location5,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                          ),
                          const Gap(14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Use Current Location',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  isFetchingGps
                                      ? 'Detecting GPS coordinates...'
                                      : 'Using GPS for accurate address delivery',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (addressState.errorMessage != null) ...[
                    const Gap(10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.error, size: 18),
                          const Gap(10),
                          Expanded(
                            child: Text(
                              addressState.errorMessage!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final success = await ref
                                  .read(addressProvider.notifier)
                                  .fetchGpsLocationAndSelect(ref);
                              if (mounted && success) {
                                Navigator.pop(context);
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Gap(20),

                  // 🏠 Saved Addresses Section Header & Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saved Addresses',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openAddEditModal(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'Add New',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  const Gap(10),

                  // Saved Addresses List Cards
                  if (filteredList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          _searchController.text.isNotEmpty
                              ? 'No matching addresses found'
                              : 'No saved addresses yet',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => const Gap(12),
                      itemBuilder: (context, index) {
                        final address = filteredList[index];
                        final isSelected = selectedAddress?.id == address.id;

                        IconData labelIcon = Iconsax.home;
                        if (address.label == 'Work') labelIcon = Iconsax.briefcase;
                        if (address.label == 'Other') labelIcon = Iconsax.location;

                        return GestureDetector(
                          onTap: () {
                            ref.read(addressProvider.notifier).selectAddress(address, ref);
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? AppColors.darkPrimary.withOpacity(0.12)
                                      : AppColors.primary.withOpacity(0.06))
                                  : (isDark ? Colors.grey.shade900 : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Selection Radio / Green Tick Indicator
                                Container(
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? AppColors.success : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.success
                                          : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),

                                const Gap(14),

                                // Address Icon & Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            labelIcon,
                                            size: 18,
                                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                          ),
                                          const Gap(8),
                                          Flexible(
                                            child: Text(
                                              address.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : AppColors.textDark,
                                              ),
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const Gap(8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'ACTIVE',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const Gap(6),
                                      Text(
                                        address.fullAddress,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                        ),
                                      ),
                                      if (address.landmark.isNotEmpty) ...[
                                        const Gap(4),
                                        Text(
                                          'Landmark: ${address.landmark}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Edit & Delete Action Buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Iconsax.edit, size: 18),
                                      color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                      onPressed: () => _openAddEditModal(address),
                                    ),
                                    IconButton(
                                      icon: const Icon(Iconsax.trash, size: 18),
                                      color: AppColors.error,
                                      onPressed: () => _confirmDelete(address),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const Gap(20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
