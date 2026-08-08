import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../auth/providers/auth_provider.dart';
import 'order_repository.dart';
import 'notification_repository.dart';
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
  return repo.streamCustomerOrders(userId);
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
  final double discountPercentage;

  const CartState({
    required this.items,
    this.appliedCoupon,
    this.discountPercentage = 0.0,
  });

  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + (item.foodItem.price * item.quantity));
  }

  double get couponDiscount {
    return subtotal * discountPercentage;
  }

  double get deliveryFee {
    if (items.isEmpty) return 0.0;
    return subtotal > 500 ? 0.0 : 40.0; // Free delivery above 500
  }

  double get gstTax {
    return subtotal * 0.05; // 5% GST
  }

  double get total {
    if (items.isEmpty) return 0.0;
    final calculated = subtotal - couponDiscount + deliveryFee + gstTax;
    return double.parse(calculated.toStringAsFixed(2));
  }

  CartState copyWith({
    List<CartItem>? items,
    String? appliedCoupon,
    double? discountPercentage,
    bool clearCoupon = false,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
      discountPercentage: clearCoupon ? 0.0 : (discountPercentage ?? this.discountPercentage),
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

  bool isDifferentRestaurant(String restaurantId) {
    return state.items.isNotEmpty && state.items.first.restaurantId != restaurantId;
  }

  void forceAddItem(CartItem item) {
    state = CartState(items: [item], appliedCoupon: null, discountPercentage: 0.0);
  }

  void addItem(CartItem item) {
    // If adding item from a different restaurant, reset cart
    if (state.items.isNotEmpty && state.items.first.restaurantId != item.restaurantId) {
      state = CartState(items: [item], appliedCoupon: null, discountPercentage: 0.0);
      return;
    }

    final index = state.items.indexWhere((i) {
      if (i.foodItem.id != item.foodItem.id) return false;
      if (i.selectedSize != item.selectedSize) return false;
      if (i.isCombo != item.isCombo) return false;
      if (i.isCombo) {
        final iCustoms = i.selectedCustomizations;
        final itemCustoms = item.selectedCustomizations;
        if (iCustoms.length != itemCustoms.length) return false;
        for (int k = 0; k < iCustoms.length; k++) {
          if (iCustoms[k] != itemCustoms[k]) return false;
        }
      }
      return true;
    });

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

  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }
    final updatedItems = state.items.map((item) {
      if (item.foodItem.id == itemId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updatedItems);
  }

  void removeItem(String itemId) {
    final updatedItems = state.items.where((item) => item.foodItem.id != itemId).toList();
    state = state.copyWith(items: updatedItems);
    if (updatedItems.isEmpty) {
      clearCart();
    }
  }

  Future<CouponApplyResult> applyOffer(dynamic offer) async {
    final code = (offer is String) ? offer : (offer.couponCode ?? '').toString();
    return applyCoupon(code);
  }

  Future<CouponApplyResult> applyCoupon(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return const CouponApplyResult(
        isSuccess: false,
        message: 'Please enter a coupon code.',
      );
    }

    // 1. Check legacy hardcoded coupons
    if (normalizedCode == 'WELCOME50') {
      state = state.copyWith(appliedCoupon: 'WELCOME50', discountPercentage: 0.50);
      return const CouponApplyResult(
        isSuccess: true,
        message: 'Coupon "WELCOME50" applied successfully!',
        appliedCode: 'WELCOME50',
      );
    } else if (normalizedCode == 'BINGE20') {
      state = state.copyWith(appliedCoupon: 'BINGE20', discountPercentage: 0.20);
      return const CouponApplyResult(
        isSuccess: true,
        message: 'Coupon "BINGE20" applied successfully!',
        appliedCode: 'BINGE20',
      );
    } else if (normalizedCode == 'FREEDEL') {
      state = state.copyWith(appliedCoupon: 'FREEDEL', discountPercentage: 0.05);
      return const CouponApplyResult(
        isSuccess: true,
        message: 'Coupon "FREEDEL" applied successfully!',
        appliedCode: 'FREEDEL',
      );
    }

    // 2. Validate against Firestore `offers` collection documents
    try {
      final snap = await FirebaseFirestore.instance.collection('offers').get();
      
      final currentRestId = state.items.isNotEmpty ? state.items.first.restaurantId.trim() : '';
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

        // Check active status
        final status = (data['status'] ?? 'ACTIVE').toString().toUpperCase();
        final bool isActive = (data['isActive'] != false) && status == 'ACTIVE';
        if (!isActive) {
          return const CouponApplyResult(
            isSuccess: false,
            message: 'This coupon is no longer active.',
          );
        }

        // Check Expiry Date
        final String? endDateStr = (data['endDate'] ?? data['validTill'])?.toString();
        if (endDateStr != null && endDateStr.isNotEmpty) {
          try {
            final expiryDate = DateTime.parse(endDateStr);
            if (now.isAfter(expiryDate.add(const Duration(days: 1)))) {
              return const CouponApplyResult(
                isSuccess: false,
                message: 'This coupon has expired.',
              );
            }
          } catch (_) {
            // Ignore invalid date parsing errors
          }
        }

        // Check Restaurant ID & Branch ID relation (if assigned)
        final String oRestId = (data['restaurantId'] ?? '').toString().trim();
        final String oBranchId = (data['branchId'] ?? '').toString().trim();

        if (currentRestId.isNotEmpty) {
          final bool isGlobalRest = oRestId.isEmpty || oRestId.toUpperCase() == 'ALL';
          final bool isGlobalBranch = oBranchId.isEmpty || oBranchId.toUpperCase() == 'ALL';
          final bool matchesRest = oRestId == currentRestId || oBranchId == currentRestId;

          if (!isGlobalRest && !isGlobalBranch && !matchesRest) {
            return const CouponApplyResult(
              isSuccess: false,
              message: 'This coupon is not valid for this restaurant.',
            );
          }
        }

        // Check Minimum Order Amount
        final minOrd = (data['minimumOrder'] ?? data['minOrderValue'] ?? 0.0);
        final double minOrderVal = (minOrd is num) ? minOrd.toDouble() : double.tryParse(minOrd.toString()) ?? 0.0;
        if (minOrderVal > 0 && currentSubtotal < minOrderVal) {
          return CouponApplyResult(
            isSuccess: false,
            message: 'Minimum order of ₹${minOrderVal.toStringAsFixed(0)} required to apply this coupon.',
          );
        }

        // Calculate discount percentage
        final discountType = (data['discountType'] ?? data['type'] ?? '').toString().toUpperCase();
        final discountVal = (data['discountPercentage'] ?? data['discount'] ?? 0.0);
        final double rawDisc = (discountVal is num) ? discountVal.toDouble() : double.tryParse(discountVal.toString()) ?? 0.0;

        double discountPct = 0.0;
        if (discountType == 'FLAT' || discountType == 'FLAT_DISCOUNT' || (rawDisc >= 100.0 && discountType != 'PERCENTAGE')) {
          if (rawDisc > 0 && currentSubtotal > 0) {
            discountPct = (rawDisc / currentSubtotal).clamp(0.0, 1.0);
          }
        } else if (rawDisc > 0 && rawDisc <= 1.0) {
          discountPct = rawDisc;
        } else if (rawDisc > 1.0 && rawDisc <= 100.0) {
          discountPct = rawDisc / 100.0;
        }

        final appliedCodeName = rawCoupon.isNotEmpty ? rawCoupon : normalizedCode;
        state = state.copyWith(appliedCoupon: appliedCodeName, discountPercentage: discountPct);
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
      discountPercentage: 0.0,
    );
  }

  void clearCart() {
    state = const CartState(items: [], appliedCoupon: null, discountPercentage: 0.0);
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
    state = [order, ...state];
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(() {
  return OrdersNotifier();
});
