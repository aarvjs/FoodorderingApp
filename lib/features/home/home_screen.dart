import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/restaurant_card.dart';
import '../../models/restaurant.dart';
import '../../auth/providers/auth_provider.dart';
import 'providers/restaurant_providers.dart';
import 'widgets/glass_app_bar.dart';
import 'widgets/animated_search_bar.dart';
import 'widgets/hero_banner_carousel.dart';
import 'widgets/floating_particles_bg.dart';
import 'widgets/premium_category_list.dart';
import '../address/widgets/address_selection_bottom_sheet.dart';
import '../../core/services/state_providers.dart';





class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedCategory;
  String _activeFilter = 'All';
  late AnimationController _greetingController;

  final List<String> _filters = const [
    'All',
    'Offers',
    'Rating 4+',
    'Pure Veg',
    'Fast Delivery',
    'Under ₹200',
    'Free Delivery',
  ];

  final List<Map<String, dynamic>> _exploreMore = const [
    {
      'title': 'Rewards',
      'icon': Iconsax.award5,
      'color': Color(0xFFFF9800),
      'bg': Color(0xFFFFF3E0),
    },
    {
      'title': 'Coupons',
      'icon': Iconsax.discount_shape,
      'color': Color(0xFFE91D25),
      'bg': Color(0xFFFFEBEE),
    },
    {
      'title': 'Collections',
      'icon': Iconsax.folder_open,
      'color': Color(0xFF3B82F6),
      'bg': Color(0xFFEBF5FF),
    },
  ];



  @override
  void initState() {
    super.initState();
    _greetingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // Set system overlay style for immersive feel
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // Guard: Ensure user has a valid delivery location before viewing Home Screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final addressState = ref.read(addressProvider);
      final authUser = ref.read(authProvider).userModel;

      final hasAddress = addressState.selectedAddress != null &&
          addressState.selectedAddress!.formattedAddress.isNotEmpty &&
          addressState.selectedAddress!.latitude != 0.0;

      final hasProfileAddress = authUser != null &&
          authUser.formattedAddress != null &&
          authUser.formattedAddress!.isNotEmpty &&
          authUser.latitude != null &&
          authUser.latitude != 0.0;

      if (!hasAddress && !hasProfileAddress) {
        context.go('/location-permission');
      }
    });
  }

  @override
  void dispose() {
    _greetingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final userName = authState.userModel?.fullName?.isNotEmpty == true
        ? authState.userModel!.fullName!.split(' ').first
        : 'User';

    // Real-time Firestore Stream for nearby restaurants (filtered by customer delivery radius)
    final nearbyAsync = ref.watch(nearbyRestaurantsStreamProvider);
    final List<Restaurant> allRestaurants = nearbyAsync.value ?? [];
    final bool isLoading = nearbyAsync.isLoading && allRestaurants.isEmpty;

    // Apply Filter Logic
    var filteredRestaurants = allRestaurants;
    if (_selectedCategory != null) {
      final catMap = {
        'Pizza': 'Pizza',
        'Burger': 'Burger',
        'Biryani': 'Biryani',
        'Chinese': 'Chinese',
        'Roll': 'Roll',
        'Cake': 'Cake',
        'Coffee': 'Coffee',
        'Ice Cream': 'Ice Cream',
        'Healthy': 'Healthy',
        'Desserts': 'Desserts',
        'Drinks': 'Coffee',
        'Fast Food': 'Burger',
        'Mexican': 'Roll',
        'South Indian': 'Biryani',
      };
      final mappedCat = catMap[_selectedCategory] ?? _selectedCategory!;
      filteredRestaurants = filteredRestaurants
          .where((r) => r.categories.contains(mappedCat) || r.categories.contains(_selectedCategory))
          .toList();
    }

    if (_activeFilter == 'Offers') {
      filteredRestaurants =
          filteredRestaurants.where((r) => r.offerText.isNotEmpty).toList();
    } else if (_activeFilter == 'Rating 4+') {
      filteredRestaurants =
          filteredRestaurants.where((r) => r.rating >= 4.4).toList();
    } else if (_activeFilter == 'Pure Veg') {
      filteredRestaurants = filteredRestaurants
          .where((r) => r.items.any((i) => i.isVeg))
          .toList();
    } else if (_activeFilter == 'Free Delivery') {
      filteredRestaurants = filteredRestaurants
          .where((r) => r.offerText.contains('Free Delivery'))
          .toList();
    } else if (_activeFilter == 'Under ₹200') {
      filteredRestaurants = filteredRestaurants
          .where((r) => r.items.any((i) => i.price <= 200))
          .toList();
    }

    return FloatingParticlesBackground(
      isDark: isDark,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Glass App Bar
            SliverToBoxAdapter(
              child: GlassAppBar(
                isDark: isDark,
                unreadNotifications: ref.watch(unreadNotificationCountProvider),
                onMenuTap: () => Scaffold.of(context).openDrawer(),
                onNotificationTap: () => context.push('/notifications'),

                onWalletTap: () {},
                onProfileTap: () => context.push('/profile'),
                onLocationTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddressSelectionBottomSheet(),
                  );
                },
              ),
            ),

            // Sticky Glassmorphism Search Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: StickySearchBarDelegate(isDark: isDark),
            ),

            // Main scrollable body
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Gap(8),

                  // Greeting header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $userName! 👋',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade500
                                : AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "What's on your\nmind today?",
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 200.ms)
                      .slideX(
                          begin: -0.2,
                          end: 0,
                          duration: 600.ms,
                          curve: Curves.easeOut),

                  const Gap(20),

                  // Hero Banner Carousel
                  HeroBannerCarousel(isDark: isDark),

                  const Gap(28),

                  // Categories Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "What are you\ncraving? 🍽️",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            color: isDark ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        if (_selectedCategory != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedCategory = null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.secondary
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Clear',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 300.ms),

                  const Gap(14),

                  // Premium Category List
                  PremiumCategoryList(
                    isDark: isDark,
                    selectedCategory: _selectedCategory,
                    onCategorySelected: (cat) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),

                  const Gap(28),

                  // Explore More
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Explore More ✨',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 400.ms),

                  const Gap(14),

                  // Explore More Grid (Rewards & Coupons)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Rewards Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('/rewards'),
                            child: Container(
                              height: 105,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [const Color(0xFF3E2723), const Color(0xFF261410)]
                                      : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isDark ? const Color(0xFFFF9800).withOpacity(0.3) : const Color(0xFFFF9800).withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF9800).withOpacity(0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: -10,
                                    bottom: -10,
                                    child: Icon(
                                      Iconsax.award5,
                                      size: 64,
                                      color: const Color(0xFFFF9800).withOpacity(0.12),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF9800).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Iconsax.award5,
                                              size: 20,
                                              color: Color(0xFFFF9800),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF9800),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'POINTS',
                                              style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Rewards 🎁',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : AppColors.textDark,
                                            ),
                                          ),
                                          Text(
                                            'Earn & Redeem',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),
                        ),

                        const Gap(12),

                        // Coupons Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('/offers'),
                            child: Container(
                              height: 105,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [const Color(0xFF3B1215), const Color(0xFF240A0C)]
                                      : [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isDark ? const Color(0xFFE91D25).withOpacity(0.3) : const Color(0xFFE91D25).withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE91D25).withOpacity(0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: -10,
                                    bottom: -10,
                                    child: Icon(
                                      Iconsax.discount_shape,
                                      size: 64,
                                      color: const Color(0xFFE91D25).withOpacity(0.12),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE91D25).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Iconsax.discount_shape,
                                              size: 20,
                                              color: Color(0xFFE91D25),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE91D25),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'OFFERS',
                                              style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Coupons 🏷️',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : AppColors.textDark,
                                            ),
                                          ),
                                          Text(
                                            'Branch Deals',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).scale(begin: const Offset(0.9, 0.9)),
                        ),
                      ],
                    ),
                  ),

                  const Gap(28),

                  // Premium Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey.shade200,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '🍴 Nearby Outlets',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : AppColors.textLight,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey.shade200,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(16),

                  // Filter row
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        final isSel = _activeFilter == filter;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _activeFilter = filter),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              gradient: isSel
                                  ? const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.secondary
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isSel
                                  ? null
                                  : (isDark
                                      ? const Color(0xFF1E1E1E)
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSel
                                    ? Colors.transparent
                                    : (isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.grey.shade200),
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withOpacity(0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Text(
                              filter,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSel
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white70
                                        : AppColors.textDark),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Gap(16),

                  // Restaurants header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedCategory == null
                              ? 'Outlets Delivering To You'
                              : '$_selectedCategory Restaurants',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${filteredRestaurants.length} found',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade500
                                : AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(12),
                ],
              ),
            ),

            // Restaurant Cards or Loading Skeletons
            if (isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: List.generate(3, (index) => _buildRestaurantSkeleton(isDark)),
                  ),
                ),
              )
            else if (filteredRestaurants.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('😕', style: TextStyle(fontSize: 48)),
                        const Gap(12),
                        Text(
                          'No Restaurants Found',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.textDark,
                          ),
                        ),
                        const Gap(6),
                        Text(
                          'Please select a delivery address or try adjusting filters to see nearby restaurants.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade400
                                : AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, bottom: 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final rest = filteredRestaurants[index];
                      return RestaurantCard(
                        restaurant: rest,
                        onTap: () =>
                            context.push('/restaurant/${rest.id}'),
                      )
                          .animate(
                              delay:
                                  Duration(milliseconds: index * 60))
                          .fadeIn(duration: 400.ms)
                          .slideY(
                              begin: 0.2,
                              end: 0,
                              duration: 400.ms,
                              curve: Curves.easeOut);
                    },
                    childCount: filteredRestaurants.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantSkeleton(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        height: 240,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
