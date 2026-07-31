import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum OfferBadgeType { flat50, buy1get1, weekend, limited, freeDelivery, custom }

class OfferBadge extends StatelessWidget {
  final OfferBadgeType type;
  final String? customText;
  final double fontSize;

  const OfferBadge({
    super.key,
    this.type = OfferBadgeType.flat50,
    this.customText,
    this.fontSize = 10,
  });

  String get _label {
    switch (type) {
      case OfferBadgeType.flat50:
        return 'FLAT 50% OFF';
      case OfferBadgeType.buy1get1:
        return 'BUY 1 GET 1';
      case OfferBadgeType.weekend:
        return 'WEEKEND DEAL';
      case OfferBadgeType.limited:
        return '⏰ LIMITED TIME';
      case OfferBadgeType.freeDelivery:
        return '🚚 FREE DELIVERY';
      case OfferBadgeType.custom:
        return customText ?? '';
    }
  }

  List<Color> get _gradientColors {
    switch (type) {
      case OfferBadgeType.flat50:
        return [const Color(0xFFFF4D4F), const Color(0xFFFF7043)];
      case OfferBadgeType.buy1get1:
        return [const Color(0xFF7C3AED), const Color(0xFFDB2777)];
      case OfferBadgeType.weekend:
        return [const Color(0xFFFF8A00), const Color(0xFFFFD700)];
      case OfferBadgeType.limited:
        return [const Color(0xFF059669), const Color(0xFF10B981)];
      case OfferBadgeType.freeDelivery:
        return [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)];
      case OfferBadgeType.custom:
        return [const Color(0xFFFF4D4F), const Color(0xFFFF7043)];
    }
  }

  Color get _glowColor => _gradientColors.first.withOpacity(0.5);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _glowColor,
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        _label,
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
