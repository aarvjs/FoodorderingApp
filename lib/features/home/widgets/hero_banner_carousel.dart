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
      title: '🍕 Cheese Burst\nPizza Festival',
      subtitle: 'Ultra cheesy, ultra melty — order now!',
      imageUrl:
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=900&q=90&auto=format&fit=crop',
      ctaText: 'Order Now',
      badgeType: OfferBadgeType.flat50,
      accentColors: [Color(0xFFFF4D4F), Color(0xFFFF7043)],
    ),
    const BannerData(
      title: '🍔 Double Patty\nBurger Blast',
      subtitle: 'Crispy, juicy, dripping with sauce!',
      imageUrl:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=900&q=90&auto=format&fit=crop',
      ctaText: 'Grab Now',
      badgeType: OfferBadgeType.buy1get1,
      accentColors: [Color(0xFF92400E), Color(0xFFD97706)],
    ),
    const BannerData(
      title: '🥘 Royal Biryani\nWeek',
      subtitle: 'Authentic dum biryani, free delivery!',
      imageUrl:
          'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=900&q=90&auto=format&fit=crop',
      ctaText: 'Order Now',
      badgeType: OfferBadgeType.freeDelivery,
      accentColors: [Color(0xFF78350F), Color(0xFFB45309)],
    ),
    const BannerData(
      title: '🍗 Crispy Chicken\nBucket',
      subtitle: 'Golden crispy perfection in every bite',
      imageUrl:
          'https://images.unsplash.com/photo-1562967914-608f82629710?w=900&q=90&auto=format&fit=crop',
      ctaText: 'Order Now',
      badgeType: OfferBadgeType.weekend,
      accentColors: [Color(0xFF7C2D12), Color(0xFFEA580C)],
    ),
    const BannerData(
      title: '🍜 Chinese Food\nFestival',
      subtitle: 'Momos, noodles & more — buy 1 get 1!',
      imageUrl:
          'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=900&q=90&auto=format&fit=crop',
      ctaText: 'Explore Now',
      badgeType: OfferBadgeType.buy1get1,
      accentColors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(offersStreamProvider);

    List<BannerData> bannersList = _defaultBanners;
    offersAsync.whenData((offers) {
      if (offers.isNotEmpty) {
        bannersList = offers.map((o) {
          return BannerData(
            title: o.title,
            subtitle: o.description,
            imageUrl: o.bannerUrl,
            ctaText: o.ctaText,
            badgeType: o.badgeType,
            accentColors: o.accentColors,
          );
        }).toList();
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
              child: CachedNetworkImage(
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
