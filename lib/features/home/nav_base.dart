import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/config/app_colors.dart';
import 'widgets/app_drawer.dart';

class NavBase extends StatefulWidget {
  final Widget child;

  const NavBase({super.key, required this.child});

  @override
  State<NavBase> createState() => _NavBaseState();
}

class _NavBaseState extends State<NavBase> with SingleTickerProviderStateMixin {
  bool _isNavbarVisible = true;
  late AnimationController _hideController;

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
  void initState() {
    super.initState();
    _hideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _hideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    // Responsive horizontal padding
    final hPad = size.width > 600 ? size.width * 0.1 : 20.0;

    return Scaffold(
      drawer: const AppDrawer(),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse) {
            if (_isNavbarVisible) {
              setState(() => _isNavbarVisible = false);
              _hideController.forward();
            }
          } else if (notification.direction == ScrollDirection.forward) {
            if (!_isNavbarVisible) {
              setState(() => _isNavbarVisible = true);
              _hideController.reverse();
            }
          }
          return true;
        },
        child: Stack(
          children: [
            widget.child,

            // ── Floating Bottom Nav Bar ────────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              bottom: _isNavbarVisible ? 20 : -100,
              left: hPad,
              right: hPad,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    height: 68,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard.withOpacity(0.82)
                          : Colors.white.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.09)
                            : Colors.white.withOpacity(0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.10),
                          blurRadius: 28,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          index: 0,
                          icon: Iconsax.home_1,
                          activeIcon: Iconsax.home5,
                          label: 'Home',
                          isSelected: selectedIndex == 0,
                          isDark: isDark,
                        ),
                        _buildNavItem(
                          index: 1,
                          icon: Iconsax.search_normal_1,
                          activeIcon: Iconsax.search_normal,
                          label: 'Search',
                          isSelected: selectedIndex == 1,
                          isDark: isDark,
                        ),
                        _buildNavItem(
                          index: 2,
                          icon: Iconsax.shopping_cart,
                          activeIcon: Iconsax.shopping_cart,
                          label: 'Cart',
                          isSelected: selectedIndex == 2,
                          isDark: isDark,
                        ),
                        _buildNavItem(
                          index: 3,
                          icon: Iconsax.receipt_2,
                          activeIcon: Iconsax.receipt_2,
                          label: 'Orders',
                          isSelected: selectedIndex == 3,
                          isDark: isDark,
                        ),
                        _buildNavItem(
                          index: 4,
                          icon: Iconsax.user,
                          activeIcon: Iconsax.user,
                          label: 'Profile',
                          isSelected: selectedIndex == 4,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    final activeColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final inactiveColor =
        isDark ? Colors.grey.shade500 : const Color(0xFFAAAAAA);

    return GestureDetector(
      onTap: () => _onItemTapped(index, context),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? AppColors.darkPrimary.withOpacity(0.14)
                  : AppColors.primary.withOpacity(0.09))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
