import 'package:flutter/material.dart';
import '../../../core/config/app_colors.dart';

class CurvedNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const CurvedNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class CurvedNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final List<CurvedNavItem> items;
  final bool isDark;
  final int cartCount;

  const CurvedNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.items,
    required this.isDark,
    this.cartCount = 0,
  });

  Widget _buildIconWithBadge({
    required IconData iconData,
    Key? key,
    required Color color,
    required double size,
    required bool showBadge,
    required int count,
  }) {
    final iconWidget = Icon(
      iconData,
      key: key,
      color: color,
      size: size,
    );

    if (!showBadge) return iconWidget;

    final badgeString = count > 99 ? '99+' : '$count';

    return Badge(
      label: Text(
        badgeString,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: const Color(0xFFFF3B30),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      offset: const Offset(6, -6),
      child: iconWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    // Calculate horizontal padding to ensure navbar stays floating & responsive
    final double hMargin = screenWidth > 600 ? screenWidth * 0.12 : 16.0;
    final double barWidth = screenWidth - (hMargin * 2);
    final double itemWidth = barWidth / items.length;

    const double barHeight = 62.0;
    const double topOffset = 16.0; // Space for rising active circle
    const double totalHeight = barHeight + topOffset;
    const double circleSize = 52.0;

    // Target center X of the selected item
    final double targetX = itemWidth * selectedIndex + (itemWidth / 2);

    final Color bgColor = isDark
        ? AppColors.darkCard.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.96);
    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.8);
    final Color activeBlue = isDark ? AppColors.darkPrimary : AppColors.primary;
    final Color inactiveColor =
        isDark ? Colors.grey.shade400 : const Color(0xFF8E9BAB);

    return SizedBox(
      width: barWidth,
      height: totalHeight,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: targetX, end: targetX),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        builder: (context, notchX, child) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // ── 1. Curved Background Container ────────────────────────────
              Positioned(
                top: topOffset,
                left: 0,
                right: 0,
                height: barHeight,
                child: CustomPaint(
                  painter: CurvedNavPainter(
                    notchX: notchX,
                    color: bgColor,
                    borderColor: borderColor,
                    isDark: isDark,
                  ),
                ),
              ),

              // ── 2. Floating Active Circular Button ────────────────────────
              Positioned(
                top: 0,
                left: notchX - (circleSize / 2),
                width: circleSize,
                height: circleSize,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: activeBlue.withValues(alpha: 0.38),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: activeBlue.withValues(alpha: 0.18),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: child,
                        );
                      },
                      child: _buildIconWithBadge(
                        iconData: items[selectedIndex].activeIcon,
                        key: ValueKey<int>(selectedIndex),
                        color: Colors.white,
                        size: 25,
                        showBadge: selectedIndex == 2 && cartCount > 0,
                        count: cartCount,
                      ),
                    ),
                  ),
                ),
              ),

              // ── 3. Navigation Items Row ──────────────────────────────────
              Positioned(
                top: topOffset,
                left: 0,
                right: 0,
                height: barHeight,
                child: Row(
                  children: List.generate(items.length, (index) {
                    final isSelected = index == selectedIndex;
                    final item = items[index];

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onItemTapped(index),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          alignment: Alignment.center,
                          child: isSelected
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Active Label underneath the dip
                                    Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: activeBlue,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Small active dot indicator
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: activeBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 4),
                                    _buildIconWithBadge(
                                      iconData: item.icon,
                                      color: inactiveColor,
                                      size: 22,
                                      showBadge: index == 2 && cartCount > 0,
                                      count: cartCount,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: inactiveColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CurvedNavPainter extends CustomPainter {
  final double notchX;
  final Color color;
  final Color borderColor;
  final bool isDark;

  CurvedNavPainter({
    required this.notchX,
    required this.color,
    required this.borderColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final shadowPaint = Paint()
      ..color = isDark
          ? Colors.black.withValues(alpha: 0.35)
          : Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    const double cornerRadius = 26.0;
    const double dipDepth = 20.0;
    const double dipHalfWidth = 36.0;

    final path = Path();
    path.moveTo(cornerRadius, 0);

    // Smooth concave notch around notchX
    path.lineTo(notchX - dipHalfWidth - 8, 0);
    path.cubicTo(
      notchX - dipHalfWidth + 10,
      0,
      notchX - dipHalfWidth + 12,
      dipDepth,
      notchX,
      dipDepth,
    );
    path.cubicTo(
      notchX + dipHalfWidth - 12,
      dipDepth,
      notchX + dipHalfWidth - 10,
      0,
      notchX + dipHalfWidth + 8,
      0,
    );

    path.lineTo(size.width - cornerRadius, 0);
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: const Radius.circular(cornerRadius),
    );
    path.lineTo(size.width, size.height - cornerRadius);
    path.arcToPoint(
      Offset(size.width - cornerRadius, size.height),
      radius: const Radius.circular(cornerRadius),
    );
    path.lineTo(cornerRadius, size.height);
    path.arcToPoint(
      Offset(0, size.height - cornerRadius),
      radius: const Radius.circular(cornerRadius),
    );
    path.lineTo(0, cornerRadius);
    path.arcToPoint(
      const Offset(cornerRadius, 0),
      radius: const Radius.circular(cornerRadius),
    );
    path.close();

    // Draw outer elevation shadow
    canvas.save();
    canvas.translate(0, 5);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Draw white/dark rounded container fill
    canvas.drawPath(path, paint);

    // Draw subtle border line
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CurvedNavPainter oldDelegate) {
    return oldDelegate.notchX != notchX ||
        oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.isDark != isDark;
  }
}
