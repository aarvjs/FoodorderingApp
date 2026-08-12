import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/config/app_colors.dart';
import '../providers/restaurant_providers.dart';
import 'offer_badge.dart';

class BannerData {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String ctaText;
  final OfferBadgeType badgeType;
  final List<Color> accentColors;

  const BannerData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.ctaText,
    required this.badgeType,
    required this.accentColors,
  });
}

class HeroBannerCarousel extends ConsumerStatefulWidget {
  final bool isDark;

  const HeroBannerCarousel({super.key, required this.isDark});

  @override
  ConsumerState<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends ConsumerState<HeroBannerCarousel> {
  int _currentIndex = 0;
  final CarouselSliderController _controller = CarouselSliderController();

  static final List<BannerData> _defaultBanners = [
    const BannerData(
      title: '🍕 BUY 1 GET 1 FREE\non Large Pizzas',
      subtitle: 'Freshly baked gourmet pizzas delivered hot to your door!',
      imageUrl: 'assets/images/perfect_pizza_banner1.png',
      ctaText: 'Order Now',
      badgeType: OfferBadgeType.buy1get1,
      accentColors: [Color(0xFF0879C9), Color(0xFF005B9F)],
    ),
    const BannerData(
      title: '🍔 SUPER COMBO DEALS\nFlat 40% OFF',
      subtitle: 'Family pizza combos with garlic bread & chilled drinks',
      imageUrl: 'assets/images/perfect_pizza_banner2.png',
      ctaText: 'Grab Deal',
      badgeType: OfferBadgeType.flat50,
      accentColors: [Color(0xFF0879C9), Color(0xFF005B9F)],
    ),
    const BannerData(
      title: '🧀 CHEEZY DELIGHTS\nFree Delivery',
      subtitle: 'Ultra cheesy pizzas delivered free on orders above ₹299',
      imageUrl: 'assets/images/perfect_pizza_banner3.png',
      ctaText: 'Explore Menu',
      badgeType: OfferBadgeType.freeDelivery,
      accentColors: [Color(0xFF0879C9), Color(0xFF005B9F)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(offersStreamProvider);

    List<BannerData> bannersList = _defaultBanners;
    offersAsync.whenData((offers) {
      final validFirestoreOffers = offers
          .where((o) => o.bannerUrl.isNotEmpty && !o.bannerUrl.contains('unsplash.com'))
          .map((o) => BannerData(
                title: o.title,
                subtitle: o.description,
                imageUrl: o.bannerUrl,
                ctaText: o.ctaText,
                badgeType: o.badgeType,
                accentColors: o.accentColors,
              ))
          .toList();
      if (validFirestoreOffers.isNotEmpty) {
        bannersList = [..._defaultBanners, ...validFirestoreOffers];
      }
    });

    return Column(
      children: [
        CarouselSlider.builder(
          carouselController: _controller,
          itemCount: bannersList.length,
          itemBuilder: (context, index, realIndex) {
            final banner = bannersList[index % bannersList.length];
            final isActive = _currentIndex == index;

            return _BannerCard(
              banner: banner,
              isActive: isActive,
            );
          },
          options: CarouselOptions(
            height: 240,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            enlargeFactor: 0.15,
            viewportFraction: 0.88,
            onPageChanged: (index, reason) {
              setState(() => _currentIndex = index);
            },
          ),
        ),
        const SizedBox(height: 14),
        // Animated morphing indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(bannersList.length, (index) {
            final isActive = _currentIndex == index;
            return GestureDetector(
              onTap: () => _controller.animateToPage(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: isActive ? 24 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        )
                      : null,
                  color: isActive
                      ? null
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            );
          }),
        ),
      ],
    ).animate().fadeIn(duration: 700.ms, delay: 100.ms);
  }
}

class _BannerCard extends StatefulWidget {
  final BannerData banner;
  final bool isActive;

  const _BannerCard({required this.banner, required this.isActive});

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _zoomController;
  late Animation<double> _zoomAnim;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _zoomAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOut),
    );
    if (widget.isActive) _zoomController.forward();
  }

  @override
  void didUpdateWidget(_BannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _zoomController.forward(from: 0);
    } else if (!widget.isActive) {
      _zoomController.stop();
    }
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.banner;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ken Burns zoom image
            AnimatedBuilder(
              animation: _zoomAnim,
              builder: (context, child) {
                return Transform.scale(
                  scale: _zoomAnim.value,
                  child: child,
                );
              },
              child: banner.imageUrl.startsWith('assets/')
                  ? Image.asset(
                      banner.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: banner.accentColors),
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: banner.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey.shade800,
                        highlightColor: Colors.grey.shade600,
                        child: Container(color: Colors.grey.shade800),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: banner.accentColors,
                          ),
                        ),
                      ),
                    ),
            ),

            // Cinematic gradient overlay — bottom-heavy
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      banner.accentColors.first.withOpacity(0.85),
                      banner.accentColors.last.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Top-right vignette
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                    center: Alignment.topRight,
                    radius: 1.2,
                  ),
                ),
              ),
            ),

            // Content layer
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Offer badge
                  OfferBadge(type: banner.badgeType, fontSize: 9),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    banner.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    banner.subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // CTA Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          banner.ctaText,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: banner.accentColors.first,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: banner.accentColors.first,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
