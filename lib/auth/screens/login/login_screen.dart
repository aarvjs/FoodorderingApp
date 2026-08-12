import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:food_ordering_app/core/config/app_colors.dart';
import 'package:food_ordering_app/auth/utils/auth_validators.dart';
import 'package:food_ordering_app/auth/providers/auth_provider.dart';
import 'package:food_ordering_app/auth/widgets/country_picker_chip.dart';
import 'package:food_ordering_app/auth/widgets/custom_auth_button.dart';
import 'package:food_ordering_app/auth/widgets/food_auth_illustration.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  bool _isValidPhone = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final valid = AuthValidators.isValidPhone(_phoneController.text);
    if (valid != _isValidPhone) {
      setState(() {
        _isValidPhone = valid;
      });
    }
  }

  bool _otpScreenOpened = false;

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final authState = ref.read(authProvider);
    if (!_isValidPhone || authState.isLoading || _otpScreenOpened) return;

    final phone = _phoneController.text.trim();
    FocusScope.of(context).unfocus();

    final notifier = ref.read(authProvider.notifier);
    await notifier.sendOtp(
      phone,
      onCodeSent: () async {
        if (!_otpScreenOpened && mounted) {
          _otpScreenOpened = true;
          await context.push('/otp');
          _otpScreenOpened = false;
        }
      },
      onError: (errorMsg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);

    // Listen for status changes (e.g. automatic SMS verification completion)
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/home');
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Premium Food Delivery Header Illustration
              const FoodAuthIllustration(
                title: 'Welcome to Perfect Pizza',
                subtitle: 'Enter your mobile number to discover hot pizzas & exclusive deals near you.',
                icon: Icons.local_pizza_rounded,
              ),

              const SizedBox(height: 40),

              // Mobile Input Container
              Text(
                'Mobile Number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade300 : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CountryPickerChip(
                    countryCode: '+91',
                    flag: '🇮🇳',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      focusNode: _phoneFocusNode,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        hintText: '98765 43210',
                        counterText: '',
                        prefixIcon: Icon(
                          Iconsax.call,
                          size: 20,
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                        suffixIcon: _phoneController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel, size: 18),
                                onPressed: () {
                                  _phoneController.clear();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              if (_phoneController.text.isNotEmpty && !_isValidPhone)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Enter a valid 10-digit Indian phone number',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Send OTP Button
              CustomAuthButton(
                text: 'Continue',
                onPressed: _handleSendOtp,
                isLoading: authState.isLoading,
                isEnabled: _isValidPhone,
              ),

              const SizedBox(height: 24),

              // Terms & Privacy Note
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'By continuing, you agree to our ',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                    ),
                    children: [
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' & '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
