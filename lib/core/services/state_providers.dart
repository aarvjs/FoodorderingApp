import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/cart_item.dart';
import '../../models/offer_model.dart';
import '../../models/order.dart';
import '../../auth/providers/auth_provider.dart';
import 'order_repository.dart';
import 'notification_repository.dart';
import '../../features/rewards/repositories/reward_repository.dart';
export '../../features/address/providers/address_provider.dart';

// ==========================================
// REPOSITORIES PROVIDERS
// ==========================================
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// ==========================================
// REAL-TIME FIRESTORE STREAMS
// ==========================================
final userOrdersStreamProvider = StreamProvider<List<Order>>((ref) {
  final authState = ref.watch(authProvider);
  final userId = authState.userModel?.uid ?? '';
  final repo = ref.watch(orderRepositoryProvider);
  final rewardRepo = ref.watch(rewardRepositoryProvider);

  return repo.streamCustomerOrders(userId).map((orders) {
    final visibleOrders = orders.where((o) => !o.hiddenForUser).toList();
    for (final order in visibleOrders) {
      if (order.isCompleted || order.status.toUpperCase() == 'DELIVERED') {
        rewardRepo.awardPointsForOrder(order);
      }
    }
    return visibleOrders;
  });
});


final userNotificationsStreamProvider = StreamProvider<List<AppNotificationModel>>((ref) {
  final authState = ref.watch(authProvider);
  final userId = authState.userModel?.uid ?? '';
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.streamCustomerNotifications(userId);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(userNotificationsStreamProvider);
  final notifs = notifsAsync.value ?? [];
  return notifs.where((n) => !n.read).length;
});


// ==========================================
// THEME STATE
// ==========================================
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});

// ==========================================
// CART STATE
// ==========================================
class CartState {
  final List<CartItem> items;
  final String? appliedCoupon;
  final String? appliedOfferId;
  final double discountPercentage;
  final double? appliedCouponMinOrder;
  final List<String>? appliedCouponExcludedCategories;
  final List<String>? appliedCouponExcludedProductIds;
  final List<String>? appliedCouponExcludedComboIds;
  final Map<String, List<String>>? appliedCouponExcludedComboProductIds;
  final String? appliedDiscountType;
  final double? appliedDiscountValue;
  final double? appliedMaxDiscountCap;
  final int appliedRewardPoints;
  final double pointValue;
  final double? appliedRewardMinOrder;
  final double? overrideDeliveryFee;
  final double taxPercentage;
  final String selectedOrderType; // "DELIVERY", "TAKE_AWAY"

  const CartState({
    required this.items,
    this.appliedCoupon,
    this.appliedOfferId,
    this.discountPercentage = 0.0,
    this.appliedCouponMinOrder,
    this.appliedCouponExcludedCategories,
    this.appliedCouponExcludedProductIds,
    this.appliedCouponExcludedComboIds,
    this.appliedCouponExcludedComboProductIds,
    this.appliedDiscountType,
    this.appliedDiscountValue,
    this.appliedMaxDiscountCap,
    this.appliedRewardPoints = 0,
    this.pointValue = 0.25,
    this.appliedRewardMinOrder,
    this.overrideDeliveryFee,
    this.taxPercentage = 0.0,
    this.selectedOrderType = 'DELIVERY',
  });

  bool get isTakeAway => selectedOrderType.toUpperCase() == 'TAKE_AWAY';

  double get subtotal {
    return items.fold(0.0, (total, item) => total + item.totalPrice);
  }

  double get eligibleSubtotal {
    if (items.isEmpty) return 0.0;
    if (appliedCoupon == null) return subtotal;

    final exProds = appliedCouponExcludedProductIds ?? [];
    final exCombos = appliedCouponExcludedComboIds ?? [];
    final exComboProds = appliedCouponExcludedComboProductIds ?? {};

    if (exProds.isEmpty && exCombos.isEmpty && exComboProds.isEmpty) {
      return subtotal;
    }

    double sum = 0.0;
    for (final item in items) {
      final String fId = item.foodItem.id.trim().toUpperCase();
      final String fName = item.foodItem.name.trim().toUpperCase();
      final String cItemId = (item.comboItemId ?? '').trim().toUpperCase();
      final String cId = (item.comboId ?? '').trim().toUpperCase();

      bool isExcluded = false;

      if (exProds.isNotEmpty) {
        isExcluded = exProds.any((id) {
          final clean = id.trim().toUpperCase();
          return clean == fId || clean == fName || (cItemId.isNotEmpty && clean == cItemId);
        });
      }

      if (!isExcluded && item.isCombo && cId.isNotEmpty && exCombos.isNotEmpty) {
        isExcluded = exCombos.any((id) => id.trim().toUpperCase() == cId);
      }

      if (!isExcluded && item.isCombo && cId.isNotEmpty && exComboProds.isNotEmpty) {
        List<String> childEx = exComboProds[cId] ?? [];
        if (childEx.isEmpty) {
          final entry = exComboProds.entries.firstWhere(
            (e) => e.key.trim().toUpperCase() == cId,
            orElse: () => const MapEntry('', []),
          );
          childEx = entry.value;
        }
        if (childEx.isNotEmpty) {
          isExcluded = childEx.any((id) {
            final clean = id.trim().toUpperCase();
            return clean == fId || clean == fName || (cItemId.isNotEmpty && clean == cItemId);
          });
        }
      }

      if (!isExcluded) {
        sum += item.totalPrice;
      }
    }
    return sum;
  }

