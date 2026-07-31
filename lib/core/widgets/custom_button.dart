import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final double? width;
  final double height;
  final IconData? icon;
  final bool isSecondary;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 54,
    this.icon,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isSecondary 
            ? null 
            : (isDark ? AppColors.darkGradient : AppColors.primaryGradient),
        color: isSecondary 
            ? (isDark ? AppColors.darkCard : Colors.white) 
            : null,
        border: isSecondary 
            ? Border.all(color: isDark ? AppColors.darkDivider : AppColors.divider, width: 1.5) 
            : null,
        boxShadow: isSecondary 
            ? null 
            : [
                BoxShadow(
                  color: (isDark ? AppColors.darkPrimary : AppColors.primary).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSecondary 
                            ? (isDark ? AppColors.darkPrimary : AppColors.primary) 
                            : AppColors.textWhite,
                      ),
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: isSecondary 
                              ? (isDark ? AppColors.darkPrimary : AppColors.primary) 
                              : AppColors.textWhite,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          color: isSecondary
                              ? (isDark ? Colors.white : AppColors.textDark)
                              : AppColors.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
