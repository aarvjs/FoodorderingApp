import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:food_ordering_app/core/config/app_colors.dart';

class FoodAuthIllustration extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const FoodAuthIllustration({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Iconsax.shop,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Soft ambient glow circle
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.12),
              ),
            ).animate().scale(duration: 800.ms, curve: Curves.easeOut),

            // Floating Emoji Badges around center icon
            Positioned(
              top: 10,
              left: 20,
              child: const Text('🍕', style: TextStyle(fontSize: 22))
                  .animate()
                  .fade(duration: 500.ms)
                  .shake(duration: 1000.ms),
            ),
            Positioned(
              bottom: 10,
              right: 20,
              child: const Text('🍔', style: TextStyle(fontSize: 22))
                  .animate()
                  .fade(delay: 200.ms, duration: 500.ms)
                  .shake(delay: 300.ms, duration: 1000.ms),
            ),
            Positioned(
              top: 15,
              right: 25,
              child: const Text('🛵', style: TextStyle(fontSize: 20))
                  .animate()
                  .fade(delay: 400.ms, duration: 500.ms),
            ),

            // Main Brand / Food Icon Container
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: isDark ? AppColors.darkGradient : AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 42,
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut)
                .slideY(begin: -0.2, end: 0, duration: 600.ms),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : AppColors.textDark,
          ),
        ).animate().fade(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
            ),
          ),
        ).animate().fade(delay: 250.ms, duration: 400.ms).slideY(begin: 0.1),
      ],
    );
  }
}
