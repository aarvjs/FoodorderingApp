import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_colors.dart';

class AnimatedSearchBar extends StatefulWidget {
  final bool isDark;
  final bool isPinned;

  const AnimatedSearchBar({
    super.key,
    required this.isDark,
    this.isPinned = false,
  });

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _placeholderIndex = 0;
  bool _micActive = false;

  final List<String> _placeholders = [
    'Search Pizza, Burger, Biryani...',
    'Try Cheese Burst Pizza 🍕',
    'Craving Chinese? 🍜',
    'Order Biryani Now 🥘',
    'Cold Coffee or Frappe? ☕',
    'Mexican Fiesta tonight? 🌮',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Cycle placeholders
    Future.delayed(const Duration(seconds: 3), _cyclePlaceholder);
  }

  void _cyclePlaceholder() {
    if (!mounted) return;
    setState(() {
      _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
    });
    Future.delayed(const Duration(seconds: 3), _cyclePlaceholder);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isPinned = widget.isPinned;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: EdgeInsets.symmetric(
        horizontal: isPinned ? 12 : 16,
        vertical: isPinned ? 6 : 8,
      ),
      child: GestureDetector(
        onTap: () => context.go('/search'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isPinned
                    ? (isDark
                        ? const Color(0xFF1E1E1E).withOpacity(0.97)
                        : Colors.white.withOpacity(0.97))
                    : (isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.white.withOpacity(0.85)),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isPinned
                      ? (isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.grey.shade200)
                      : Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isPinned
                        ? Colors.black.withOpacity(0.08)
                        : AppColors.primary.withOpacity(0.12),
                    blurRadius: isPinned ? 8 : 20,
                    spreadRadius: isPinned ? 0 : -2,
                    offset: const Offset(0, 4),
                  ),
                  if (!isPinned)
                    BoxShadow(
                      color: Colors.white.withOpacity(0.6),
                      blurRadius: 1,
                      offset: const Offset(0, -1),
                    ),
                ],
              ),
              child: Row(
                children: [
                  // Search icon with animation
                  Icon(
                    Iconsax.search_normal_1,
                    size: 20,
                    color: isDark
                        ? Colors.grey.shade400
                        : AppColors.primary.withOpacity(0.7),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.1, 1.1),
                        duration: 2000.ms,
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(width: 12),
                  // Animated placeholder
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _placeholders[_placeholderIndex],
                        key: ValueKey(_placeholderIndex),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey.shade500
                              : AppColors.textLight,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  // Voice mic with pulse
                  GestureDetector(
                    onTap: () => setState(() => _micActive = !_micActive),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(
                                    0.3 + _pulseController.value * 0.25),
                                blurRadius: 8 + _pulseController.value * 8,
                                spreadRadius: _pulseController.value * 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Iconsax.microphone_2,
                            size: 16,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut);
  }
}

// Sticky delegate for the search bar
class StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;

  StickySearchBarDelegate({required this.isDark});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isPinned = shrinkOffset > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isPinned
          ? (isDark
              ? const Color(0xFF0F0F0F).withOpacity(0.95)
              : Colors.white.withOpacity(0.95))
          : Colors.transparent,
      child: AnimatedSearchBar(isDark: isDark, isPinned: isPinned),
    );
  }

  @override
  double get maxExtent => 72;

  @override
  double get minExtent => 72;

  @override
  bool shouldRebuild(covariant StickySearchBarDelegate oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
