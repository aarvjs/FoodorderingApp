import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../../core/config/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../../features/address/providers/address_provider.dart';
import '../../../features/address/widgets/address_selection_bottom_sheet.dart';

class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends ConsumerState<LocationPermissionScreen>
    with WidgetsBindingObserver {
  bool _isLocalLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Automatically re-check location/GPS status when user returns from Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final locationState = ref.read(locationProvider);
      if (locationState.status == LocationStatusState.serviceDisabled ||
          locationState.status == LocationStatusState.permanentlyDenied ||
          locationState.status == LocationStatusState.denied) {
        _handleFetchLocation();
      }
    }
  }

  void _advanceNext() {
    AppRoutes.navigateAfterLocation(context, ref);
  }

  Future<void> _handleFetchLocation() async {
    if (_isLocalLoading) return;

    setState(() {
      _isLocalLoading = true;
    });

    try {
      final success = await ref.read(addressProvider.notifier).fetchGpsLocationAndSelect(ref);

      if (mounted) {
        setState(() {
          _isLocalLoading = false;
        });

        if (success) {
          _advanceNext();
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to fetch your current location. Please try again.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocalLoading = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to fetch your current location. Please try again.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleManualEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddressSelectionBottomSheet(),
    ).then((_) {
      if (mounted) {
        final addressState = ref.read(addressProvider);
        if (addressState.selectedAddress != null &&
            addressState.selectedAddress!.formattedAddress.isNotEmpty &&
            addressState.selectedAddress!.latitude != 0.0) {
          _advanceNext();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationState = ref.watch(locationProvider);
    final addressState = ref.watch(addressProvider);
    final isFetching = _isLocalLoading || locationState.isFetching || addressState.isFetchingGps;
    final displayError = locationState.errorMessage ?? addressState.errorMessage;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const Spacer(),

              // Animated Radar Pulse / Location Icon
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isFetching)
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.12),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat())
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.3, 1.3),
                            duration: 1200.ms,
                            curve: Curves.easeInOut,
                          )
                          .fadeIn(duration: 400.ms)
                          .then()
                          .fadeOut(duration: 400.ms),

                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.2),
                            AppColors.secondary.withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            locationState.status == LocationStatusState.serviceDisabled
                                ? Iconsax.location_slash
                                : Iconsax.location5,
                            size: 60,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          ),
                          Positioned(
                            right: 12,
                            top: 15,
                            child: const Text('🍔', style: TextStyle(fontSize: 22))
                                .animate(onPlay: (c) => c.repeat())
                                .shake(hz: 1.5, duration: 1500.ms),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 15,
                            child: const Text('🛵', style: TextStyle(fontSize: 22))
                                .animate(onPlay: (c) => c.repeat())
                                .slideX(begin: -0.1, end: 0.1, duration: 1200.ms, curve: Curves.easeInOut),
                          ),
                        ],
                      ),
                    ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                  ],
                ),
              ),

              const Gap(36),

              // Title & Subtitle depending on State
              _buildContentHeader(isDark, locationState, isFetching),

              const Gap(16),

              // Error or Action Warning Banner
              if (displayError != null && !isFetching)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.error, size: 20),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          '$displayError\nTip: You can enter your address manually below.',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

              const Spacer(),

              // Main Action Button depending on permission state
              _buildPrimaryActionButton(ref, locationState, isFetching),

              const Gap(14),

              // Manual Address Entry / Skip Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton.icon(
                  onPressed: isFetching ? null : _handleManualEntry,
                  icon: const Icon(Iconsax.edit, size: 18),
                  label: Text(
                    'Enter Address Manually',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    ),
                  ),
                ),
              ),

              const Gap(10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentHeader(bool isDark, LocationState state, bool isFetching) {
    if (isFetching) {
      return Column(
        children: [
          Text(
            'Finding your location...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
          ),
          const Gap(10),
          Text(
            'Detecting your GPS coordinates to show nearby restaurants & superfast delivery.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
            ),
          ),
        ],
      );
    }

    if (state.status == LocationStatusState.serviceDisabled) {
      return Column(
        children: [
          Text(
            'GPS is Turned Off 📍',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
          ),
          const Gap(10),
          Text(
            'Please turn on GPS Location Services so we can find restaurants and deliver fresh meals to your doorstep.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
            ),
          ),
        ],
      );
    }

    if (state.status == LocationStatusState.permanentlyDenied) {
      return Column(
        children: [
          Text(
            'Location Permission Needed 🔒',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
          ),
          const Gap(10),
          Text(
            'Location access is permanently disabled. Please allow location permissions in your phone settings or enter address manually.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Text(
          'Find Delicious Food\nNear You 📍',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.2,
            color: isDark ? Colors.white : AppColors.textDark,
          ),
        ),
        const Gap(12),
        Text(
          'We use your location to show nearby restaurants, accurate delivery times, and exclusive offers.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.grey.shade400 : AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActionButton(WidgetRef ref, LocationState state, bool isFetching) {
    if (isFetching) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
              Gap(12),
              Text(
                'Fetching your current location...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.status == LocationStatusState.serviceDisabled) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: () => ref.read(locationProvider.notifier).openLocationSettings(),
          icon: const Icon(Iconsax.setting_2, color: Colors.white, size: 20),
          label: const Text(
            'Turn On GPS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (state.status == LocationStatusState.permanentlyDenied) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: () => ref.read(locationProvider.notifier).openAppSettings(),
          icon: const Icon(Iconsax.setting_4, color: Colors.white, size: 20),
          label: const Text(
            'Open App Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _handleFetchLocation,
        icon: const Icon(Iconsax.location, color: Colors.white, size: 20),
        label: Text(
          state.status == LocationStatusState.denied || state.status == LocationStatusState.error
              ? 'Try Again'
              : 'Allow Location',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
