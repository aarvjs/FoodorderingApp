import 'package:flutter/material.dart';

class AppColors {
  // Light Mode Colors (Perfect Pizza Theme)
  static const Color primary = Color(0xFF0879C9); // Perfect Pizza Primary Blue
  static const Color secondary = Color(0xFF005B9F); // Perfect Pizza Dark Blue
  static const Color accent = Color(0xFFE91D25); // Perfect Pizza Accent Red
  static const Color lightBlue = Color(0xFFEAF6FF); // Supporting Soft Blue
  static const Color success = Color(0xFF22C55E);
  static const Color background = Color(0xFFFFFFFF); // Clean White Base
  static const Color card = Color(0xFFFFFFFF);
  
  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF0A192F);
  static const Color darkCard = Color(0xFF112240);
  static const Color darkPrimary = Color(0xFF0879C9);
  static const Color darkAccent = Color(0xFFE91D25);
  
  // Common Colors
  static const Color textDark = Color(0xFF1F2937);
  static const Color textLight = Color(0xFF6B7280);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = textDark;
  static const Color textSecondary = textLight;
  static const Color surfaceDark = darkCard;
  static const Color divider = Color(0xFFE5E7EB);
  static const Color darkDivider = Color(0xFF1E293B);
  static const Color error = Color(0xFFE91D25);
  static const Color gold = Color(0xFFFFD700);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFFC4151B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkPrimary, Color(0xFF005B9F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
