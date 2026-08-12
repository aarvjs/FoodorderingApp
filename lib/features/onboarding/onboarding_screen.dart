import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Data model ────────────────────────────────────────────────────────────
class _FloatingItem {
  final String emoji;
  final double topFrac; // 0..1 fraction of screen height
  final double leftFrac; // 0..1 fraction of screen width
  final double scale;
  final double phaseOffset;

  const _FloatingItem({
    required this.emoji,
    required this.topFrac,
    required this.leftFrac,
    required this.scale,
    this.phaseOffset = 0.0,
  });
}

class _SlideData {
  final String title;
  final String subtitle;
  final String imageUrl;
  final List<Color> gradientColors;
  final List<_FloatingItem> floatingItems;

  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.gradientColors,
    required this.floatingItems,
  });
}

const List<_SlideData> _kSlides = [
  // ─── Screen 1: Food ────────────────────────────────────────────────────
  _SlideData(
    title: 'Delicious Food\nDelivered Fast',
    subtitle:
        'Hot pizza, cheesy burgers and crispy fries cooked fresh and delivered to your door in minutes.',
    imageUrl:
        'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=900&q=90&auto=format&fit=crop',
    gradientColors: [Color(0xFFFF6B35), Color(0xFFFF4D4F), Color(0xFF7C0A02)],
    floatingItems: [
      _FloatingItem(emoji: '🍕', topFrac: 0.06, leftFrac: 0.03, scale: 1.7, phaseOffset: 0.0),
      _FloatingItem(emoji: '🍔', topFrac: 0.10, leftFrac: 0.73, scale: 1.5, phaseOffset: 0.3),
      _FloatingItem(emoji: '🍟', topFrac: 0.29, leftFrac: 0.83, scale: 1.2, phaseOffset: 0.6),
      _FloatingItem(emoji: '🧅', topFrac: 0.24, leftFrac: 0.01, scale: 0.95, phaseOffset: 0.2),
      _FloatingItem(emoji: '🧀', topFrac: 0.54, leftFrac: 0.00, scale: 1.0, phaseOffset: 0.8),
      _FloatingItem(emoji: '🌿', topFrac: 0.50, leftFrac: 0.85, scale: 0.85, phaseOffset: 0.5),
      _FloatingItem(emoji: '🍅', topFrac: 0.40, leftFrac: 0.76, scale: 0.75, phaseOffset: 0.4),
    ],
  ),
  // ─── Screen 2: Live tracking ────────────────────────────────────────────
  _SlideData(
    title: 'Track Your\nOrder Live',
    subtitle:
        'Watch your Perfect Pizza rider on the map in real-time. Know exactly when your hot pizza will arrive at your door.',
    imageUrl: 'assets/images/perfect_pizza_onboarding2.png',
    gradientColors: [Color(0xFF0879C9), Color(0xFF005B9F), Color(0xFF003865)],
    floatingItems: [
      _FloatingItem(emoji: '🍕', topFrac: 0.07, leftFrac: 0.03, scale: 1.8, phaseOffset: 0.0),
      _FloatingItem(emoji: '🛵', topFrac: 0.10, leftFrac: 0.71, scale: 1.45, phaseOffset: 0.35),
      _FloatingItem(emoji: '📍', topFrac: 0.30, leftFrac: 0.81, scale: 1.15, phaseOffset: 0.6),
      _FloatingItem(emoji: '⚡', topFrac: 0.22, leftFrac: 0.01, scale: 0.95, phaseOffset: 0.2),
      _FloatingItem(emoji: '📦', topFrac: 0.48, leftFrac: 0.83, scale: 0.95, phaseOffset: 0.5),
      _FloatingItem(emoji: '🏠', topFrac: 0.54, leftFrac: 0.01, scale: 1.15, phaseOffset: 0.7),
      _FloatingItem(emoji: '✅', topFrac: 0.40, leftFrac: 0.73, scale: 0.85, phaseOffset: 0.3),
    ],
  ),
  // ─── Screen 3: Best restaurants ─────────────────────────────────────────
  _SlideData(
    title: 'Enjoy Food From\nThe Best Restaurants',
    subtitle:
        'Discover handpicked premium dining and street food with your family — with massive exclusive discounts.',
    imageUrl:
        'https://images.unsplash.com/photo-1544025162-d76694265947?w=900&q=90&auto=format&fit=crop',
    gradientColors: [Color(0xFF11998E), Color(0xFF38EF7D), Color(0xFF0A4A30)],
    floatingItems: [
      _FloatingItem(emoji: '🍽️', topFrac: 0.06, leftFrac: 0.03, scale: 1.7, phaseOffset: 0.0),
      _FloatingItem(emoji: '👨‍👩‍👧', topFrac: 0.09, leftFrac: 0.68, scale: 1.55, phaseOffset: 0.3),
      _FloatingItem(emoji: '🏪', topFrac: 0.28, leftFrac: 0.81, scale: 1.25, phaseOffset: 0.6),
      _FloatingItem(emoji: '⭐', topFrac: 0.22, leftFrac: 0.01, scale: 1.05, phaseOffset: 0.2),
      _FloatingItem(emoji: '🎁', topFrac: 0.50, leftFrac: 0.84, scale: 0.95, phaseOffset: 0.5),
      _FloatingItem(emoji: '🥘', topFrac: 0.53, leftFrac: 0.00, scale: 1.15, phaseOffset: 0.8),
      _FloatingItem(emoji: '💯', topFrac: 0.40, leftFrac: 0.74, scale: 0.85, phaseOffset: 0.4),
    ],
  ),
];

