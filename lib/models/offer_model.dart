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
  final List<String> branchIds;
  final bool isActive;
  final String? discountType;
  final String? startDate;
  final String? endDate;

  // Enhancements fields
  final String validityType;
  final String? startTime;
  final String? endTime;
  final List<String> applicableDays;
  final int usageLimit;
  final int usageCount;
  final int remainingUses;
  final double minimumOrderAmount;
  final double discountValue;
  final double maximumDiscountAmount;
  final List<String> excludedCategoryIds;

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
    this.branchIds = const [],
    this.isActive = true,
    this.discountType,
    this.startDate,
    this.endDate,
    this.validityType = 'FULL_DAY',
    this.startTime,
    this.endTime,
    this.applicableDays = const [],
    this.usageLimit = 0,
    this.usageCount = 0,
    this.remainingUses = 0,
    this.minimumOrderAmount = 0.0,
    this.discountValue = 0.0,
    this.maximumDiscountAmount = 0.0,
    this.excludedCategoryIds = const [],
  });

  String get formattedDiscount {
    final dType = (discountType ?? '').toUpperCase();
    if (dType == 'FIXED_AMOUNT' || dType == 'FLAT' || (discountValue > 0 && dType != 'PERCENTAGE')) {
      final val = discountValue > 0 ? discountValue : discountPercentage;
      return '₹${val.toStringAsFixed(0)} OFF';
    } else {
      final pct = discountValue > 0 ? discountValue : (discountPercentage > 1 ? discountPercentage : discountPercentage * 100);
      if (pct > 0) {
        return '${pct.toStringAsFixed(0)}% OFF';
      }
    }
    return 'SPECIAL OFFER';
  }

  factory OfferModel.fromFirestore(Map<String, dynamic> data, String id) {
    final title = (data['title'] ?? 'Special Discount Offer').toString();
    final description = (data['description'] ?? 'Delicious food with heavy discounts!').toString();
    final banner = (data['banner'] ?? data['bannerUrl'] ?? data['image'] ?? '').toString();
    final type = (data['discountType'] ?? data['type'] ?? '').toString().toUpperCase();
    
    final discount = (data['discountValue'] ?? data['discountPercentage'] ?? data['discount'] ?? 0.0);
    final discVal = (discount is num) ? discount.toDouble() : double.tryParse(discount.toString()) ?? 0.0;
    
    final minOrd = (data['minimumOrderAmount'] ?? data['minimumOrder'] ?? data['minOrderValue'] ?? 0.0);
    final minOrdVal = (minOrd is num) ? minOrd.toDouble() : double.tryParse(minOrd.toString()) ?? 0.0;
    
    final maxDisc = (data['maximumDiscountAmount'] ?? 0.0);
    final maxDiscVal = (maxDisc is num) ? maxDisc.toDouble() : double.tryParse(maxDisc.toString()) ?? 0.0;

    final uLimit = (data['usageLimit'] ?? 0);
    final uLimitVal = (uLimit is num) ? uLimit.toInt() : int.tryParse(uLimit.toString()) ?? 0;

    final uCount = (data['usageCount'] ?? 0);
    final uCountVal = (uCount is num) ? uCount.toInt() : int.tryParse(uCount.toString()) ?? 0;

    final remUses = (data['remainingUses'] ?? (uLimitVal > 0 ? (uLimitVal - uCountVal) : 0));
    final remUsesVal = (remUses is num) ? remUses.toInt() : int.tryParse(remUses.toString()) ?? 0;

    final status = (data['status'] ?? 'ACTIVE').toString().toUpperCase();
    final bool isAct = (data['isActive'] != false) && status == 'ACTIVE';
    final sDate = data['startDate']?.toString();
    final eDate = (data['endDate'] ?? data['validTill'])?.toString();
    final rawCode = (data['coupon'] ?? data['couponCode'] ?? data['code'] ?? '').toString();

    final vType = (data['validityType'] ?? 'FULL_DAY').toString();
    final sTime = data['startTime']?.toString();
    final eTime = data['endTime']?.toString();

    final rawDays = data['applicableDays'];
    List<String> daysList = [];
    if (rawDays is List) {
      daysList = rawDays.map((e) => e.toString()).toList();
    }

    final rawExcluded = data['excludedCategoryIds'];
    List<String> excludedList = [];
    if (rawExcluded is List) {
      excludedList = rawExcluded.map((e) => e.toString()).toList();
    }

    final rawBranchIds = data['branchIds'];
    List<String> bIdsList = [];
    if (rawBranchIds is List) {
      bIdsList = rawBranchIds.map((e) => e.toString().trim()).toList();
    }

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
      branchIds: bIdsList,
      isActive: isAct,
      discountType: type.isNotEmpty ? type : (data['discountType']?.toString()),
      startDate: sDate,
      endDate: eDate,
      validityType: vType,
      startTime: sTime,
      endTime: eTime,
      applicableDays: daysList,
      usageLimit: uLimitVal,
      usageCount: uCountVal,
      remainingUses: remUsesVal,
      minimumOrderAmount: minOrdVal,
      discountValue: discVal,
      maximumDiscountAmount: maxDiscVal,
      excludedCategoryIds: excludedList,
    );
  }
}

