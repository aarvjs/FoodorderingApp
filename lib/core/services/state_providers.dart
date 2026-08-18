import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/cart_item.dart';
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
    for (final order in orders) {
      if (order.isCompleted || order.status.toUpperCase() == 'DELIVERED') {
        rewardRepo.awardPointsForOrder(order);
      }
    }
    return orders;
  });
});


final userNotificationsStreamProvider = StreamProvider<List<AppNotificationModel>>((ref) {
  final authState = ref.watch(authProvider);
  final userId = authState.userModel?.uid ?? '';
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.streamCustomerNotifications(userId);
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
  final double? overrideDeliveryFee;
  final double taxPercentage;

  const CartState({
    required this.items,
    this.appliedCoupon,
    this.appliedOfferId,
    this.discountPercentage = 0.0,
    this.overrideDeliveryFee,
    this.taxPercentage = 0.0,
  });

  double get subtotal {
    return items.fold(0.0, (total, item) => total + (item.foodItem.price * item.quantity));
  }

  double get couponDiscount {
    return subtotal * discountPercentage;
  }

  double get deliveryFee {
    if (items.isEmpty) return 0.0;
    if (overrideDeliveryFee != null) return overrideDeliveryFee!;
    return subtotal > 500 ? 0.0 : 40.0; // Fallback
  }

  double get gstTax {
    if (items.isEmpty || taxPercentage <= 0) return 0.0;
    final taxableAmount = subtotal - couponDiscount;
    if (taxableAmount <= 0) return 0.0;
    return taxableAmount * (taxPercentage / 100.0);
  }

  double get total {
    if (items.isEmpty) return 0.0;
    final calculated = subtotal - couponDiscount + deliveryFee + gstTax;
    return double.parse(calculated.toStringAsFixed(2));
  }

  CartState copyWith({
    List<CartItem>? items,
    String? appliedCoupon,
    String? appliedOfferId,
    double? discountPercentage,
    double? overrideDeliveryFee,
    double? taxPercentage,
    bool clearCoupon = false,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
      appliedOfferId: clearCoupon ? null : (appliedOfferId ?? this.appliedOfferId),
      discountPercentage: clearCoupon ? 0.0 : (discountPercentage ?? this.discountPercentage),
      overrideDeliveryFee: overrideDeliveryFee ?? this.overrideDeliveryFee,
      taxPercentage: taxPercentage ?? this.taxPercentage,
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
  CartState build() => const CartState(items: []);

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
  }

  void removeItemAtIndex(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updatedItems = List<CartItem>.from(state.items)..removeAt(index);
    state = state.copyWith(items: updatedItems);
    if (updatedItems.isEmpty) {
      clearCart();
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
      }
    }
  }

  Future<CouponApplyResult> applyOffer(dynamic offer) async {
    final code = (offer is String) ? offer : (offer.couponCode ?? '').toString();
    return applyCoupon(code);
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

  Future<CouponApplyResult> applyCoupon(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
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

    // 2. Validate against Firestore `offers` collection documents
    try {
      final snap = await FirebaseFirestore.instance.collection('offers').get();
      
      final currentRestId = state.items.first.restaurantId.trim();
      final currentBranchId = (state.items.first.foodItem.branchId ?? '').trim();
      final currentSubtotal = state.subtotal;
      final now = DateTime.now();

      for (var doc in snap.docs) {
        final data = doc.data();
        
        // Coupon code field (supports 'coupon', 'couponCode', 'code', or 'OFFER' fallback)
        final rawCoupon = (data['coupon'] ?? data['couponCode'] ?? data['code'] ?? '').toString().trim().toUpperCase();
        final fallbackCoupon = 'OFFER${doc.id.substring(0, doc.id.length > 4 ? 4 : doc.id.length).toUpperCase()}';
        
        final matchCode = (rawCoupon.isNotEmpty && rawCoupon == normalizedCode) ||
            (fallbackCoupon == normalizedCode);

        if (!matchCode) continue;

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

        // Requirement 2: Has usage limit been reached?
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

        // Check Restaurant ID & Branch ID scope
        final String oRestId = (data['restaurantId'] ?? '').toString().trim();
        final String oBranchId = (data['branchId'] ?? '').toString().trim();

        if (currentRestId.isNotEmpty) {
          final bool isGlobalRest = oRestId.isEmpty || oRestId.toUpperCase() == 'ALL';
          final bool isGlobalBranch = oBranchId.isEmpty || oBranchId.toUpperCase() == 'ALL';
          final bool matchesRest = oRestId == currentRestId || oBranchId == currentRestId || oBranchId == currentBranchId;

          if (!isGlobalRest && !isGlobalBranch && !matchesRest) {
            return const CouponApplyResult(
              isSuccess: false,
              message: 'This offer is not valid for this restaurant branch.',
            );
          }
        }

        // Requirement 7: Exclude Categories check & calculate eligible subtotal
        final rawExcluded = data['excludedCategoryIds'];
        List<String> excludedCatList = [];
        if (rawExcluded is List) {
          excludedCatList = rawExcluded.map((e) => e.toString().trim().toUpperCase()).toList();
        }

        double eligibleSubtotal = 0.0;
        for (final item in state.items) {
          final itemCat = item.foodItem.category.trim().toUpperCase();
          final itemId = item.foodItem.id.trim().toUpperCase();
          final bool isExcluded = excludedCatList.contains(itemCat) || excludedCatList.contains(itemId);
          if (!isExcluded) {
            eligibleSubtotal += item.foodItem.price * item.quantity;
          }
        }

        if (eligibleSubtotal <= 0) {
          return const CouponApplyResult(
            isSuccess: false,
            message: 'Items in your cart belong to excluded categories for this offer.',
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

  void removeCoupon() {
    state = CartState(
      items: state.items,
      appliedCoupon: null,
      appliedOfferId: null,
      discountPercentage: 0.0,
    );
  }

  void clearCart() {
    state = const CartState(items: [], appliedCoupon: null, appliedOfferId: null, discountPercentage: 0.0);
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