// ─── Main Screen ─────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_install', false);
    if (mounted) {
      context.go('/login');
    }
  }

  void _goNext() {
    if (_currentPage < _kSlides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final slide = _kSlides[_currentPage];

    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background (animates on page change) ─────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: slide.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative rings ─────────────────────────────────────────────
          Positioned(
            top: -size.width * 0.28,
            right: -size.width * 0.18,
            child: Container(
              width: size.width * 0.72,
              height: size.width * 0.72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.12,
            left: -size.width * 0.12,
            child: Container(
              width: size.width * 0.50,
              height: size.width * 0.50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // ── Floating emojis ──────────────────────────────────────────────
          ...slide.floatingItems.map((item) {
            return Positioned(
              top: item.topFrac * size.height,
              left: item.leftFrac * size.width,
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (_, child) {
                  final t = (_floatController.value + item.phaseOffset) % 1.0;
                  final dy = math.sin(t * math.pi) * 14.0;
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: Opacity(
                      opacity: 0.55 + 0.35 * math.sin(t * math.pi),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  item.emoji,
                  style: TextStyle(fontSize: 26 * item.scale),
                ),
              ),
            );
          }),

          // ── PageView ─────────────────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _kSlides.length,
            itemBuilder: (context, index) =>
                _SlidePage(slide: _kSlides[index], size: size, index: index),
          ),

          // ── Skip button ──────────────────────────────────────────────────
          SafeArea(
            child: AnimatedOpacity(
              opacity: _currentPage < _kSlides.length - 1 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: GestureDetector(
                    onTap: _finishOnboarding,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom bar ───────────────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    28, 0, 28, math.max(24, size.height * 0.04)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: _kSlides.length,
                      effect: WormEffect(
                        activeDotColor: Colors.white,
                        dotColor: Colors.white.withOpacity(0.3),
                        dotHeight: 8,
                        dotWidth: 8,
                        spacing: 8,
                        type: WormType.thinUnderground,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: _currentPage == _kSlides.length - 1
                          ? _GetStartedBtn(
                              key: const ValueKey('gs'),
                              onTap: _goNext)
                          : _NextBtn(
                              key: const ValueKey('next'),
                              onTap: _goNext),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Slide page content ───────────────────────────────────────────────────────
class _SlidePage extends StatelessWidget {
  final _SlideData slide;
  final Size size;
  final int index;

  const _SlidePage({
    required this.slide,
    required this.size,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Gap(64), // clearance for skip button

          // ── Hero image ─────────────────────────────────────────────────
          Expanded(
            flex: 11,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    slide.imageUrl.startsWith('assets/')
                        ? Image.asset(
                            slide.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: slide.gradientColors),
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: slide.imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: slide.gradientColors),
                              ),
                            ),
                          ),
                    // Bottom gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              slide.gradientColors.last.withOpacity(0.65),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Glass border
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
              .animate(key: ValueKey('img_$index'))
              .scale(
                  begin: const Offset(0.88, 0.88),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.easeOutBack)
              .fade(duration: 450.ms),

          const Gap(32),

          // ── Text ───────────────────────────────────────────────────────
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Slide badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${index + 1} of ${_kSlides.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  )
                      .animate(key: ValueKey('badge_$index'))
                      .fadeIn(duration: 400.ms, delay: 80.ms),

                  const Gap(10),

                  Text(
                    slide.title,
                    style: GoogleFonts.poppins(
                      fontSize: size.width < 360 ? 24 : 28,
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  )
                      .animate(key: ValueKey('title_$index'))
                      .fadeIn(duration: 500.ms, delay: 130.ms)
                      .slideY(
                          begin: 0.18,
                          end: 0,
                          duration: 500.ms,
                          delay: 130.ms,
                          curve: Curves.easeOut),

                  const Gap(10),

                  Text(
                    slide.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.75),
                      height: 1.55,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  )
                      .animate(key: ValueKey('sub_$index'))
                      .fadeIn(duration: 500.ms, delay: 220.ms)
                      .slideY(
                          begin: 0.18,
                          end: 0,
                          duration: 500.ms,
                          delay: 220.ms,
                          curve: Curves.easeOut),
                ],
              ),
            ),
          ),

          // Space for bottom bar
          const Gap(88),
        ],
      ),
    );
  }
}

// ─── Next arrow button ────────────────────────────────────────────────────────
class _NextBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _NextBtn({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_forward_rounded,
            color: Colors.black87, size: 24),
      ),
    );
  }
}

// ─── Get Started button ───────────────────────────────────────────────────────
class _GetStartedBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _GetStartedBtn({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Get Started',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const Gap(8),
            const Icon(Icons.arrow_forward_rounded,
                size: 18, color: Colors.black87),
          ],
        ),
      ),
    );
  }
}