  double get couponDiscount {
    if (items.isEmpty || appliedCoupon == null) return 0.0;
    final eligSub = eligibleSubtotal;
    if (eligSub <= 0) return 0.0;

    final minReq = appliedCouponMinOrder ?? 0.0;
    if (minReq > 0 && eligSub < minReq) return 0.0;

    final dType = (appliedDiscountType ?? '').toUpperCase();
    final rawVal = appliedDiscountValue ?? 0.0;
    final maxCap = appliedMaxDiscountCap ?? 0.0;

    double amount = 0.0;
    if (dType == 'FIXED_AMOUNT' || dType == 'FLAT' || (rawVal >= 100.0 && dType != 'PERCENTAGE')) {
      amount = rawVal.clamp(0.0, eligSub);
    } else if (rawVal > 0) {
      final pct = (rawVal > 1.0) ? (rawVal / 100.0) : rawVal;
      amount = eligSub * pct;
      if (maxCap > 0 && amount > maxCap) {
        amount = maxCap;
      }
    } else if (discountPercentage > 0) {
      amount = eligSub * discountPercentage;
    }

    final clamped = amount.clamp(0.0, eligSub);
    return double.parse(clamped.toStringAsFixed(2));
  }

  double get maxRewardEligibleSubtotal {
    return (subtotal - couponDiscount).clamp(0.0, double.infinity);
  }

  double get rewardDiscount {
    if (subtotal <= 0 || appliedRewardPoints <= 0) return 0.0;
    if (appliedRewardMinOrder != null && appliedRewardMinOrder! > 0 && subtotal < appliedRewardMinOrder!) {
      return 0.0;
    }
    final rawVal = appliedRewardPoints * pointValue;
    final clamped = rawVal.clamp(0.0, maxRewardEligibleSubtotal);
    return double.parse(clamped.toStringAsFixed(2));
  }

  double get totalDiscount {
    return double.parse((couponDiscount + rewardDiscount).toStringAsFixed(2));
  }

  double get deliveryFee {
    if (items.isEmpty || isTakeAway) return 0.0;
    if (overrideDeliveryFee != null) return overrideDeliveryFee!;
    return 0.0;
  }

  double get gstTax {
    if (items.isEmpty || taxPercentage <= 0) return 0.0;
    final taxableAmount = (subtotal - couponDiscount - rewardDiscount).clamp(0.0, double.infinity);
    if (taxableAmount <= 0) return 0.0;
    return double.parse((taxableAmount * (taxPercentage / 100.0)).toStringAsFixed(2));
  }

  double get total {
    if (items.isEmpty) return 0.0;
    final calculated = (subtotal - couponDiscount - rewardDiscount + deliveryFee + gstTax).clamp(0.0, double.infinity);
    return double.parse(calculated.toStringAsFixed(2));
  }

  CartState copyWith({
    List<CartItem>? items,
    String? appliedCoupon,
    String? appliedOfferId,
    double? discountPercentage,
    double? appliedCouponMinOrder,
    List<String>? appliedCouponExcludedCategories,
    List<String>? appliedCouponExcludedProductIds,
    List<String>? appliedCouponExcludedComboIds,
    Map<String, List<String>>? appliedCouponExcludedComboProductIds,
    String? appliedDiscountType,
    double? appliedDiscountValue,
    double? appliedMaxDiscountCap,
    int? appliedRewardPoints,
    double? pointValue,
    double? appliedRewardMinOrder,
    double? overrideDeliveryFee,
    double? taxPercentage,
    String? selectedOrderType,
    bool clearCoupon = false,
    bool clearReward = false,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
      appliedOfferId: clearCoupon ? null : (appliedOfferId ?? this.appliedOfferId),
      discountPercentage: clearCoupon ? 0.0 : (discountPercentage ?? this.discountPercentage),
      appliedCouponMinOrder: clearCoupon ? null : (appliedCouponMinOrder ?? this.appliedCouponMinOrder),
      appliedCouponExcludedCategories: clearCoupon ? null : (appliedCouponExcludedCategories ?? this.appliedCouponExcludedCategories),
      appliedCouponExcludedProductIds: clearCoupon ? null : (appliedCouponExcludedProductIds ?? this.appliedCouponExcludedProductIds),
      appliedCouponExcludedComboIds: clearCoupon ? null : (appliedCouponExcludedComboIds ?? this.appliedCouponExcludedComboIds),
      appliedCouponExcludedComboProductIds: clearCoupon ? null : (appliedCouponExcludedComboProductIds ?? this.appliedCouponExcludedComboProductIds),
      appliedDiscountType: clearCoupon ? null : (appliedDiscountType ?? this.appliedDiscountType),
      appliedDiscountValue: clearCoupon ? null : (appliedDiscountValue ?? this.appliedDiscountValue),
      appliedMaxDiscountCap: clearCoupon ? null : (appliedMaxDiscountCap ?? this.appliedMaxDiscountCap),
      appliedRewardPoints: clearReward ? 0 : (appliedRewardPoints ?? this.appliedRewardPoints),
      pointValue: pointValue ?? this.pointValue,
      appliedRewardMinOrder: clearReward ? null : (appliedRewardMinOrder ?? this.appliedRewardMinOrder),
      overrideDeliveryFee: overrideDeliveryFee ?? this.overrideDeliveryFee,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      selectedOrderType: selectedOrderType ?? this.selectedOrderType,
    );
  }
}




