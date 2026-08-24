import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_colors.dart';
import '../../../models/restaurant.dart';
import '../providers/restaurant_providers.dart';

import 'offer_badge.dart';

class BannerData {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String ctaText;
  final String actionType;
  final String targetBranchId;
  final String targetRestaurantId;
  final OfferBadgeType badgeType;
  final List<Color> accentColors;

  const BannerData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.ctaText,
    this.actionType = 'ORDER_NOW',
    this.targetBranchId = '',
    this.targetRestaurantId = '',
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
      imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&q=80&auto=format&fit=crop',
      ctaText: 'Order Now',
      actionType: 'ORDER_NOW',
      badgeType: OfferBadgeType.buy1get1,
      accentColors: [Color(0xFF0879C9), Color(0xFF005B9F)],
    ),
    const BannerData(
      title: '🍔 SUPER COMBO DEALS\nFlat 40% OFF',
      subtitle: 'Family pizza combos with garlic bread & chilled drinks',
      imageUrl: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800&q=80&auto=format&fit=crop',
      ctaText: 'Grab Deal',
      actionType: 'GRAB_DEAL',
      badgeType: OfferBadgeType.flat50,
      accentColors: [Color(0xFF0879C9), Color(0xFF005B9F)],
    ),
    const BannerData(
      title: '🧀 CHEEZY DELIGHTS\nFree Delivery',
      subtitle: 'Ultra cheesy pizzas delivered free on orders above ₹299',
      imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80&auto=format&fit=crop',
      ctaText: 'Explore Menu',
      actionType: 'EXPLORE_MENU',
      badgeType: OfferBadgeType.freeDelivery,
      accentColors: [Color(0xFF0879C9), Color(0xFF005B9F)],
    ),
  ];

  void _handleBannerTap(BuildContext context, BannerData banner, Restaurant? nearestRestaurant) {
    final String targetId = banner.targetBranchId.isNotEmpty
        ? banner.targetBranchId
        : (banner.targetRestaurantId.isNotEmpty
            ? banner.targetRestaurantId
            : (nearestRestaurant?.id ?? ''));

    if (targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an outlet to view details'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    context.push('/restaurant/$targetId');
  }

  @override
  Widget build(BuildContext context) {
    final nearbyAsync = ref.watch(nearbyRestaurantsStreamProvider);
    final nearestRestaurant = nearbyAsync.value?.firstOrNull;

    List<BannerData> bannersList = [];
    if (nearestRestaurant != null && nearestRestaurant.homeHeroSliders.isNotEmpty) {
      bannersList = nearestRestaurant.homeHeroSliders
          .where((h) => h.active)
          .map((h) => BannerData(
                title: h.title,
                subtitle: h.description,
                imageUrl: h.imageUrl,
                ctaText: h.buttonText,
                actionType: h.actionType,
                targetBranchId: h.targetBranchId,
                targetRestaurantId: h.targetRestaurantId,
                badgeType: OfferBadgeType.flat50,
                accentColors: const [Color(0xFF0879C9), Color(0xFF005B9F)],
              ))
          .toList();
    }

    if (bannersList.isEmpty) {
      bannersList = _defaultBanners;
    }

    return Column(
      children: [
        CarouselSlider.builder(
          carouselController: _controller,
          itemCount: bannersList.length,
          itemBuilder: (context, index, realIndex) {
            final banner = bannersList[index % bannersList.length];
            final isActive = _currentIndex == index;

            return GestureDetector(
              onTap: () => _handleBannerTap(context, banner, nearestRestaurant),
              child: _BannerCard(
                banner: banner,
                isActive: isActive,
                onTap: () => _handleBannerTap(context, banner, nearestRestaurant),
              ),
            );
          },
          options: CarouselOptions(
            height: 240,
            autoPlay: bannersList.length > 1,
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
  final VoidCallback onTap;

  const _BannerCard({
    required this.banner,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard> with SingleTickerProviderStateMixin {
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

            // Cinematic gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      banner.accentColors.first.withValues(alpha: 0.85),
                      banner.accentColors.last.withValues(alpha: 0.4),
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
                      Colors.black.withValues(alpha: 0.3),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  if (banner.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      banner.subtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // CTA Button
                  GestureDetector(
                    onTap: widget.onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            banner.ctaText.isNotEmpty ? banner.ctaText : 'Order Now',
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
