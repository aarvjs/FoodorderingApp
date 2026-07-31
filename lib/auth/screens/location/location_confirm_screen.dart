import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../../core/config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';

class LocationConfirmScreen extends ConsumerStatefulWidget {
  const LocationConfirmScreen({super.key});

  @override
  ConsumerState<LocationConfirmScreen> createState() => _LocationConfirmScreenState();
}

class _LocationConfirmScreenState extends ConsumerState<LocationConfirmScreen> {
  Future<void> _handleConfirmLocation() async {
    final locationState = ref.read(locationProvider);
    final location = locationState.location;

    if (location != null) {
      await ref.read(authProvider.notifier).saveUserData(
        formattedAddress: location.formattedAddress,
        latitude: location.latitude,
        longitude: location.longitude,
        city: location.city,
        stateName: location.state,
        pincode: location.pincode,
      );
    }

    if (mounted) {
      context.push('/complete-profile');
    }
  }

  void _showEditAddressModal() {
    final locationState = ref.read(locationProvider);
    final currentLocation = locationState.location;

    final addressController = TextEditingController(
      text: currentLocation?.formattedAddress ?? '',
    );
    final cityController = TextEditingController(text: currentLocation?.city ?? '');
    final stateController = TextEditingController(text: currentLocation?.state ?? '');
    final pincodeController = TextEditingController(text: currentLocation?.pincode ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Gap(16),
                  Text(
                    'Edit Delivery Address',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const Gap(16),
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Full Address / Street',
                      prefixIcon: const Icon(Iconsax.location),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Gap(12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cityController,
                          decoration: InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: TextField(
                          controller: stateController,
                          decoration: InputDecoration(
                            labelText: 'State',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(12),
                  TextField(
                    controller: pincodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Pincode',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Gap(24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(locationProvider.notifier).setManualLocation(
                          formattedAddress: addressController.text.trim(),
                          city: cityController.text.trim(),
                          stateName: stateController.text.trim(),
                          pincode: pincodeController.text.trim(),
                        );
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Save Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationState = ref.watch(locationProvider);
    final location = locationState.location;

    final displayAddress = location?.formattedAddress.isNotEmpty == true
        ? location!.formattedAddress
        : 'Select delivery location';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Location'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(16),

              // Location Card Display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Iconsax.location5,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const Gap(14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                location?.city.isNotEmpty == true ? location!.city : 'Current Address',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 30),

                    Text(
                      displayAddress,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),

              const Spacer(),

              // Confirm Location Button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _handleConfirmLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Confirm Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

              const Gap(14),

              // Edit Address Button
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _showEditAddressModal,
                  icon: const Icon(Iconsax.edit, size: 18),
                  label: const Text(
                    'Edit Address',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                    side: BorderSide(
                      color: (isDark ? AppColors.darkPrimary : AppColors.primary).withOpacity(0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

              const Gap(10),
            ],
          ),
        ),
      ),
    );
  }
}