class CouponApplyResult {
  final bool isSuccess;
  final String message;
  final String? appliedCode;

  const CouponApplyResult({
    required this.isSuccess,
    required this.message,
    this.appliedCode,
  });
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    final initialState = const CartState(items: []);
    // Perform initial expiry check on build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndExpireItems();
    });
    return initialState;
  }

  void checkAndExpireItems() {
    if (state.items.isEmpty) return;
    final now = DateTime.now();
    final validItems = state.items.where((item) {
      final ageMs = now.difference(item.addedAt).inMilliseconds;
      return ageMs < (5 * 3600 * 1000); // 5-hour cart retention rule
    }).toList();

    if (validItems.length != state.items.length) {
      if (validItems.isEmpty) {
        clearCart();
      } else {
        state = state.copyWith(items: validItems);
      }
    }
  }

  void setOrderType(String orderType) {
    state = state.copyWith(selectedOrderType: orderType);
  }

  bool isDifferentRestaurant(String restaurantId, {String? branchId}) {
    if (state.items.isEmpty) return false;
    final firstItem = state.items.first;
    final firstBranchId = firstItem.branchId.isNotEmpty ? firstItem.branchId : firstItem.restaurantId;
    final firstRestId = firstItem.restaurantId;

    final targetBranchId = (branchId != null && branchId.isNotEmpty) ? branchId : restaurantId;

    if (branchId != null && branchId.isNotEmpty) {
      return firstBranchId != targetBranchId && firstItem.branchId != targetBranchId;
    }
    return firstRestId != restaurantId && firstBranchId != restaurantId;
  }

  String? checkItemExclusion({
    required CartItem item,
    required List<String> excludedProductIds,
    required List<String> excludedComboIds,
    required Map<String, List<String>> excludedComboProductIds,
  }) {
    final String foodItemId = item.foodItem.id.trim();
    final String foodItemName = item.foodItem.name.trim();

    // 1. Menu item exclusion check
    if (!item.isCombo) {
      if (excludedProductIds.any((id) {
        final cleanId = id.trim().toLowerCase();
        return cleanId == foodItemId.toLowerCase() || cleanId == foodItemName.toLowerCase();
      })) {
        return 'This offer is not applicable to ${item.foodItem.name}.';
      }
    }

    // 2. Entire combo exclusion check
    if (item.isCombo) {
      final comboId = (item.comboId ?? '').trim();
      if (comboId.isNotEmpty && excludedComboIds.any((id) => id.trim().toLowerCase() == comboId.toLowerCase())) {
        return 'This offer is not applicable to this combo.';
      }

      // 3. Partial product inside combo exclusion check
      if (comboId.isNotEmpty) {
        List<String> exComboProducts = excludedComboProductIds[comboId] ?? [];
        if (exComboProducts.isEmpty) {
          final entry = excludedComboProductIds.entries.firstWhere(
            (e) => e.key.trim().toLowerCase() == comboId.toLowerCase(),
            orElse: () => const MapEntry('', []),
          );
          exComboProducts = entry.value;
        }

        if (exComboProducts.isNotEmpty) {
          final comboItemId = (item.comboItemId ?? '').trim();
          bool isChildExcluded = exComboProducts.any((id) {
            final cleanId = id.trim().toLowerCase();
            return cleanId == foodItemId.toLowerCase() ||
                   cleanId == foodItemName.toLowerCase() ||
                   (comboItemId.isNotEmpty && cleanId == comboItemId.toLowerCase());
          });

          if (!isChildExcluded && item.customizationSelections.isNotEmpty) {
            for (final cust in item.customizationSelections) {
              if (cust.productId != null && cust.productId!.trim().isNotEmpty) {
                final cProdId = cust.productId!.trim().toLowerCase();
                if (exComboProducts.any((id) => id.trim().toLowerCase() == cProdId)) {
                  isChildExcluded = true;
                  break;
                }
              }
            }
          }

          if (isChildExcluded) {
            return 'This offer is not applicable to ${item.foodItem.name} in this combo.';
          }
        }
      }
    }

    return null;
  }

  bool isItemExcludedForOffer({
    required CartItem item,
    required List<String> excludedProductIds,
    required List<String> excludedComboIds,
    required Map<String, List<String>> excludedComboProductIds,
  }) {
    final itemId = item.foodItem.id.trim().toUpperCase();
    final itemName = item.foodItem.name.trim().toUpperCase();
    final comboItemId = (item.comboItemId ?? '').trim().toUpperCase();

    if (excludedProductIds.isNotEmpty) {
      if (excludedProductIds.any((id) {
        final cleanId = id.trim().toUpperCase();
        return cleanId == itemId || cleanId == itemName || (comboItemId.isNotEmpty && cleanId == comboItemId);
      })) {
        return true;
      }
    }

    final exclusionMsg = checkItemExclusion(
      item: item,
      excludedProductIds: excludedProductIds,
      excludedComboIds: excludedComboIds,
      excludedComboProductIds: excludedComboProductIds,
    );

    return exclusionMsg != null;
  }

  double calculateEligibleSubtotalForOffer({
    required List<String> excludedProductIds,
    required List<String> excludedComboIds,
    required Map<String, List<String>> excludedComboProductIds,
  }) {
    double eligibleSubtotal = 0.0;
    for (final item in state.items) {
      final bool isExcluded = isItemExcludedForOffer(
        item: item,
        excludedProductIds: excludedProductIds,
        excludedComboIds: excludedComboIds,
        excludedComboProductIds: excludedComboProductIds,
      );
      if (!isExcluded) {
        eligibleSubtotal += item.totalPrice;
      }
    }
    return eligibleSubtotal;
  }

  void _revalidateDiscounts() {
    if (state.items.isEmpty) {
      state = state.copyWith(clearCoupon: true, clearReward: true);
      return;
    }

    if (state.appliedRewardPoints > 0) {
      final double minReq = state.appliedRewardMinOrder ?? 0.0;
      if ((minReq > 0 && state.subtotal < minReq) || state.subtotal <= 0) {
        state = state.copyWith(clearReward: true);
      }
    }

    if (state.appliedCoupon != null) {
      if (state.subtotal <= 0) {
        state = state.copyWith(clearCoupon: true);
        return;
      }

      final minReq = state.appliedCouponMinOrder ?? 0.0;
      final excludedProductIds = state.appliedCouponExcludedProductIds ?? [];
      final excludedComboIds = state.appliedCouponExcludedComboIds ?? [];
      final excludedComboProductIds = state.appliedCouponExcludedComboProductIds ?? {};

      // Recalculate current eligible product subtotal for Menu + Combo items
      final double eligibleSubtotal = calculateEligibleSubtotalForOffer(
        excludedProductIds: excludedProductIds,
        excludedComboIds: excludedComboIds,
        excludedComboProductIds: excludedComboProductIds,
      );

      // If current eligible subtotal <= 0 or < coupon minimum order requirement, auto-remove coupon
      if (eligibleSubtotal <= 0 || (minReq > 0 && eligibleSubtotal < minReq)) {
        debugPrint('[CartNotifier] Auto-removing coupon "${state.appliedCoupon}": eligible subtotal (₹$eligibleSubtotal) < minOrder (₹$minReq)');
        state = state.copyWith(clearCoupon: true);
      }
    }
  }

  void forceAddItem(CartItem item) {
    state = CartState(items: [item], appliedCoupon: null, appliedOfferId: null, discountPercentage: 0.0);
  }

  void addItem(CartItem item) {
    // If adding item from a different restaurant or branch, reset cart
    if (state.items.isNotEmpty) {
      final firstItem = state.items.first;
      final firstBranchId = firstItem.branchId.isNotEmpty ? firstItem.branchId : firstItem.restaurantId;
      final itemBranchId = item.branchId.isNotEmpty ? item.branchId : item.restaurantId;

      if (firstBranchId != itemBranchId && firstItem.restaurantId != item.restaurantId) {
        state = CartState(items: [item], appliedCoupon: null, appliedOfferId: null, discountPercentage: 0.0);
        return;
      }
    }

    final index = state.items.indexWhere((i) => i.cartKey == item.cartKey);

    if (index >= 0) {
      final updatedItems = List<CartItem>.from(state.items);
      final currentQuantity = updatedItems[index].quantity;
      final addAmount = item.quantity > 0 ? item.quantity : 1;
      updatedItems[index] = updatedItems[index].copyWith(quantity: currentQuantity + addAmount);
      state = state.copyWith(items: updatedItems);
    } else {
      state = state.copyWith(items: [...state.items, item]);
    }
    _revalidateDiscounts();
  }

  void updateItemAtIndex(int index, CartItem newItem) {
    if (index < 0 || index >= state.items.length) return;
    final updatedItems = List<CartItem>.from(state.items);
    updatedItems[index] = newItem;
    state = state.copyWith(items: updatedItems);
    _revalidateDiscounts();
  }

  void updateQuantityAtIndex(int index, int quantity) {
    if (index < 0 || index >= state.items.length) return;
    if (quantity <= 0) {
      removeItemAtIndex(index);
      return;
    }
    final updatedItems = List<CartItem>.from(state.items);
    updatedItems[index] = updatedItems[index].copyWith(quantity: quantity);
    state = state.copyWith(items: updatedItems);
    _revalidateDiscounts();
  }

  void removeItemAtIndex(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updatedItems = List<CartItem>.from(state.items)..removeAt(index);
    state = state.copyWith(items: updatedItems);
    if (updatedItems.isEmpty) {
      clearCart();
    } else {
      _revalidateDiscounts();
    }
  }

  void updateQuantity(String itemId, int quantity) {
    final index = state.items.indexWhere((i) => i.foodItem.id == itemId || i.cartKey == itemId);
    if (index >= 0) {
      updateQuantityAtIndex(index, quantity);
    }
  }

  void removeItem(String itemId) {
    final index = state.items.indexWhere((i) => i.foodItem.id == itemId || i.cartKey == itemId);
    if (index >= 0) {
      removeItemAtIndex(index);
    } else {
      final updatedItems = state.items.where((item) => item.foodItem.id != itemId).toList();
      state = state.copyWith(items: updatedItems);
      if (updatedItems.isEmpty) {
        clearCart();
      } else {
        _revalidateDiscounts();
      }
    }
  }

  Future<CouponApplyResult> applyOffer(dynamic offer) async {
    if (offer is OfferModel) {
      return applyCoupon(offer.couponCode, targetOfferId: offer.id);
    } else if (offer is Map) {
      final code = (offer['couponCode'] ?? offer['coupon'] ?? offer['code'] ?? '').toString();
      final id = (offer['id'] ?? offer['_id'] ?? '').toString();
      return applyCoupon(code, targetOfferId: id.isNotEmpty ? id : null);
    } else {
      final code = (offer ?? '').toString();
      return applyCoupon(code);
    }
  }

  int? _parseTimeToMinutes(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final timePart = clean.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = timePart.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int min = int.parse(parts[1]);
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        return hour * 60 + min;
      }
    } catch (_) {}
    return null;
  }

  Future<CouponApplyResult> applyCoupon(String code, {String? targetOfferId}) async {
    final normalizedCode = code.trim().toUpperCase();
    final cleanTargetOfferId = (targetOfferId ?? '').trim();

    if (normalizedCode.isEmpty && cleanTargetOfferId.isEmpty) {
      return const CouponApplyResult(
        isSuccess: false,
        message: 'Please enter a coupon code.',
      );
    }

    if (state.items.isEmpty) {
      return const CouponApplyResult(
        isSuccess: false,
        message: 'Your cart is empty.',
      );
    }

    // 1. Check legacy hardcoded coupons
    if (cleanTargetOfferId.isEmpty) {
      if (normalizedCode == 'WELCOME50') {
        state = state.copyWith(appliedCoupon: 'WELCOME50', appliedOfferId: null, discountPercentage: 0.50);
        return const CouponApplyResult(
          isSuccess: true,
          message: 'Coupon "WELCOME50" applied successfully!',
          appliedCode: 'WELCOME50',
        );
      } else if (normalizedCode == 'BINGE20') {
        state = state.copyWith(appliedCoupon: 'BINGE20', appliedOfferId: null, discountPercentage: 0.20);
        return const CouponApplyResult(
          isSuccess: true,
          message: 'Coupon "BINGE20" applied successfully!',
          appliedCode: 'BINGE20',
        );
      } else if (normalizedCode == 'FREEDEL') {
        state = state.copyWith(appliedCoupon: 'FREEDEL', appliedOfferId: null, discountPercentage: 0.05);
        return const CouponApplyResult(
          isSuccess: true,
          message: 'Coupon "FREEDEL" applied successfully!',
          appliedCode: 'FREEDEL',
        );
      }
    }

    // 2. Validate against Firestore `offers` collection documents
    try {
      final snap = await FirebaseFirestore.instance.collection('offers').get();
      
      // 2. Build comprehensive, case-insensitive set of candidate IDs for the active cart branch & parent restaurant
      final Set<String> rawCandidateIds = {};
      for (final item in state.items) {
        if (item.branchId.trim().isNotEmpty) rawCandidateIds.add(item.branchId.trim());
        if (item.restaurantId.trim().isNotEmpty) rawCandidateIds.add(item.restaurantId.trim());
        final fBranch = (item.foodItem.branchId ?? '').trim();
        final fRest = (item.foodItem.restaurantId ?? '').trim();
        if (fBranch.isNotEmpty) rawCandidateIds.add(fBranch);
        if (fRest.isNotEmpty) rawCandidateIds.add(fRest);
      }

      final List<String> initialLookupIds = List<String>.from(rawCandidateIds);
      for (final lookupId in initialLookupIds) {
        try {
          final branchDoc = await FirebaseFirestore.instance.collection('branches').doc(lookupId).get();
          if (branchDoc.exists && branchDoc.data() != null) {
            final bData = branchDoc.data()!;
            rawCandidateIds.add(branchDoc.id.trim());
            final bFields = [
              bData['restaurantId'],
              bData['restaurant_id'],
              bData['parentId'],
              bData['parent_id'],
              bData['branchId'],
              bData['branch_id'],
              bData['id'],
              bData['branchCode'],
              bData['code'],
            ];
            for (final f in bFields) {
              if (f != null && f.toString().trim().isNotEmpty) {
                rawCandidateIds.add(f.toString().trim());
              }
            }
          }
        } catch (_) {}

        try {
          final restDoc = await FirebaseFirestore.instance.collection('restaurants').doc(lookupId).get();
          if (restDoc.exists && restDoc.data() != null) {
            final rData = restDoc.data()!;
            rawCandidateIds.add(restDoc.id.trim());
            final rFields = [rData['restaurantId'], rData['restaurant_id'], rData['id']];
            for (final f in rFields) {
              if (f != null && f.toString().trim().isNotEmpty) {
                rawCandidateIds.add(f.toString().trim());
              }
            }
          }
        } catch (_) {}
      }

      final Set<String> upperCandidateIds = rawCandidateIds
          .map((id) => id.toUpperCase().trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      final currentSubtotal = state.subtotal;
      final now = DateTime.now();

      for (var doc in snap.docs) {
        final data = doc.data();
        final rawCoupon = (data['coupon'] ?? data['couponCode'] ?? data['code'] ?? '').toString().trim().toUpperCase();

        if (cleanTargetOfferId.isNotEmpty) {
          if (doc.id.trim() != cleanTargetOfferId) continue;
        } else {
          final fallbackCoupon = 'OFFER${doc.id.substring(0, doc.id.length > 4 ? 4 : doc.id.length).toUpperCase()}';
          
          final matchCode = (rawCoupon.isNotEmpty && rawCoupon == normalizedCode) ||
              (fallbackCoupon == normalizedCode);

          if (!matchCode) continue;
        }

        // Requirement 9: Is offer active?
        final status = (data['status'] ?? 'ACTIVE').toString().toUpperCase();
        final bool isActive = (data['isActive'] != false) && status == 'ACTIVE';
        if (!isActive) {
          return const CouponApplyResult(
            isSuccess: false,
            message: 'This offer is no longer active.',
          );
        }

        // Requirement 1 & 9: Is current date valid?
        final String? startDateStr = data['startDate']?.toString();
        if (startDateStr != null && startDateStr.isNotEmpty) {
          try {
            final sDate = DateTime.parse(startDateStr);
            if (now.isBefore(sDate)) {
              return const CouponApplyResult(
                isSuccess: false,
                message: 'This offer is scheduled for a future date.',
              );
            }
          } catch (_) {}
        }

        final String? endDateStr = (data['endDate'] ?? data['validTill'])?.toString();
        if (endDateStr != null && endDateStr.isNotEmpty) {
          try {
            final expiryDate = DateTime.parse(endDateStr);
            if (now.isAfter(expiryDate.add(const Duration(days: 1)))) {
              return const CouponApplyResult(
                isSuccess: false,
                message: 'This offer has expired.',
              );
            }
          } catch (_) {}
        }

        // Requirement 1: Is current time valid? (Validity Type: Scheduled Time vs Full Day)
        final validityType = (data['validityType'] ?? 'FULL_DAY').toString().toUpperCase();
        if (validityType == 'SCHEDULED_TIME') {
          final sTime = data['startTime']?.toString();
          final eTime = data['endTime']?.toString();
          if (sTime != null && eTime != null && sTime.isNotEmpty && eTime.isNotEmpty) {
            final startMin = _parseTimeToMinutes(sTime);
            final endMin = _parseTimeToMinutes(eTime);
            final nowMin = now.hour * 60 + now.minute;
            if (startMin != null && endMin != null) {
              if (nowMin < startMin || nowMin > endMin) {
                return CouponApplyResult(
                  isSuccess: false,
                  message: 'Offer is only available between $sTime and $eTime.',
                );
              }
            }
          }
        }

        // Requirement 8: Is current day allowed?
        final rawDays = data['applicableDays'];
        if (rawDays is List && rawDays.isNotEmpty) {
          final dayMap = {1: 'MONDAY', 2: 'TUESDAY', 3: 'WEDNESDAY', 4: 'THURSDAY', 5: 'FRIDAY', 6: 'SATURDAY', 7: 'SUNDAY'};
          final currentDayName = dayMap[now.weekday] ?? '';
          final allowedDays = rawDays.map((d) => d.toString().trim().toUpperCase()).toList();
          if (!allowedDays.contains(currentDayName)) {
            return const CouponApplyResult(
              isSuccess: false,
              message: 'This offer is not applicable today.',
            );
          }
        }

        // Requirement 2: Has total usage limit been reached?
        final uLimit = (data['usageLimit'] ?? 0);
        final int usageLimit = (uLimit is num) ? uLimit.toInt() : int.tryParse(uLimit.toString()) ?? 0;
        final uCount = (data['usageCount'] ?? 0);
        final int usageCount = (uCount is num) ? uCount.toInt() : int.tryParse(uCount.toString()) ?? 0;
        if (usageLimit > 0 && usageCount >= usageLimit) {
          return const CouponApplyResult(
            isSuccess: false,
            message: 'Sorry, this offer has reached its usage limit.',
          );
        }

        // Requirement 2b: Has per-user usage limit been reached?
        final mUsesUser = (data['maxUsesPerUser'] ?? 0);
        final int maxUsesPerUser = (mUsesUser is num) ? mUsesUser.toInt() : int.tryParse(mUsesUser.toString()) ?? 0;
        if (maxUsesPerUser > 0) {
          final authUser = FirebaseAuth.instance.currentUser;
          final userModel = ref.read(authProvider).userModel;
          final currentUserId = (authUser?.uid ?? userModel?.uid ?? '').trim();
          final currentPhone = (authUser?.phoneNumber ?? userModel?.phone ?? ref.read(authProvider).phoneNumber).trim();

          if (currentUserId.isNotEmpty || currentPhone.isNotEmpty) {
            try {
              final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> docMap = {};

              if (currentUserId.isNotEmpty) {
                final snapById = await FirebaseFirestore.instance
                    .collection('orders')
                    .where('customerId', isEqualTo: currentUserId)
                    .get();
                for (final docSnap in snapById.docs) {
                  docMap[docSnap.id] = docSnap;
                }
              }

              if (currentPhone.isNotEmpty) {
                final snapByPhone = await FirebaseFirestore.instance
                    .collection('orders')
                    .where('customerPhone', isEqualTo: currentPhone)
                    .get();
                for (final docSnap in snapByPhone.docs) {
                  docMap[docSnap.id] = docSnap;
                }
              }

              int userUsageCount = 0;
              final offerDocId = doc.id.trim();
              final offerCouponCode = (data['coupon'] ?? data['couponCode'] ?? data['code'] ?? '').toString().trim().toUpperCase();
              final matchCouponCode = offerCouponCode.isNotEmpty ? offerCouponCode : normalizedCode;

              for (final oDoc in docMap.values) {
                final oData = oDoc.data();
                final oStatus = (oData['status'] ?? '').toString().toUpperCase();
                if (oStatus == 'CANCELLED' || oStatus == 'REJECTED') {
                  continue;
                }
                final oAppliedOfferId = (oData['appliedOfferId'] ?? '').toString().trim();
                final oAppliedCoupon = (oData['appliedCoupon'] ?? '').toString().trim().toUpperCase();

                bool matches = false;
                if (oAppliedOfferId.isNotEmpty && oAppliedOfferId == offerDocId) {
                  matches = true;
                }
                if (oAppliedCoupon.isNotEmpty) {
                  if (oAppliedCoupon == matchCouponCode ||
                      oAppliedCoupon == normalizedCode ||
                      (offerCouponCode.isNotEmpty && oAppliedCoupon == offerCouponCode)) {
                    matches = true;
                  }
                }

                if (matches) {
                  userUsageCount++;
                }
              }

              debugPrint('[ApplyCoupon] PerUserCheck - Offer: $offerDocId ($matchCouponCode) | User: $currentUserId / $currentPhone | Count: $userUsageCount / Max: $maxUsesPerUser');

              if (userUsageCount >= maxUsesPerUser) {
                return const CouponApplyResult(
                  isSuccess: false,
                  message: 'You have already used this offer the maximum number of times.',
                );
              }
            } catch (e) {
              debugPrint('[CartNotifier] Error checking per-user offer limit: $e');
            }
          }
        }

        // Strict Restaurant ID & Branch ID validation
        final String oRestId = (data['restaurantId'] ?? data['restaurant_id'] ?? '').toString().trim();
        final String oBranchId = (data['branchId'] ?? data['branch_id'] ?? data['applicableBranchId'] ?? data['restaurantBranchId'] ?? '').toString().trim();
        
        final List<String> oBranchIds = [];
        final rawBIds = data['branchIds'] ?? data['branch_ids'] ?? data['applicableBranchIds'];
        if (rawBIds is List) {
          for (final b in rawBIds) {
            if (b != null && b.toString().trim().isNotEmpty) {
              oBranchIds.add(b.toString().trim());
            }
          }
        }
        if (oBranchId.isNotEmpty && !oBranchIds.contains(oBranchId)) {
          oBranchIds.add(oBranchId);
        }

        final String oBranchIdUpper = oBranchId.toUpperCase();
        final String oRestIdUpper = oRestId.toUpperCase();
        final List<String> oBranchIdsUpper = oBranchIds.map((b) => b.toUpperCase()).toList();

        final bool isGlobal = oBranchIdUpper.isEmpty ||
            oBranchIdUpper == 'ALL' ||
            oBranchIdsUpper.contains('ALL') ||
            (oBranchIdUpper.isEmpty && oBranchIdsUpper.isEmpty && (oRestIdUpper.isEmpty || oRestIdUpper == 'ALL'));

        debugPrint('[ApplyCoupon] Code: $normalizedCode | OfferId: ${doc.id}');
        debugPrint('[ApplyCoupon] Offer branchId: $oBranchId | branchIds: $oBranchIds | restId: $oRestId | isGlobal: $isGlobal');
        debugPrint('[ApplyCoupon] Cart Active Branch Candidates: $upperCandidateIds');

        if (!isGlobal) {
          final bool matchesBranchId = oBranchIdUpper.isNotEmpty && upperCandidateIds.contains(oBranchIdUpper);
          final bool matchesBranchIds = oBranchIdsUpper.any((b) => upperCandidateIds.contains(b));
          final bool matchesRestId = oRestIdUpper.isNotEmpty && upperCandidateIds.contains(oRestIdUpper);

          if (!matchesBranchId && !matchesBranchIds && !matchesRestId) {
            debugPrint('[ApplyCoupon] Branch check failed for code: $normalizedCode against candidates: $upperCandidateIds');
            return const CouponApplyResult(
              isSuccess: false,
              message: 'This coupon is not valid for this branch.',
            );
          }
        }

        final rawExProducts = data['excludedProductIds'] ?? data['excludedProducts'];
        List<String> excludedProductIds = [];
        if (rawExProducts is List) {
          excludedProductIds = rawExProducts.map((e) => e.toString().trim()).toList();
        }

        final rawExCombos = data['excludedComboIds'] ?? data['excludedCombos'];
        List<String> excludedComboIds = [];
        if (rawExCombos is List) {
          excludedComboIds = rawExCombos.map((e) => e.toString().trim()).toList();
        }

        final rawExComboProds = data['excludedComboProductIds'] ?? data['excludedComboProducts'];
        Map<String, List<String>> excludedComboProductIds = {};
        if (rawExComboProds is Map) {
          rawExComboProds.forEach((key, value) {
            if (value is List) {
              excludedComboProductIds[key.toString().trim()] = value.map((e) => e.toString().trim()).toList();
            }
          });
        }

        final double eligibleSubtotal = calculateEligibleSubtotalForOffer(
          excludedProductIds: excludedProductIds,
          excludedComboIds: excludedComboIds,
          excludedComboProductIds: excludedComboProductIds,
        );

        if (eligibleSubtotal <= 0) {
          return const CouponApplyResult(
            isSuccess: false,
            message: 'Items in your cart are excluded for this offer.',
          );
        }

        // Requirement 4: Minimum Order Amount check
        final minOrd = (data['minimumOrderAmount'] ?? data['minimumOrder'] ?? data['minOrderValue'] ?? 0.0);
        final double minOrderVal = (minOrd is num) ? minOrd.toDouble() : double.tryParse(minOrd.toString()) ?? 0.0;
        if (minOrderVal > 0 && eligibleSubtotal < minOrderVal) {
          final double shortage = minOrderVal - eligibleSubtotal;
          return CouponApplyResult(
            isSuccess: false,
            message: 'Add ₹${shortage.toStringAsFixed(0)} more to use this offer.',
          );
        }

        // Requirement 5 & 6: Calculate percentage/fixed discount & Apply maximum discount cap
        final discountType = (data['discountType'] ?? data['type'] ?? '').toString().toUpperCase();
        final discountVal = (data['discountValue'] ?? data['discountPercentage'] ?? data['discount'] ?? 0.0);
        final double rawDisc = (discountVal is num) ? discountVal.toDouble() : double.tryParse(discountVal.toString()) ?? 0.0;
        final maxDisc = (data['maximumDiscountAmount'] ?? 0.0);
        final double maxDiscountCap = (maxDisc is num) ? maxDisc.toDouble() : double.tryParse(maxDisc.toString()) ?? 0.0;

        double finalDiscountAmount = 0.0;
        if (discountType == 'FIXED_AMOUNT' || discountType == 'FLAT' || (rawDisc >= 100.0 && discountType != 'PERCENTAGE')) {
          finalDiscountAmount = rawDisc.clamp(0.0, eligibleSubtotal);
        } else {
          // Percentage discount
          final pct = (rawDisc > 1.0) ? (rawDisc / 100.0) : rawDisc;
          finalDiscountAmount = eligibleSubtotal * pct;
          if (maxDiscountCap > 0 && finalDiscountAmount > maxDiscountCap) {
            finalDiscountAmount = maxDiscountCap;
          }
        }

        final double discountPctForCart = currentSubtotal > 0 ? (finalDiscountAmount / currentSubtotal) : 0.0;
        final appliedCodeName = rawCoupon.isNotEmpty ? rawCoupon : normalizedCode;

        state = state.copyWith(
          appliedCoupon: appliedCodeName,
          appliedOfferId: doc.id,
          discountPercentage: discountPctForCart,
          appliedCouponMinOrder: minOrderVal,
          appliedCouponExcludedProductIds: excludedProductIds,
          appliedCouponExcludedComboIds: excludedComboIds,
          appliedCouponExcludedComboProductIds: excludedComboProductIds,
          appliedDiscountType: discountType,
          appliedDiscountValue: rawDisc,
          appliedMaxDiscountCap: maxDiscountCap,
        );

        return CouponApplyResult(
          isSuccess: true,
          message: 'Coupon "$appliedCodeName" applied successfully!',
          appliedCode: appliedCodeName,
        );
      }
    } catch (e) {
      debugPrint('[CartNotifier] Error validating coupon in Firestore: $e');
    }

    return const CouponApplyResult(
      isSuccess: false,
      message: 'Invalid coupon code.',
    );
  }

  void applyRewardPoints(int points, double pointValue, {double? minOrderThreshold}) {
    if (points <= 0) {
      removeRewardPoints();
      return;
    }
    state = state.copyWith(
      appliedRewardPoints: points,
      pointValue: pointValue,
      appliedRewardMinOrder: minOrderThreshold ?? 0.0,
    );
    _revalidateDiscounts();
  }

  void removeRewardPoints() {
    state = state.copyWith(clearReward: true);
  }

  void removeCoupon() {
    state = state.copyWith(clearCoupon: true);
  }

  void clearCart() {
    state = const CartState(items: [], appliedCoupon: null, appliedOfferId: null, discountPercentage: 0.0, appliedRewardPoints: 0);
  }
}


final cartProvider = NotifierProvider<CartNotifier, CartState>(() {
  return CartNotifier();
});

// ==========================================
// FAVORITES STATE
// ==========================================
class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggleFavorite(String id) {
    if (state.contains(id)) {
      state = Set.from(state)..remove(id);
    } else {
      state = Set.from(state)..add(id);
    }
  }

  bool isFavorite(String id) => state.contains(id);
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(() {
  return FavoritesNotifier();
});

// Address state is re-exported from features/address/providers/address_provider.dart

// ==========================================
// ORDERS STATE (LEGACY IN-MEMORY FALLBACK)
// ==========================================
class OrdersNotifier extends Notifier<List<Order>> {
  @override
  List<Order> build() => [];

  void placeOrder(Order order) {
    state = [order, ...state.where((o) => o.id != order.id)];
  }

  void updateOrder(Order order) {
    state = state.map((o) => o.id == order.id ? order : o).toList();
  }

  void removeOrder(String orderId) {
    state = state.where((o) => o.id != orderId).toList();
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(() {
  return OrdersNotifier();
});
