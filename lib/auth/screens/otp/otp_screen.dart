import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:food_ordering_app/core/config/app_colors.dart';
import 'package:food_ordering_app/routes/app_routes.dart';
import 'package:food_ordering_app/auth/providers/auth_provider.dart';
import 'package:food_ordering_app/features/address/providers/address_provider.dart';
import 'package:food_ordering_app/auth/utils/auth_validators.dart';
import 'package:food_ordering_app/auth/widgets/custom_auth_button.dart';
import 'package:food_ordering_app/auth/widgets/food_auth_illustration.dart';
import 'package:food_ordering_app/auth/widgets/otp_input_fields.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  String _enteredOtp = '';
  bool _isVerifying = false;
  bool _hasNavigated = false;
  final GlobalKey<OtpInputFieldsState> _otpKey = GlobalKey<OtpInputFieldsState>();

  void _navigateToNext(AuthState state) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    final userModel = state.userModel;
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
      AppRoutes.navigateAfterLocation(context, ref);
    }
  }

  Future<void> _handleVerifyOtp([String? otpCode]) async {
    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      _navigateToNext(authState);
      return;
    }
    if (_isVerifying || authState.isLoading || _hasNavigated) return;

    final code = otpCode ?? _enteredOtp;
    if (!AuthValidators.isValidOtp(code)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP code'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isVerifying = true;
    });

    final notifier = ref.read(authProvider.notifier);
    final success = await notifier.verifyOtp(code);

    if (mounted) {
      setState(() {
        _isVerifying = false;
      });

      final latestState = ref.read(authProvider);
      if (success || latestState.status == AuthStatus.authenticated) {
        _navigateToNext(latestState);
      } else if (latestState.errorMessage != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(latestState.errorMessage!),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleResendOtp() async {
    final authState = ref.read(authProvider);
    if (_isVerifying || authState.isLoading || authState.timerSeconds > 0) return;

    // Reset local state and clear OTP fields
    setState(() {
      _enteredOtp = '';
    });
    _otpKey.currentState?.clear();

    final notifier = ref.read(authProvider.notifier);
    await notifier.resendOtp();

    if (mounted) {
      final latestState = ref.read(authProvider);
      if (latestState.errorMessage == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New OTP code sent successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(latestState.errorMessage!),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isBusy = authState.isLoading || _isVerifying;

    // Listen for status changes (e.g. automatic SMS auto-fill login)
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != next.status) {
        if (next.status == AuthStatus.authenticated) {
          _navigateToNext(next);
        }
      }
    });

    final formattedPhone = authState.phoneNumber.startsWith('+')
        ? authState.phoneNumber
        : '+91 ${authState.phoneNumber}';

    return PopScope(
      canPop: !isBusy,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: isBusy ? null : () => context.pop(),
          ),
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Food Auth Illustration
                const FoodAuthIllustration(
                  title: 'Verify OTP Code',
                  subtitle: 'Enter the 6-digit code sent to your mobile number.',
                  icon: Iconsax.security_safe,
                ),

                const SizedBox(height: 24),

                // Phone number display + Change number button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.mobile,
                            size: 20,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            formattedPhone,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: isBusy ? null : () => context.pop(),
                        child: Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isBusy
                                ? Colors.grey
                                : (isDark ? AppColors.darkPrimary : AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 6-digit OTP Fields
                OtpInputFields(
                  key: _otpKey,
                  length: 6,
                  enabled: !isBusy,
                  onChanged: (val) {
                    setState(() {
                      _enteredOtp = val;
                    });
                  },
                  onCompleted: (val) {
                    setState(() {
                      _enteredOtp = val;
                    });
                    _handleVerifyOtp(val);
                  },
                ),

                const SizedBox(height: 24),

                // Countdown Timer & Resend OTP
                Center(
                  child: authState.timerSeconds > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Iconsax.timer_1,
                              size: 18,
                              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Resend OTP in ${authState.timerSeconds}s',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Didn't receive code? ",
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                              ),
                            ),
                            GestureDetector(
                              onTap: isBusy ? null : _handleResendOtp,
                              child: Text(
                                'Resend OTP',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isBusy
                                      ? Colors.grey
                                      : (isDark ? AppColors.darkPrimary : AppColors.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 32),

                // Error display
                if (authState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              authState.errorMessage!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Verify Button
                CustomAuthButton(
                  text: 'Verify OTP',
                  onPressed: () => _handleVerifyOtp(),
                  isLoading: isBusy,
                  isEnabled: !isBusy && AuthValidators.isValidOtp(_enteredOtp),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
