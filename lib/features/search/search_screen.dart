import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/food_card.dart';
import '../../core/widgets/restaurant_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../models/food_item.dart';
import '../../models/restaurant.dart';
import '../../models/cart_item.dart';
import '../../core/services/state_providers.dart';
import '../home/providers/restaurant_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // Quick Filters
  bool _vegOnly = false;
  bool _nonVegOnly = false;
  bool _topRatedOnly = false;
  bool _fastDeliveryOnly = false;
  bool _openNowOnly = false;
  bool _tablesOnly = false;
  String? _selectedCategory;

  final List<Map<String, String>> _categories = [
    {'name': 'Pizza', 'icon': '🍕'},
    {'name': 'Burger', 'icon': '🍔'},
    {'name': 'Veg', 'icon': '🥗'},
    {'name': 'Non Veg', 'icon': '🍗'},
    {'name': 'Drinks', 'icon': '🥤'},
    {'name': 'Dessert', 'icon': '🍰'},
    {'name': 'Snacks', 'icon': '🍟'},
    {'name': 'Chinese', 'icon': '🍜'},
    {'name': 'North Indian', 'icon': '🥘'},
    {'name': 'Breakfast', 'icon': '🥞'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _query = '';
      _selectedCategory = null;
    });
  }

  bool get _hasActiveFilters =>
      _query.isNotEmpty ||
      _vegOnly ||
      _nonVegOnly ||
      _topRatedOnly ||
      _fastDeliveryOnly ||
      _openNowOnly ||
      _tablesOnly ||
      _selectedCategory != null;

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _vegOnly = false;
      _nonVegOnly = false;
      _topRatedOnly = false;
      _fastDeliveryOnly = false;
      _openNowOnly = false;
      _tablesOnly = false;
      _selectedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Stream nearby restaurants using existing latitude/longitude & radius logic
    final nearbyAsync = ref.watch(nearbyRestaurantsStreamProvider);
    final List<Restaurant> allRestaurants = nearbyAsync.value ?? [];

    // Filter restaurants based on query & active filter chips
    List<Restaurant> filteredRestaurants = allRestaurants.where((r) {
      if (_openNowOnly && !r.isOpen) return false;
      if (_topRatedOnly && r.rating < 4.0) return false;
      if (_tablesOnly && !r.hasDineIn) return false;

      // Extract delivery time mins
      if (_fastDeliveryOnly) {
        final match = RegExp(r'(\d+)').firstMatch(r.deliveryTime);
        if (match != null) {
          final mins = int.tryParse(match.group(1) ?? '99') ?? 99;
          if (mins > 35) return false;
        }
      }

      if (_selectedCategory != null) {
        final catLower = _selectedCategory!.toLowerCase();
        final matchesCategory = r.categories.any((c) => c.toLowerCase().contains(catLower)) ||
            r.items.any((item) => item.category.toLowerCase().contains(catLower));
        if (!matchesCategory) return false;
      }

      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matchesName = r.name.toLowerCase().contains(q);
        final matchesCat = r.categories.any((c) => c.toLowerCase().contains(q));
        final matchesFood = r.items.any((item) =>
            item.name.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q));
        final matchesVeg = q == 'veg' ? r.items.any((i) => i.isVeg) : false;
        final matchesNonVeg = (q == 'non veg' || q == 'non-veg') ? r.items.any((i) => !i.isVeg) : false;

        return matchesName || matchesCat || matchesFood || matchesVeg || matchesNonVeg;
      }

      return true;
    }).toList();

    // Collect matched food items across nearby restaurants
    List<Map<String, dynamic>> matchedDishes = [];
    for (var restaurant in allRestaurants) {
      for (var item in restaurant.items) {
        if (!item.isAvailable) continue;
        if (_vegOnly && !item.isVeg) continue;
        if (_nonVegOnly && item.isVeg) continue;

        if (_selectedCategory != null) {
          final catLower = _selectedCategory!.toLowerCase();
          if (!item.category.toLowerCase().contains(catLower) &&
              !restaurant.categories.any((c) => c.toLowerCase().contains(catLower))) {
            continue;
          }
        }

        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          final isNameMatch = item.name.toLowerCase().contains(q);
          final isDescMatch = item.description.toLowerCase().contains(q);
          final isCatMatch = item.category.toLowerCase().contains(q);
          final isRestMatch = restaurant.name.toLowerCase().contains(q);
          final isVegMatch = q == 'veg' && item.isVeg;
          final isNonVegMatch = (q == 'non veg' || q == 'non-veg') && !item.isVeg;

          if (!isNameMatch && !isDescMatch && !isCatMatch && !isRestMatch && !isVegMatch && !isNonVegMatch) {
            continue;
          }
        }

        matchedDishes.add({
          'food': item,
          'restaurant': restaurant,
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Food & Outlets', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Header
            _buildSearchBar(isDark),

            // Quick Filter Chips (Veg, Non-Veg, Top Rated, etc.)
            _buildQuickFilterChips(isDark),

            const Gap(4),

            // Main Content Body
            Expanded(
              child: nearbyAsync.isLoading && allRestaurants.isEmpty
                  ? _buildShimmerSkeleton(isDark)
                  : (_hasActiveFilters
                      ? _buildFilteredSearchResults(isDark, filteredRestaurants, matchedDishes)
                      : _buildDiscoveryHome(isDark, allRestaurants)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SEARCH BAR WIDGET
  // ==========================================
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _query = val.trim();
            });
          },
          decoration: InputDecoration(
            hintText: 'Search dishes, cuisines, or outlets...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade500 : AppColors.textLight,
            ),
            prefixIcon: Icon(
              Iconsax.search_normal_1,
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
              size: 20,
            ),
            suffixIcon: _query.isNotEmpty || _selectedCategory != null
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: _clearSearch,
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // QUICK FILTER CHIPS
  // ==========================================
  Widget _buildQuickFilterChips(bool isDark) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (_hasActiveFilters)
            GestureDetector(
              onTap: _clearAllFilters,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 14, color: Colors.red),
                    Gap(4),
                    Text('Reset All', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          _buildFilterChip('🥗 Veg', _vegOnly, () {
            setState(() {
              _vegOnly = !_vegOnly;
              if (_vegOnly) _nonVegOnly = false;
            });
          }, isDark),
          _buildFilterChip('🍗 Non Veg', _nonVegOnly, () {
            setState(() {
              _nonVegOnly = !_nonVegOnly;
              if (_nonVegOnly) _vegOnly = false;
            });
          }, isDark),
          _buildFilterChip('⭐ Top Rated', _topRatedOnly, () {
            setState(() => _topRatedOnly = !_topRatedOnly);
          }, isDark),
          _buildFilterChip('⚡ Fast Delivery', _fastDeliveryOnly, () {
            setState(() => _fastDeliveryOnly = !_fastDeliveryOnly);
          }, isDark),
          _buildFilterChip('🟢 Open Now', _openNowOnly, () {
            setState(() => _openNowOnly = !_openNowOnly);
          }, isDark),
          _buildFilterChip('🪑 Available Tables', _tablesOnly, () {
            setState(() => _tablesOnly = !_tablesOnly);
          }, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkPrimary : AppColors.primary)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? AppColors.darkDivider : Colors.grey.shade200),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? (isDark ? AppColors.textDark : Colors.white)
                  : (isDark ? Colors.white : AppColors.textDark),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DISCOVERY HOME (WHEN NO QUERY IS TYPED)
  // ==========================================
  Widget _buildDiscoveryHome(bool isDark, List<Restaurant> restaurants) {
    // Extract table-available restaurants
    final tableRestaurants = restaurants.where((r) => r.hasDineIn && r.isOpen).toList();

    // Extract popular food items
    List<Map<String, dynamic>> popularDishes = [];
    for (var r in restaurants) {
      for (var item in r.items) {
        if (item.isAvailable) {
          popularDishes.add({'food': item, 'restaurant': r});
        }
      }
    }
    // Sort by food rating descending
    popularDishes.sort((a, b) => (b['food'] as FoodItem).rating.compareTo((a['food'] as FoodItem).rating));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(12),

          // ------------------------------------------
          // SECTION 1: FOOD CATEGORIES
          // ------------------------------------------
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(title: 'Explore Categories 🍕'),
          ),
          const Gap(12),
          SizedBox(
            height: 95,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['name'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = isSelected ? null : cat['name'];
                    });
                  },
                  child: Container(
                    width: 76,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppColors.darkPrimary.withOpacity(0.2) : AppColors.primary.withOpacity(0.1))
                          : (isDark ? AppColors.darkCard : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                            : (isDark ? AppColors.darkDivider : Colors.grey.shade200),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cat['icon']!, style: const TextStyle(fontSize: 28)),
                        const Gap(6),
                        Text(
                          cat['name']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                : (isDark ? Colors.white : AppColors.textDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Gap(24),

          // ------------------------------------------
          // SECTION 2: AVAILABLE TABLES NEAR YOU
          // ------------------------------------------
          if (tableRestaurants.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(title: 'Available Tables Near You 🪑'),
            ),
            const Gap(12),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tableRestaurants.length,
                itemBuilder: (context, index) {
                  final rest = tableRestaurants[index];
                  return _buildTableRestaurantCard(rest, isDark);
                },
              ),
            ),
            const Gap(24),
          ],

          // ------------------------------------------
          // SECTION 3: POPULAR FOOD NEAR YOU
          // ------------------------------------------
          if (popularDishes.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(title: 'Popular Food Near You 🔥'),
            ),
            const Gap(12),
            SizedBox(
              height: 225,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: popularDishes.length > 10 ? 10 : popularDishes.length,
                itemBuilder: (context, index) {
                  final dishMap = popularDishes[index];
                  final food = dishMap['food'] as FoodItem;
                  final rest = dishMap['restaurant'] as Restaurant;
                  return _buildPopularFoodCard(food, rest, isDark);
                },
              ),
            ),
            const Gap(24),
          ],

          // ------------------------------------------
          // SECTION 4: NEARBY RESTAURANTS
          // ------------------------------------------
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(title: 'Restaurants Near You 📍'),
          ),
          const Gap(12),

          if (restaurants.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Iconsax.location_slash, size: 44, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                    const Gap(12),
                    Text(
                      'No restaurants available in your delivery area.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.grey.shade400 : AppColors.textLight),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: restaurants.length,
              itemBuilder: (context, index) {
                final rest = restaurants[index];
                return RestaurantCard(
                  restaurant: rest,
                  onTap: () => context.push('/restaurant/${rest.id}'),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 2 CARD: AVAILABLE TABLE RESTAURANT
  // ==========================================
  Widget _buildTableRestaurantCard(Restaurant rest, bool isDark) {
    return GestureDetector(
      onTap: () => context.push('/restaurant/${rest.id}'),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: CachedNetworkImage(
                    imageUrl: rest.bannerUrl,
                    height: 105,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: Colors.grey.shade800),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                        const Gap(2),
                        Text(
                          rest.rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.table_restaurant, color: Colors.white, size: 12),
                        Gap(4),
                        Text(
                          'Tables Available',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rest.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const Gap(4),
                  Row(
                    children: [
                      Icon(Iconsax.location, size: 12, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
                      const Gap(4),
                      Text(
                        '${rest.distance} away',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SECTION 3 CARD: POPULAR FOOD CARD
  // ==========================================
  Widget _buildPopularFoodCard(FoodItem food, Restaurant rest, bool isDark) {
    return GestureDetector(
      onTap: () => context.push('/product/${rest.id}/${food.id}'),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: CachedNetworkImage(
                    imageUrl: food.imageUrl,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: Colors.grey.shade800),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Icon(
                    Icons.circle,
                    color: food.isVeg ? Colors.green : Colors.red,
                    size: 14,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 10),
                        const Gap(2),
                        Text(
                          food.rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    rest.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                    ),
                  ),
                  const Gap(6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${food.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          final cartNotifier = ref.read(cartProvider.notifier);
                          final cartItem = CartItem(
                            foodItem: food,
                            quantity: 1,
                            unitPrice: food.price,
                            restaurantId: rest.id,
                            restaurantName: rest.name,
                          );
                          cartNotifier.addItem(cartItem);
                          TopToast.show(context, '${food.name} added to cart');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.darkPrimary : AppColors.primary).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'ADD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FILTERED SEARCH RESULTS (WHEN QUERY / FILTERS ACTIVE)
  // ==========================================
  Widget _buildFilteredSearchResults(
    bool isDark,
    List<Restaurant> matchedRestaurants,
    List<Map<String, dynamic>> matchedDishes,
  ) {
    if (matchedRestaurants.isEmpty && matchedDishes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.search_status, size: 54, color: isDark ? AppColors.darkPrimary : AppColors.primary),
              const Gap(16),
              const Text(
                'No Results Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Gap(6),
              Text(
                'No dishes or restaurants matched your search or filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.grey.shade400 : AppColors.textLight),
              ),
              const Gap(16),
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                  foregroundColor: isDark ? AppColors.textDark : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: isDark ? AppColors.darkPrimary : AppColors.primary,
            labelColor: isDark ? AppColors.darkPrimary : AppColors.primary,
            unselectedLabelColor: isDark ? Colors.grey.shade400 : AppColors.textLight,
            tabs: [
              Tab(text: 'Dishes (${matchedDishes.length})'),
              Tab(text: 'Outlets (${matchedRestaurants.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Dishes Tab
                matchedDishes.isEmpty
                    ? _buildEmptyTab('No dishes match active search/filters')
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: matchedDishes.length,
                        itemBuilder: (context, index) {
                          final dishMap = matchedDishes[index];
                          final food = dishMap['food'] as FoodItem;
                          final rest = dishMap['restaurant'] as Restaurant;

                          return FoodCard(
                            foodItem: food,
                            restaurantId: rest.id,
                            restaurantName: rest.name,
                            onTap: () => context.push('/product/${rest.id}/${food.id}'),
                          );
                        },
                      ),

                // Outlets Tab
                matchedRestaurants.isEmpty
                    ? _buildEmptyTab('No restaurants match active search/filters')
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: matchedRestaurants.length,
                        itemBuilder: (context, index) {
                          final rest = matchedRestaurants[index];
                          return RestaurantCard(
                            restaurant: rest,
                            onTap: () => context.push('/restaurant/${rest.id}'),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTab(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textLight),
        ),
      ),
    );
  }

  // ==========================================
  // SHIMMER SKELETON LOADING
  // ==========================================
  Widget _buildShimmerSkeleton(bool isDark) {
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 140, height: 18, color: Colors.white),
            const Gap(12),
            Row(
              children: List.generate(
                4,
                (i) => Container(
                  width: 76,
                  height: 90,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const Gap(24),
            Container(width: 180, height: 18, color: Colors.white),
            const Gap(12),
            Row(
              children: List.generate(
                2,
                (i) => Container(
                  width: 200,
                  height: 160,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const Gap(24),
            Container(width: 160, height: 18, color: Colors.white),
            const Gap(12),
            Column(
              children: List.generate(
                3,
                (i) => Container(
                  height: 120,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
