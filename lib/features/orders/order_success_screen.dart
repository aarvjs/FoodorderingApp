import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/custom_button.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      // Lottie Checkmark Animation / Fallback
                      Lottie.network(
                        'https://fonts.gstatic.com/s/a/650058e7/lottie.json',
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 72,
                              color: AppColors.success,
                            ),
                          );
                        },
                      ),
                      const Gap(24),

                      // Title & Message
                      Text(
                        'Order Placed!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Gap(10),
                      Text(
                        'Your payment was processed successfully. The restaurant is preparing your food now!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      const Gap(24),

                      // Action Buttons
                      CustomButton(
                        text: 'Track Delivery Timeline',
                        onPressed: () {
                          context.go('/orders');
                        },
                      ),
                      const Gap(12),
                      CustomButton(
                        text: 'Continue Shopping',
                        isSecondary: true,
                        onPressed: () {
                          context.go('/home');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
