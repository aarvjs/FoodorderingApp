import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/food_card.dart';
import '../../core/widgets/restaurant_card.dart';
import '../../core/widgets/section_header.dart';
import '../../models/food_item.dart';
import '../../models/restaurant.dart';
import '../home/providers/restaurant_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final List<String> _recentSearches = ['Biryani', 'Pizza', 'Burger', 'Coffee'];
  
  final List<String> _popularSearches = [
    'Pasta', 'Healthy Salad', 'Gelato', 'Waffles', 'Chowmein', 'Chicken Roll'
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
    });
  }

  void _onSearchSubmit(String val) {
    if (val.trim().isEmpty) return;
    setState(() {
      _query = val.trim();
      if (!_recentSearches.contains(_query)) {
        _recentSearches.insert(0, _query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Real-time dynamic nearby restaurants stream
    final nearbyAsync = ref.watch(nearbyRestaurantsStreamProvider);
    final List<Restaurant> allRestaurants = nearbyAsync.value ?? [];
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    // Perform search filtering
    List<Restaurant> matchedRestaurants = [];
    List<Map<String, dynamic>> matchedDishes = []; // Map containing foodItem + restaurant details

    if (_query.isNotEmpty) {
      final lowercaseQuery = _query.toLowerCase();
      
      // Match restaurants
      matchedRestaurants = allRestaurants.where((r) {
        return r.name.toLowerCase().contains(lowercaseQuery) ||
            r.categories.any((c) => c.toLowerCase().contains(lowercaseQuery));
      }).toList();

      // Match food items across all restaurants
      for (var restaurant in allRestaurants) {
        for (var item in restaurant.items) {
          if (item.name.toLowerCase().contains(lowercaseQuery) ||
              item.description.toLowerCase().contains(lowercaseQuery) ||
              item.category.toLowerCase().contains(lowercaseQuery)) {
            matchedDishes.add({
              'food': item,
              'resId': restaurant.id,
              'resName': restaurant.name,
            });
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Dishes & Outlets'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Floating Input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  onChanged: (val) {
                    setState(() {
                      _query = val;
                    });
                  },
                  onSubmitted: _onSearchSubmit,
                  decoration: InputDecoration(
                    hintText: 'Search dishes, cuisines, or outlets...',
                    prefixIcon: Icon(Iconsax.search_normal_1, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),
            
            const Gap(8),

            // Content Area
            Expanded(
              child: _query.isEmpty
                  ? _buildEmptyQueryState(isDark, categoriesAsync.value?.map((c) => c.name).toList() ?? [])
                  : _buildSearchResults(isDark, matchedRestaurants, matchedDishes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyQueryState(bool isDark, List<String> dynamicCategories) {
    final categoriesToDisplay = dynamicCategories.isNotEmpty
        ? dynamicCategories
        : ['Pizza', 'Burger', 'Biryani', 'Chinese', 'Roll', 'Desserts'];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeader(title: 'Recent Searches'),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _recentSearches.clear();
                    });
                  },
                  child: const Text('Clear All', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
            const Gap(6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _recentSearches.map((item) {
                return _buildSearchChip(item, isDark);
              }).toList(),
            ),
            const Gap(24),
          ],

          // Popular Searches
          const SectionHeader(title: 'Popular Searches'),
          const Gap(12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _popularSearches.map((item) {
              return _buildSearchChip(item, isDark);
            }).toList(),
          ),
          const Gap(28),

          // Trending Cuisines / Categories
          const SectionHeader(title: 'Trending Categories'),
          const Gap(12),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categoriesToDisplay.length,
              itemBuilder: (context, index) {
                final catName = categoriesToDisplay[index];
                return GestureDetector(
                  onTap: () {
                    _searchController.text = catName;
                    _onSearchSubmit(catName);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.darkDivider : Colors.grey.shade100),
                    ),
                    child: Center(
                      child: Text(
                        catName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchChip(String label, bool isDark) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _onSearchSubmit(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.trend_up, size: 14, color: isDark ? AppColors.darkPrimary : AppColors.primary),
            const Gap(6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    bool isDark,
    List<Restaurant> matchedRestaurants,
    List<Map<String, dynamic>> matchedDishes,
  ) {
    if (matchedRestaurants.isEmpty && matchedDishes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.info_circle, size: 48, color: isDark ? AppColors.darkPrimary : AppColors.primary),
            const Gap(16),
            const Text(
              'No Results Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Gap(6),
            Text(
              'Try searching for something else.',
              style: TextStyle(color: isDark ? Colors.grey.shade400 : AppColors.textLight),
            ),
          ],
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
                    ? _buildEmptyTab('No dishes found matching "$_query"')
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: matchedDishes.length,
                        itemBuilder: (context, index) {
                          final dishMap = matchedDishes[index];
                          final food = dishMap['food'] as FoodItem;
                          final resId = dishMap['resId'] as String;
                          final resName = dishMap['resName'] as String;
                          
                          return FoodCard(
                            foodItem: food,
                            restaurantId: resId,
                            restaurantName: resName,
                            onTap: () => context.push('/product/$resId/${food.id}'),
                          );
                        },
                      ),

                // Restaurants Tab
                matchedRestaurants.isEmpty
                    ? _buildEmptyTab('No restaurants found matching "$_query"')
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
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: AppColors.textLight),
      ),
    );
  }
}
