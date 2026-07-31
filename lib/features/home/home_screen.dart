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
import 'widgets/premium_category_list.dart';
import 'widgets/floating_particles_bg.dart';
import '../address/widgets/address_selection_bottom_sheet.dart';

import '../address/providers/address_provider.dart';

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
      'title': 'Offers',
      'icon': Iconsax.ticket_discount,
      'color': Color(0xFFFF4D4F),
      'bg': Color(0xFFFFEEEB),
    },
    {
      'title': 'Collections',
      'icon': Iconsax.folder_open,
      'color': Color(0xFF3B82F6),
      'bg': Color(0xFFEBF5FF),
    },
    {
      'title': 'Gift Cards',
      'icon': Iconsax.gift,
      'color': Color(0xFF10B981),
      'bg': Color(0xFFE8FFF5),
    },
    {
      'title': 'Party Orders',
      'icon': Iconsax.cake,
      'color': Color(0xFF8B5CF6),
      'bg': Color(0xFFF5F0FF),
    },
    {
      'title': 'Food on Train',
      'icon': Iconsax.box,
      'color': Color(0xFF06B6D4),
      'bg': Color(0xFFE8FEFF),
    },
    {
      'title': 'Premium',
      'icon': Iconsax.crown,
      'color': Color(0xFFD97706),
      'bg': Color(0xFFFFF8E1),
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

                  // Explore More Grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.05,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _exploreMore.length,
                      itemBuilder: (context, index) {
                        final item = _exploreMore[index];
                        final itemColor = item['color'] as Color;
                        final itemBg = item['bg'] as Color;
                        return GestureDetector(
                          onTap: () {
                            if (item['title'] == 'Offers') {
                              context.push('/offers');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Opening ${item['title']}...'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : itemBg.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : itemColor.withOpacity(0.15),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: itemColor.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: itemColor.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    item['icon'] as IconData,
                                    size: 22,
                                    color: itemColor,
                                  ),
                                ),
                                const Gap(8),
                                Text(
                                  item['title'] as String,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate(
                                delay:
                                    Duration(milliseconds: index * 70 + 300))
                            .fadeIn(duration: 400.ms)
                            .scale(
                              begin: const Offset(0.85, 0.85),
                              end: const Offset(1, 1),
                              duration: 400.ms,
                              curve: Curves.easeOut,
                            );
                      },
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
