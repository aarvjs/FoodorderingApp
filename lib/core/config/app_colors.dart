import 'package:flutter/material.dart';

class AppColors {
  // Light Mode Colors
  static const Color primary = Color(0xFFFF4D4F);
  static const Color secondary = Color(0xFFFF7043);
  static const Color accent = Color(0xFFFFC107);
  static const Color success = Color(0xFF22C55E);
  static const Color background = Color(0xFFFAFAFA);
  static const Color card = Color(0xFFFFFFFF);
  
  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkPrimary = Color(0xFFFF5A5C);
  
  // Common Colors
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textLight = Color(0xFF7A7A7A);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color darkDivider = Color(0xFF2C2C2C);
  static const Color error = Color(0xFFEF4444);
  static const Color gold = Color(0xFFFFD700);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkPrimary, Color(0xFFFF8A65)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
