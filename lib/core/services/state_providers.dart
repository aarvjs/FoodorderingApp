import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/cart_item.dart';
import '../../models/address.dart';
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
  }) {
    return CartState(
      items: items ?? this.items,
      appliedCoupon: appliedCoupon ?? this.appliedCoupon,
      discountPercentage: discountPercentage ?? this.discountPercentage,
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState(items: []);

  bool isDifferentRestaurant(String restaurantId) {
    return state.items.isNotEmpty && state.items.first.restaurantId != restaurantId;
  }

  void forceAddItem(CartItem item) {
    state = CartState(items: [item]);
  }

  void addItem(CartItem item) {
    // If adding item from a different restaurant, reset cart
    if (state.items.isNotEmpty && state.items.first.restaurantId != item.restaurantId) {
      state = CartState(items: [item]);
      return;
    }

    final index = state.items.indexWhere(
      (i) => i.foodItem.id == item.foodItem.id && i.selectedSize == item.selectedSize,
    );

    if (index >= 0) {
      final updatedItems = List<CartItem>.from(state.items);
      final currentQuantity = updatedItems[index].quantity;
      updatedItems[index] = updatedItems[index].copyWith(quantity: currentQuantity + item.quantity);
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

  bool applyCoupon(String code) {
    if (code.trim().toUpperCase() == 'WELCOME50') {
      state = state.copyWith(appliedCoupon: 'WELCOME50', discountPercentage: 0.50);
      return true;
    } else if (code.trim().toUpperCase() == 'BINGE20') {
      state = state.copyWith(appliedCoupon: 'BINGE20', discountPercentage: 0.20);
      return true;
    } else if (code.trim().toUpperCase() == 'FREEDEL') {
      state = state.copyWith(appliedCoupon: 'FREEDEL', discountPercentage: 0.05); // dummy 5% off
      return true;
    }
    return false;
  }

  void removeCoupon() {
    state = state.copyWith(appliedCoupon: null, discountPercentage: 0.0);
  }

  void clearCart() {
    state = const CartState(items: []);
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
