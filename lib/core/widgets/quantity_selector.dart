import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class QuantitySelector extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  final double height;
  final double width;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.height = 36,
    this.width = 100,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => onChanged(quantity - 1),
            child: Container(
              width: height,
              height: height,
              alignment: Alignment.center,
              child: Icon(
                Icons.remove,
                size: 16,
                color: isDark ? AppColors.darkPrimary : AppColors.primary,
              ),
            ),
          ),
          Text(
            '$quantity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(quantity + 1),
            child: Container(
              width: height,
              height: height,
              alignment: Alignment.center,
              child: Icon(
                Icons.add,
                size: 16,
                color: isDark ? AppColors.darkPrimary : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
