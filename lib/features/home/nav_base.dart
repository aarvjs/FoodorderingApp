import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/services/state_providers.dart';
import 'widgets/app_drawer.dart';
import 'widgets/curved_nav_bar.dart';

class NavBase extends ConsumerStatefulWidget {
  final Widget child;

  const NavBase({super.key, required this.child});

  @override
  ConsumerState<NavBase> createState() => _NavBaseState();
}

class _NavBaseState extends ConsumerState<NavBase> {
  static const List<CurvedNavItem> _navItems = [
    CurvedNavItem(
      icon: Iconsax.home_1,
      activeIcon: Iconsax.home5,
      label: 'Home',
    ),
    CurvedNavItem(
      icon: Iconsax.search_normal_1,
      activeIcon: Iconsax.search_normal,
      label: 'Search',
    ),
    CurvedNavItem(
      icon: Iconsax.shopping_cart,
      activeIcon: Iconsax.shopping_cart,
      label: 'Cart',
    ),
    CurvedNavItem(
      icon: Iconsax.receipt_2,
      activeIcon: Iconsax.receipt_2,
      label: 'Orders',
    ),
    CurvedNavItem(
      icon: Iconsax.user,
      activeIcon: Iconsax.user,
      label: 'Profile',
    ),
  ];

  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/cart')) return 2;
    if (location.startsWith('/orders')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/cart');
        break;
      case 3:
        context.go('/orders');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cartState = ref.watch(cartProvider);
    final int cartCount = cartState.items.fold<int>(0, (sum, item) => sum + item.quantity);
    
    // Calculate system inset for gesture / 3-button navigation
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const double navBarWidgetHeight = 78.0;
    final double targetBottomPosition = 10.0 + bottomInset;

    // Adjust child MediaQuery padding so scrollable screens automatically add bottom padding
    final mediaQueryData = MediaQuery.of(context);
    final adjustedMediaQuery = mediaQueryData.copyWith(
      padding: mediaQueryData.padding.copyWith(
        bottom: navBarWidgetHeight + bottomInset + 12.0,
      ),
    );

    return Scaffold(
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // Active Screen Child Widget
          MediaQuery(
            data: adjustedMediaQuery,
            child: widget.child,
          ),

          // ── Static Floating Curved Bottom Nav Bar ──────────────────────
          Positioned(
            bottom: targetBottomPosition,
            left: 0,
            right: 0,
            child: Center(
              child: CurvedNavBar(
                selectedIndex: selectedIndex,
                onItemTapped: (index) => _onItemTapped(index, context),
                items: _navItems,
                isDark: isDark,
                cartCount: cartCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



