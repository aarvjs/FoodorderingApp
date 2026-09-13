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
        // Perfect Pizza Brand App Logo
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/app_logo_1.png',
              width: 110,
              height: 110,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: primaryColor,
                child: const Icon(Icons.local_pizza_rounded, size: 50, color: Colors.white),
              ),
            ),
          ),
        )
            .animate()
            .scale(duration: 600.ms, curve: Curves.easeOutBack)
            .fadeIn(duration: 400.ms),
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
