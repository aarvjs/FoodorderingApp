import 'package:flutter/material.dart';
import '../features/home/widgets/offer_badge.dart';

class OfferModel {
  final String id;
  final String title;
  final String description;
  final String bannerUrl;
  final String ctaText;
  final String couponCode;
  final double discountPercentage;
  final double minimumOrder;
  final OfferBadgeType badgeType;
  final List<Color> accentColors;
  final String? restaurantId;
  final String? branchId;
  final bool isActive;
  final String? discountType;
  final String? startDate;
  final String? endDate;

  const OfferModel({
    required this.id,
    required this.title,
    required this.description,
    required this.bannerUrl,
    this.ctaText = 'Order Now',
    this.couponCode = '',
    this.discountPercentage = 0.0,
    this.minimumOrder = 0.0,
    this.badgeType = OfferBadgeType.flat50,
    this.accentColors = const [Color(0xFFFF4D4F), Color(0xFFFF7043)],
    this.restaurantId,
    this.branchId,
    this.isActive = true,
    this.discountType,
    this.startDate,
    this.endDate,
  });

  String get formattedDiscount {
    final dType = (discountType ?? '').toUpperCase();
    if (dType == 'FLAT' || (discountPercentage >= 100 && dType != 'PERCENTAGE')) {
      return '₹${discountPercentage.toStringAsFixed(0)} OFF';
    } else if (discountPercentage <= 1.0 && discountPercentage > 0) {
      return '${(discountPercentage * 100).toStringAsFixed(0)}% OFF';
    } else if (discountPercentage > 1) {
      return '${discountPercentage.toStringAsFixed(0)}% OFF';
    }
    return 'SPECIAL OFFER';
  }

  factory OfferModel.fromFirestore(Map<String, dynamic> data, String id) {
    final title = (data['title'] ?? 'Special Discount Offer').toString();
    final description = (data['description'] ?? 'Delicious food with heavy discounts!').toString();
    final banner = (data['banner'] ?? data['bannerUrl'] ?? data['image'] ?? '').toString();
    final type = (data['type'] ?? data['discountType'] ?? '').toString().toUpperCase();
    final discount = (data['discountPercentage'] ?? data['discount'] ?? 0.0);
    final discVal = (discount is num) ? discount.toDouble() : double.tryParse(discount.toString()) ?? 0.0;
    final minOrd = (data['minimumOrder'] ?? data['minOrderValue'] ?? 0.0);
    final minOrdVal = (minOrd is num) ? minOrd.toDouble() : double.tryParse(minOrd.toString()) ?? 0.0;
    final status = (data['status'] ?? 'ACTIVE').toString().toUpperCase();
    final sDate = data['startDate']?.toString();
    final eDate = (data['endDate'] ?? data['validTill'])?.toString();
    final rawCode = (data['coupon'] ?? data['couponCode'] ?? data['code'] ?? '').toString();

    OfferBadgeType badgeType = OfferBadgeType.flat50;
    if (type.contains('FREE') || title.toLowerCase().contains('free')) {
      badgeType = OfferBadgeType.freeDelivery;
    } else if (type.contains('BUY1') || title.toLowerCase().contains('buy 1')) {
      badgeType = OfferBadgeType.buy1get1;
    } else if (type.contains('WEEKEND') || title.toLowerCase().contains('weekend')) {
      badgeType = OfferBadgeType.weekend;
    } else if (discVal > 0) {
      badgeType = OfferBadgeType.flat50;
    }

    final hash = title.hashCode.abs();
    final colorGradients = [
      [const Color(0xFFFF4D4F), const Color(0xFFFF7043)],
      [const Color(0xFF92400E), const Color(0xFFD97706)],
      [const Color(0xFF78350F), const Color(0xFFB45309)],
      [const Color(0xFF7C2D12), const Color(0xFFEA580C)],
      [const Color(0xFF7C3AED), const Color(0xFFDB2777)],
      [const Color(0xFF065F46), const Color(0xFF059669)],
    ];

    return OfferModel(
      id: id,
      title: title,
      description: description,
      bannerUrl: banner.isNotEmpty
          ? banner
          : 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=900&q=90&auto=format&fit=crop',
      ctaText: 'Order Now',
      couponCode: rawCode.isNotEmpty ? rawCode : 'OFFER${id.substring(0, id.length > 4 ? 4 : id.length).toUpperCase()}',
      discountPercentage: discVal,
      minimumOrder: minOrdVal,
      badgeType: badgeType,
      accentColors: colorGradients[hash % colorGradients.length],
      restaurantId: data['restaurantId']?.toString(),
      branchId: data['branchId']?.toString(),
      isActive: status == 'ACTIVE',
      discountType: (data['discountType'] ?? data['type'])?.toString(),
      startDate: sDate,
      endDate: eDate,
    );
  }
}
