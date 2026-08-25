import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../address/providers/address_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFlowAndNavigate();
  }

  Future<void> _checkFlowAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final isFirstInstall = prefs.getBool('is_first_install') ?? true;

    if (!mounted) return;

    if (isFirstInstall) {
      context.go('/onboarding');
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);
    final userIsValid = await authNotifier.checkAndReloadUser();

    if (!mounted) return;

    if (!userIsValid) {
      context.go('/login');
    } else {
      final userModel = ref.read(authProvider).userModel;
      final addressState = ref.read(addressProvider);

      final hasAddress = (addressState.selectedAddress != null &&
          addressState.selectedAddress!.formattedAddress.isNotEmpty &&
          addressState.selectedAddress!.latitude != 0.0) ||
          (userModel?.formattedAddress != null &&
          userModel!.formattedAddress!.isNotEmpty &&
          userModel.latitude != null &&
          userModel.latitude != 0.0);

      if (!hasAddress) {
        context.go('/location-permission');
      } else {
        await AppRoutes.navigateAfterLocation(context, ref);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.background,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient soft glowing background circle
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? AppColors.darkPrimary : AppColors.primary).withOpacity(0.08),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            
            // Brand Logo & Text Group
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? AppColors.darkPrimary : AppColors.primary).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/app_logo_1.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                    .animate()
                    .scale(duration: 800.ms, curve: Curves.elasticOut)
                    .then()
                    .shake(hz: 2, offset: const Offset(4, 4), duration: 800.ms),
                const SizedBox(height: 24),
                Text(
                  'Perfect Pizza',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                )
                    .animate()
                    .fade(delay: 200.ms, duration: 500.ms)
                    .slideY(begin: 0.2, curve: Curves.easeOut),
                const SizedBox(height: 8),
                Text(
                  'Delicious meals delivered to your doorstep',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                  ),
                )
                    .animate()
                    .fade(delay: 450.ms, duration: 500.ms)
                    .slideY(begin: 0.2, curve: Curves.easeOut),
              ],
            ),
            
            // Footer credits/loading indicator
            Positioned(
              bottom: 50,
              child: Column(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
