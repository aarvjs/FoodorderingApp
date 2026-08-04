import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/food_card.dart';
import '../../core/services/state_providers.dart';
import '../../models/food_item.dart';
import '../../models/restaurant.dart';
import '../../models/table_model.dart';
import '../../models/combo_model.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:flutter/services.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../models/offer_model.dart';
import '../home/providers/restaurant_providers.dart';
import '../product/combo_customization_sheet.dart';

class RestaurantDetailsScreen extends ConsumerStatefulWidget {
  final String restaurantId;

  const RestaurantDetailsScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<RestaurantDetailsScreen> createState() => _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState extends ConsumerState<RestaurantDetailsScreen> {
  String? _selectedCategory;
  int _activeMainTab = 0; // 0: Menu, 1: Combos
  final TextEditingController _menuSearchController = TextEditingController();
  String _menuSearchQuery = '';

  @override
  void dispose() {
    _menuSearchController.dispose();
    super.dispose();
  }

  void _openTableBookingModal(Restaurant restaurant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.read(authProvider);
    final userModel = authState.userModel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TableBookingBottomSheet(
        restaurant: restaurant,
        isDark: isDark,
        customerName: userModel?.fullName ?? 'Guest Customer',
        customerPhone: userModel?.phone ?? '',
        customerEmail: userModel?.email,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen to real-time Firestore streams for restaurant details & menu
    final detailsAsync = ref.watch(restaurantDetailsStreamProvider(widget.restaurantId));
    final restaurant = detailsAsync.value;

    final targetRestId = (restaurant != null && restaurant.restaurantId.isNotEmpty) ? restaurant.restaurantId : widget.restaurantId;
    final menuAsync = ref.watch(restaurantMenuStreamProvider(targetRestId));
    final combosAsync = ref.watch(restaurantCombosStreamProvider(widget.restaurantId));
    final offersAsync = ref.watch(restaurantOffersStreamProvider(widget.restaurantId));
    final List<ComboModel> combosList = combosAsync.value ?? [];

    final List<FoodItem> dynamicMenu = (menuAsync.value != null && menuAsync.value!.isNotEmpty)
        ? menuAsync.value!
        : (restaurant?.items ?? []);
    final bool isMenuLoading = menuAsync.isLoading && dynamicMenu.isEmpty;

    if (detailsAsync.isLoading && restaurant == null) {
      return Scaffold(
        body: Center(
          child: Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.shop, size: 64, color: Colors.white),
                Gap(16),
                Text('Loading Outlet Details...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    if (restaurant == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Outlet details unavailable.'),
        ),
      );
    }

    // Dynamic category list from restaurant & menu items
    final Set<String> categoriesSet = {...restaurant.categories};
    for (var item in dynamicMenu) {
      if (item.category.isNotEmpty) categoriesSet.add(item.category);
    }
    final List<String> availableCategories = categoriesSet.toList();

    // Filter menu items by category + search query
    var filteredItems = dynamicMenu;
    if (_selectedCategory != null) {
      filteredItems = filteredItems.where((item) => item.category == _selectedCategory).toList();
    }
    if (_menuSearchQuery.isNotEmpty) {
      filteredItems = filteredItems.where((item) {
        return item.name.toLowerCase().contains(_menuSearchQuery.toLowerCase()) ||
            item.description.toLowerCase().contains(_menuSearchQuery.toLowerCase());
      }).toList();
    }

    return Scaffold(
      body: Stack(
        children: [
          // Scrollable Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom Sliver App Bar with Large Banner Image
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                stretch: true,
                backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'restaurant_banner_${restaurant.id}',
                    child: Image.network(
                      restaurant.bannerUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.restaurant, size: 48, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.4),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    onPressed: () => context.pop(),
                  ),
                ),
                actions: [
                  CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.4),
                    child: IconButton(
                      icon: Icon(
                        ref.watch(favoritesProvider).contains(restaurant.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: ref.watch(favoritesProvider).contains(restaurant.id)
                            ? Colors.red
                            : Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        ref.read(favoritesProvider.notifier).toggleFavorite(restaurant.id);
                      },
                    ),
                  ),
                  const Gap(12),
                ],
              ),

              // Restaurant Info details Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restaurant.name,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : AppColors.textDark,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (!restaurant.isOpen)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                                    ),
                                    child: const Text(
                                      'CURRENTLY CLOSED',
                                      style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${restaurant.rating}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Gap(3),
                                const Icon(Icons.star, color: Colors.white, size: 14),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(4),
                      Text(
                        restaurant.categories.join(' • '),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                        ),
                      ),
                      const Gap(12),
                      const Divider(),
                      const Gap(12),

                      // Logistics stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLogisticsColumn(Iconsax.routing, restaurant.distance, 'Distance', isDark),
                          _buildLogisticsColumn(Iconsax.clock, restaurant.deliveryTime, 'Delivery', isDark),
                          _buildOfferBadgePill(offersAsync, restaurant, isDark),
                        ],
                      ),

                      // Table Booking Card (if enabled)
                      if (restaurant.hasDineIn) ...[
                        const Gap(16),
                        GestureDetector(
                          onTap: () => _openTableBookingModal(restaurant),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 22),
                                ),
                                const Gap(14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Book a Table 🪑',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Gap(2),
                                      Text(
                                        'Reserve your dining table instantly from Firestore',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Real-time Branch Gallery Section
                      _buildBranchGallerySection(restaurant, isDark),

                      const Gap(12),
                      const Divider(),
                      const Gap(12),

                      // Segmented Main Tab Selector: Menu | Combos
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _activeMainTab = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _activeMainTab == 0
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Iconsax.element_4,
                                          size: 16,
                                          color: _activeMainTab == 0 ? Colors.white : (isDark ? Colors.grey.shade400 : AppColors.textDark),
                                        ),
                                        const Gap(6),
                                        Text(
                                          'Menu',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: _activeMainTab == 0 ? Colors.white : (isDark ? Colors.grey.shade400 : AppColors.textDark),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _activeMainTab = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _activeMainTab == 1
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.local_fire_department_rounded,
                                          size: 16,
                                          color: _activeMainTab == 1 ? Colors.white : (isDark ? Colors.grey.shade400 : AppColors.textDark),
                                        ),
                                        const Gap(6),
                                        Text(
                                          'Combos (${combosList.length})',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: _activeMainTab == 1 ? Colors.white : (isDark ? Colors.grey.shade400 : AppColors.textDark),
                                          ),
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

                      const Gap(14),

                      // Menu Search Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                          ),
                        ),
                        child: TextField(
                          controller: _menuSearchController,
                          onChanged: (val) {
                            setState(() {
                              _menuSearchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: _activeMainTab == 0 ? 'Search within restaurant menu...' : 'Search combos...',
                            prefixIcon: Icon(Iconsax.search_normal_1, size: 18, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sticky Categories Header Tabs (Only in Menu Tab)
              if (_activeMainTab == 0)
                SliverAppBar(
                  primary: false,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
                  elevation: 1,
                  title: Container(
                    height: 44,
                    alignment: Alignment.centerLeft,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: availableCategories.length + 1,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final isAll = index == 0;
                        final catName = isAll ? 'All Menu' : availableCategories[index - 1];
                        final isSelected = isAll 
                            ? (_selectedCategory == null)
                            : (_selectedCategory == catName);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = isAll ? null : catName;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                  : (isDark ? AppColors.darkCard : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected 
                                    ? Colors.transparent 
                                    : (isDark ? AppColors.darkDivider : Colors.grey.shade200),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                catName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected 
                                      ? (isDark ? AppColors.textDark : Colors.white)
                                      : (isDark ? Colors.white : AppColors.textDark),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Content View (Menu Dishes List or Combos List)
              SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                sliver: _activeMainTab == 1
                    ? _buildCombosSliver(combosList, restaurant, isDark)
                    : (isMenuLoading
                        ? SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Shimmer.fromColors(
                                  baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                  highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                                  child: Container(
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                              ),
                              childCount: 4,
                            ),
                          )
                        : (filteredItems.isEmpty
                            ? SliverToBoxAdapter(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Iconsax.document_text,
                                          size: 48,
                                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                        ),
                                        const Gap(12),
                                        Text(
                                          'No menu items available for this outlet.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final foodItem = filteredItems[index];
                                    return FoodCard(
                                      foodItem: foodItem,
                                      restaurantId: restaurant.id,
                                      restaurantName: restaurant.name,
                                      onTap: () => context.push('/product/${restaurant.id}/${foodItem.id}'),
                                    );
                                  },
                                  childCount: filteredItems.length,
                                ),
                              ))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfferBadgePill(AsyncValue<List<OfferModel>> offersAsync, Restaurant restaurant, bool isDark) {
    final offersList = offersAsync.value ?? [];
    final int offersCount = offersList.length;

    String labelText = 'OFFERS';
    if (offersCount > 0) {
      labelText = '$offersCount OFFER${offersCount > 1 ? 'S' : ''}';
    } else if (restaurant.offerText.isNotEmpty) {
      labelText = restaurant.offerText;
    }

    return InkWell(
      onTap: () => _showOffersBottomSheet(offersAsync, isDark),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF7C2D12), const Color(0xFFC2410C)]
                : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFFEA580C) : const Color(0xFFF97316),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.ticket_discount, size: 16, color: Color(0xFFEA580C)),
            const Gap(6),
            Text(
              labelText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEA580C),
                letterSpacing: 0.3,
              ),
            ),
            const Gap(2),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFEA580C)),
          ],
        ),
      ),
    );
  }

  void _showOffersBottomSheet(AsyncValue<List<OfferModel>> initialOffersAsync, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final liveOffersAsync = ref.watch(restaurantOffersStreamProvider(widget.restaurantId));

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bottom sheet handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Iconsax.ticket_discount, color: AppColors.primary, size: 20),
                            ),
                            const Gap(10),
                            Text(
                              'Available Offers',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Body Content
                  Expanded(
                    child: liveOffersAsync.when(
                      loading: () => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: AppColors.primary),
                              const Gap(16),
                              Text(
                                'Fetching available offers...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                              const Gap(12),
                              Text(
                                'Unable to load offers',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textDark,
                                ),
                              ),
                              const Gap(6),
                              Text(
                                'Please check your connection and try again.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                ),
                              ),
                              const Gap(16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  ref.invalidate(restaurantOffersStreamProvider(widget.restaurantId));
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                                label: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      data: (offers) {
                        if (offers.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '🎁',
                                    style: TextStyle(fontSize: 48),
                                  ),
                                  const Gap(12),
                                  Text(
                                    'No Offers Available',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppColors.textDark,
                                    ),
                                  ),
                                  const Gap(6),
                                  Text(
                                    'Check back later for exciting offers.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: offers.length,
                          separatorBuilder: (_, __) => const Gap(14),
                          itemBuilder: (context, index) {
                            final offer = offers[index];
                            final discountText = offer.formattedDiscount;

                            return Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Title & Discount Badge
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            offer.title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : AppColors.textDark,
                                            ),
                                          ),
                                        ),
                                        const Gap(8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade700,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            discountText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Gap(6),

                                    // Description
                                    Text(
                                      offer.description,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.grey.shade300 : AppColors.textLight,
                                      ),
                                    ),
                                    const Gap(10),

                                    // Meta Info (Min Order / Expiry)
                                    Row(
                                      children: [
                                        if (offer.minimumOrder > 0) ...[
                                          Icon(Iconsax.shopping_bag, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                          const Gap(4),
                                          Text(
                                            'Min order ₹${offer.minimumOrder.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Gap(12),
                                        ],
                                        if (offer.endDate != null && offer.endDate!.isNotEmpty) ...[
                                          Icon(Iconsax.calendar, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                          const Gap(4),
                                          Text(
                                            'Till ${offer.endDate}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const Gap(14),

                                    // Dashed Coupon Box & Copy Button
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.black26 : Colors.orange.shade50.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Iconsax.ticket, size: 18, color: AppColors.primary),
                                              const Gap(8),
                                              Text(
                                                offer.couponCode,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.0,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: offer.couponCode));
                                              TopToast.show(
                                                context,
                                                'Coupon "${offer.couponCode}" copied successfully!',
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                                                  Gap(4),
                                                  Text(
                                                    'Copy Coupon',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
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
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLogisticsColumn(IconData icon, String val, String subtitle, bool isDark, {bool highlight = false}) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: highlight
              ? (isDark ? AppColors.darkPrimary : AppColors.primary)
              : (isDark ? Colors.grey.shade400 : AppColors.textLight),
        ),
        const Gap(4),
        Text(
          val,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: highlight
                ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                : (isDark ? Colors.white : AppColors.textDark),
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBranchGallerySection(Restaurant restaurant, bool isDark) {
    final targetId = restaurant.branchId.isNotEmpty ? restaurant.branchId : restaurant.id;
    final galleryAsync = ref.watch(branchGalleryStreamProvider(targetId));

    return galleryAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(16),
            Row(
              children: [
                const Icon(Icons.photo_library_rounded, size: 18, color: AppColors.primary),
                const Gap(8),
                Text(
                  'Branch Gallery (${items.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
              ],
            ),
            const Gap(10),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final imgUrl = (items[index]['url'] ?? items[index]['imageUrl'] ?? '').toString();
                  final category = (items[index]['category'] ?? 'Gallery').toString();
                  if (imgUrl.isEmpty) return const SizedBox.shrink();

                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.black87, Colors.transparent],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCombosSliver(List<ComboModel> combosList, Restaurant restaurant, bool isDark) {
    if (combosList.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fastfood_outlined,
                  size: 56,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                const Gap(16),
                Text(
                  'No Combos Available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                const Gap(6),
                Text(
                  'This outlet currently has no active combo deals.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filteredCombos = _menuSearchQuery.isEmpty
        ? combosList
        : combosList
            .where((c) =>
                c.name.toLowerCase().contains(_menuSearchQuery.toLowerCase()) ||
                c.description.toLowerCase().contains(_menuSearchQuery.toLowerCase()))
            .toList();

    if (filteredCombos.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              'No combos found matching "$_menuSearchQuery".',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : AppColors.textLight,
              ),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final combo = filteredCombos[index];
          final itemsSummary = combo.items.map((i) => i.productName).join(' • ');

          return Container(
            key: ValueKey(combo.id),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Image.network(
                      combo.image,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: AppColors.primary.withOpacity(0.1),
                        child: const Icon(Icons.fastfood, size: 40, color: AppColors.primary),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            Gap(4),
                            Text(
                              'VEG COMBO',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          combo.isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: combo.isAvailable ? Colors.greenAccent : Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              combo.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textDark,
                              ),
                            ),
                          ),
                          Text(
                            '₹${combo.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const Gap(4),
                      Text(
                        combo.description.isNotEmpty ? combo.description : 'Special value combo meal.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (itemsSummary.isNotEmpty) ...[
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.primary),
                              const Gap(6),
                              Expanded(
                                child: Text(
                                  'Includes: $itemsSummary',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Gap(12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 42),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: combo.isAvailable
                                ? () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => ComboCustomizationSheet(
                                        combo: combo,
                                        restaurantId: restaurant.id,
                                        restaurantName: restaurant.name,
                                      ),
                                    );
                                  }
                                : null,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'ADD COMBO',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: combo.isAvailable
                                      ? Colors.white
                                      : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        childCount: filteredCombos.length,
      ),
    );
  }
}

class _TableBookingBottomSheet extends ConsumerStatefulWidget {
  final Restaurant restaurant;
  final bool isDark;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;

  const _TableBookingBottomSheet({
    required this.restaurant,
    required this.isDark,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
  });

  @override
  ConsumerState<_TableBookingBottomSheet> createState() => _TableBookingBottomSheetState();
}

class _TableBookingBottomSheetState extends ConsumerState<_TableBookingBottomSheet> {
  TableModel? _selectedTable;
  int _guests = 2;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 30);
  bool _isSubmitting = false;

  Future<void> _submitBooking() async {
    if (_selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an available table.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final repo = ref.read(restaurantRepositoryProvider);
    final authUser = ref.read(authProvider).userModel;
    final String formattedDate = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final String formattedTime = '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    final booking = TableBookingModel(
      id: '',
      restaurantId: widget.restaurant.restaurantId.isNotEmpty ? widget.restaurant.restaurantId : widget.restaurant.id,
      branchId: widget.restaurant.branchId.isNotEmpty ? widget.restaurant.branchId : widget.restaurant.id,
      restaurantName: widget.restaurant.name,
      branchName: widget.restaurant.branchName.isNotEmpty ? widget.restaurant.branchName : 'Main',
      tableId: _selectedTable!.id,
      tableNumber: _selectedTable!.tableNumber,
      customerId: authUser?.uid ?? '',
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      customerEmail: widget.customerEmail,
      date: formattedDate,
      time: formattedTime,
      guests: _guests,
      charges: 0.0,
      gst: 0.0,
      grandTotal: 0.0,
      status: 'CONFIRMED',
      createdAt: DateTime.now(),
    );

    final success = await repo.createTableBooking(booking);

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pop(context);

      if (success) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: widget.isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 24),
                Gap(8),
                Text('Booking Confirmed!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildBillRow('Restaurant', widget.restaurant.name),
                      _buildBillRow('Table Number', _selectedTable!.tableNumber),
                      _buildBillRow('Date & Time', '$formattedDate | $formattedTime'),
                      _buildBillRow('Guests', '$_guests Guests'),
                      _buildBillRow('Reservation Charge', 'FREE'),
                      const Divider(),
                      _buildBillRow('Status', 'CONFIRMED', isStatus: true),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/bookings');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('View My Bookings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        final errorDetail = repo.lastBookingError != null ? ': ${repo.lastBookingError}' : '. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Table Booking Failed$errorDetail')),
        );
      }
    }
  }

  Widget _buildBillRow(String label, String val, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isStatus ? AppColors.success : (widget.isDark ? Colors.white : AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetId = widget.restaurant.branchId.isNotEmpty ? widget.restaurant.branchId : widget.restaurant.id;
    final tablesAsync = ref.watch(availableTablesStreamProvider(targetId));
    final isDark = widget.isDark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),
          Text(
            'Select Table at ${widget.restaurant.name}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
          ),
          const Gap(14),

          tablesAsync.when(
            data: (tables) {
              if (tables.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900.withOpacity(0.5) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'No tables available for booking.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                      ),
                    ),
                  ),
                );
              }

              // Auto-select first table if none selected yet or selected table is no longer available
              if ((_selectedTable == null || !tables.any((t) => t.id == _selectedTable!.id)) && tables.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && (_selectedTable == null || !tables.any((t) => t.id == _selectedTable!.id))) {
                    setState(() => _selectedTable = tables.first);
                  }
                });
              }

              return SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tables.length,
                  itemBuilder: (context, index) {
                    final t = tables[index];
                    final isSel = _selectedTable?.id == t.id;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedTable = t),
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.primary
                              : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel ? AppColors.primary : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              t.tableNumber,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : (isDark ? Colors.white : AppColors.textDark),
                              ),
                            ),
                            const Gap(4),
                            Text(
                              '${t.capacity} Guests • ${t.type}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSel ? Colors.white70 : (isDark ? Colors.grey.shade400 : AppColors.textLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Error loading available tables.'),
          ),

          const Gap(20),

          // Guests count selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Number of Guests',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
                  ),
                  Text(
                    '$_guests',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _guests++),
                  ),
                ],
              ),
            ],
          ),

          const Gap(20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Confirm Table Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
