import 'dart:async';
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
import '../../models/combo_item_model.dart';
import '../../models/cart_item.dart';
import '../home/providers/restaurant_providers.dart';
import '../product/combo_customization_sheet.dart';


class RestaurantDetailsScreen extends ConsumerStatefulWidget {
  final String restaurantId;

  const RestaurantDetailsScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<RestaurantDetailsScreen> createState() => _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState extends ConsumerState<RestaurantDetailsScreen> {
  String _selectedNavId = 'ALL'; // 'ALL', 'MENU' or combo.id
  final TextEditingController _menuSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _menuSearchQuery = '';

  bool _calculateIsOpen(Restaurant restaurant) {
    if (!restaurant.isOpen) return false;

    try {
      final now = DateTime.now();
      final openTime = _parseTimeOfDay(restaurant.openingTime);
      final closeTime = _parseTimeOfDay(restaurant.closingTime);

      if (openTime == null || closeTime == null) return restaurant.isOpen;

      final currentMinutes = now.hour * 60 + now.minute;
      final openMinutes = openTime.hour * 60 + openTime.minute;
      final closeMinutes = closeTime.hour * 60 + closeTime.minute;

      if (closeMinutes > openMinutes) {
        return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
      } else {
        return currentMinutes >= openMinutes || currentMinutes <= closeMinutes;
      }
    } catch (e) {
      return restaurant.isOpen;
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    if (timeStr.isEmpty) return null;
    try {
      final cleaned = timeStr.trim().toUpperCase();
      final isPM = cleaned.contains('PM');
      final isAM = cleaned.contains('AM');
      final digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digitsOnly.split(':');
      if (parts.isEmpty || parts[0].isEmpty) return null;

      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 && parts[1].isNotEmpty ? int.parse(parts[1]) : 0;

      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
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

  void _onAddComboItem(
    ComboItemModel item,
    ComboModel combo,
    Restaurant restaurant,
  ) {
    final bool isComboActive = combo.isActive;
    if (!isComboActive) {
      TopToast.show(context, 'This combo is currently unavailable.');
      return;
    }

    final String targetBranchId = (restaurant.branchId.isNotEmpty)
        ? restaurant.branchId
        : (restaurant.id.isNotEmpty ? restaurant.id : item.restaurantId);
    final String targetRestId = (restaurant.restaurantId.isNotEmpty)
        ? restaurant.restaurantId
        : targetBranchId;
    final String targetRestName = restaurant.name;

    final groups = item.customizationGroups;
    if (groups.isNotEmpty || item.isCustomisable || item.isVariantEnabled) {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ComboProductCustomizationSheet(
          item: item,
          combo: combo,
          restaurantId: targetRestId,
          branchId: targetBranchId,
          restaurantName: targetRestName,
        ),
      );
    } else {
      final foodItem = FoodItem(
        id: item.id,
        name: '${combo.name} - ${item.name}',
        description: item.description,
        price: item.price,
        imageUrl: item.image,
        isVeg: item.isVeg,
        rating: item.rating,
        reviewCount: item.ratingCount,
        ingredients: const [],
        nutrition: const {},
        reviews: const [],
        restaurantId: targetRestId,
        branchId: targetBranchId,
        category: 'Combos',
        isAvailable: true,
      );

      final cartItem = CartItem(
        foodItem: foodItem,
        quantity: 1,
        restaurantId: targetRestId,
        branchId: targetBranchId,
        restaurantName: targetRestName,
        isCombo: true,
        comboId: combo.id,
        comboName: combo.name,
        comboItemId: item.id,
        unitPrice: item.price,
        basePrice: item.price,
      );

      ref.read(cartProvider.notifier).addItem(cartItem);

      TopToast.show(
        context,
        'Added "${item.name}" to cart!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen to real-time Firestore streams for restaurant details & menu
    final detailsAsync = ref.watch(restaurantDetailsStreamProvider(widget.restaurantId));
    final restaurant = detailsAsync.value;

    final menuAsync = ref.watch(restaurantMenuStreamProvider(widget.restaurantId));
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

    // Filter menu items by search query
    final query = _menuSearchQuery.trim().toLowerCase();
    var filteredItems = dynamicMenu;
    if (query.isNotEmpty) {
      filteredItems = filteredItems.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query);
      }).toList();
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Scrollable Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom Sliver App Bar with Dynamic Image Slider
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                stretch: true,
                backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
                flexibleSpace: FlexibleSpaceBar(
                  background: _RestaurantHeaderSlider(
                    restaurant: restaurant,
                    isDark: isDark,
                  ),
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.4),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    onPressed: () => context.pop(),
                  ),
                ),
                actions: const [
                  Gap(12),
                ],
              ),

              // Restaurant Info details Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Restaurant Name & Rating Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Restaurant Name (Visually prominent)
                                Text(
                                  restaurant.name,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : AppColors.textDark,
                                    letterSpacing: -0.5,
                                  ),
                                ),

                                // Branch Name (Subtle underneath)
                                if (restaurant.branchName.isNotEmpty && restaurant.branchName != restaurant.name) ...[
                                  const Gap(3),
                                  Text(
                                    '📍 ${restaurant.branchName}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Gap(8),
                          // Rating Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Gap(3),
                                const Icon(Icons.star, color: Colors.white, size: 13),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Categories / Cuisine list
                      if (restaurant.categories.isNotEmpty) ...[
                        const Gap(6),
                        Text(
                          restaurant.categories.join(' • '),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                          ),
                        ),
                      ],

                      // 2. Description
                      if (restaurant.description.isNotEmpty) ...[
                        const Gap(8),
                        Text(
                          restaurant.description,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                            height: 1.35,
                          ),
                        ),
                      ],

                      const Gap(12),

                      // 3. Contact + Timing + OPEN/CLOSED Status in one clean horizontal row
                      Builder(
                        builder: (context) {
                          final bool isCalculatedOpen = _calculateIsOpen(restaurant);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 📞 Branch Contact Number
                                Flexible(
                                  flex: 5,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.phone_in_talk_rounded, size: 14, color: AppColors.primary),
                                      const Gap(6),
                                      Expanded(
                                        child: Text(
                                          restaurant.phone.isNotEmpty ? restaurant.phone : 'N/A',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AppColors.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Gap(8),

                                // 🕒 Operating Timing & Status Badge
                                Flexible(
                                  flex: 6,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 14, color: AppColors.primary),
                                      const Gap(4),
                                      Flexible(
                                        child: Text(
                                          isCalculatedOpen
                                              ? '${restaurant.openingTime} – ${restaurant.closingTime}'
                                              : 'Opens ${restaurant.openingTime}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.grey.shade300 : AppColors.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Gap(6),
                                      // Status Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isCalculatedOpen
                                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                              : Colors.red.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isCalculatedOpen
                                                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                                : Colors.red.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Text(
                                          isCalculatedOpen ? 'OPEN' : 'CLOSED',
                                          style: TextStyle(
                                            color: isCalculatedOpen ? const Color(0xFF047857) : Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
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

                      const Gap(14),
                      const Divider(),
                      const Gap(12),

                      // 1. Search Bar: "Search menu or combos"
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                          ),
                        ),
                        child: TextField(
                          controller: _menuSearchController,
                          focusNode: _searchFocusNode,
                          autofocus: false,
                          onChanged: (val) {
                            setState(() {
                              _menuSearchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search menu or combos',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                            ),
                            prefixIcon: Icon(
                              Iconsax.search_normal_1,
                              size: 18,
                              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                            ),
                            suffixIcon: _menuSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _menuSearchController.clear();
                                      _searchFocusNode.unfocus();
                                      setState(() {
                                        _menuSearchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      const Gap(12),

                      // 2. Single Top Horizontal Navigation Row: [ Menu ] [ 🖼 Combo 1 ] [ 🖼 Combo 2 ] ...
                      _buildTopHorizontalNav(
                        combosList: combosList,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),

              // Content View (ALL Items, Menu Items or Selected Combo Items List)
              if (_selectedNavId == 'ALL') ...[
                _buildAllProductsSliver(
                  filteredMenuItems: filteredItems,
                  isMenuLoading: isMenuLoading,
                  combosList: combosList,
                  restaurant: restaurant,
                  isDark: isDark,
                  query: query,
                ),
                SliverToBoxAdapter(
                  child: _buildFssaiFooter(restaurant, isDark),
                ),
              ] else if (_selectedNavId == 'MENU') ...[
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 20),
                  sliver: isMenuLoading
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
                                        _menuSearchQuery.isNotEmpty
                                            ? 'No menu products matching "$_menuSearchQuery"'
                                            : 'No menu items available for this outlet.',
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
                            )),
                ),
                SliverToBoxAdapter(
                  child: _buildFssaiFooter(restaurant, isDark),
                ),
              ] else ...[
                // Selected Combo Products Sliver
                _buildSelectedComboSliver(
                  comboId: _selectedNavId,
                  combosList: combosList,
                  restaurant: restaurant,
                  isDark: isDark,
                ),
                SliverToBoxAdapter(
                  child: _buildFssaiFooter(restaurant, isDark),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfferBadgePill(AsyncValue<List<OfferModel>> offersAsync, Restaurant restaurant, bool isDark) {
    final offersList = offersAsync.value ?? [];
    final int offersCount = offersList.length;

    String labelText = '';
    if (offersCount > 0) {
      labelText = '$offersCount OFFER${offersCount > 1 ? 'S' : ''}';
    } else if (restaurant.offerText.isNotEmpty && !restaurant.offerText.contains('50% OFF')) {
      labelText = restaurant.offerText;
    }

    if (labelText.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.ticket, size: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            const Gap(4),
            Text(
              'No offers available',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
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

  Widget _buildTopHorizontalNav({
    required List<ComboModel> combosList,
    required bool isDark,
  }) {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: combosList.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedNavId == 'ALL';
            return GestureDetector(
              onTap: () {
                _searchFocusNode.unfocus();
                setState(() {
                  _selectedNavId = 'ALL';
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkCard : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkDivider : Colors.grey.shade300),
                    width: isSelected ? 1.6 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.grid_5,
                      size: 15,
                      color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : AppColors.textDark),
                    ),
                    const Gap(6),
                    Text(
                      'ALL',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (index == 1) {
            final isSelected = _selectedNavId == 'MENU';
            return GestureDetector(
              onTap: () {
                _searchFocusNode.unfocus();
                setState(() {
                  _selectedNavId = 'MENU';
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkCard : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkDivider : Colors.grey.shade300),
                    width: isSelected ? 1.6 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.element_4,
                      size: 15,
                      color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : AppColors.textDark),
                    ),
                    const Gap(6),
                    Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final combo = combosList[index - 2];
          final isSelected = _selectedNavId == combo.id;

          return GestureDetector(
            onTap: () {
              _searchFocusNode.unfocus();
              setState(() {
                _selectedNavId = combo.id;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkCard : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkDivider : Colors.grey.shade300),
                  width: isSelected ? 1.6 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      combo.image,
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 24,
                        height: 24,
                        color: isSelected ? Colors.white24 : Colors.grey.shade300,
                        child: Icon(
                          Icons.fastfood,
                          size: 14,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const Gap(6),
                  Text(
                    combo.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey.shade300 : AppColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAllProductsSliver({
    required List<FoodItem> filteredMenuItems,
    required bool isMenuLoading,
    required List<ComboModel> combosList,
    required Restaurant restaurant,
    required bool isDark,
    required String query,
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final List<Widget> sliverWidgets = [];

        // 1. Normal Menu Items Section
        if (filteredMenuItems.isNotEmpty) {
          if (combosList.isNotEmpty) {
            sliverWidgets.add(
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Row(
                  children: [
                    const Icon(Iconsax.element_4, size: 16, color: AppColors.primary),
                    const Gap(6),
                    Text(
                      'Menu Items (${filteredMenuItems.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          for (final foodItem in filteredMenuItems) {
            sliverWidgets.add(
              FoodCard(
                foodItem: foodItem,
                restaurantId: restaurant.id,
                restaurantName: restaurant.name,
                onTap: () => context.push('/product/${restaurant.id}/${foodItem.id}'),
              ),
            );
          }
        }

        // 2. Combos Section
        int totalMatchingComboItems = 0;

        for (final combo in combosList) {
          final comboItemsAsync = ref.watch(comboItemsStreamProvider(combo.id));
          final comboItems = comboItemsAsync.value ?? [];

          final filteredComboItems = query.isEmpty
              ? comboItems
              : comboItems.where((item) {
                  return item.name.toLowerCase().contains(query) ||
                      item.description.toLowerCase().contains(query);
                }).toList();

          if (filteredComboItems.isNotEmpty) {
            totalMatchingComboItems += filteredComboItems.length;

            sliverWidgets.add(
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        combo.image,
                        width: 18,
                        height: 18,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 16, color: AppColors.primary),
                      ),
                    ),
                    const Gap(6),
                    Text(
                      '${combo.name} (${filteredComboItems.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            );

            for (final item in filteredComboItems) {
              sliverWidgets.add(
                _buildComboItemTile(
                  item: item,
                  combo: combo,
                  restaurant: restaurant,
                  isDark: isDark,
                ),
              );
            }
          }
        }

        // 3. Empty State if no menu items and no combo items match
        if (filteredMenuItems.isEmpty && totalMatchingComboItems == 0) {
          if (isMenuLoading) {
            return SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 20),
              sliver: SliverList(
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
              ),
            );
          }

          return SliverToBoxAdapter(
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
                      query.isNotEmpty
                          ? 'No products matching "$query"'
                          : 'No items available for this outlet.',
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
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => sliverWidgets[index],
              childCount: sliverWidgets.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFssaiFooter(Restaurant restaurant, bool isDark) {
    final rawFssai = restaurant.fssaiNo.trim();
    String displayFssai = 'N/A';

    if (rawFssai.isNotEmpty) {
      if (rawFssai.toUpperCase().contains('FSSAI')) {
        displayFssai = rawFssai;
      } else {
        displayFssai = 'FSSAI No: $rawFssai';
      }
    } else {
      displayFssai = 'FSSAI No: N/A';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 100),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  size: 15,
                  color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                ),
              ),
              const Gap(8),
              Text(
                displayFssai,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey.shade300 : AppColors.textDark,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedComboSliver({
    required String comboId,
    required List<ComboModel> combosList,
    required Restaurant restaurant,
    required bool isDark,
  }) {
    final combo = combosList.firstWhere(
      (c) => c.id == comboId,
      orElse: () => combosList.isNotEmpty ? combosList.first : const ComboModel(id: '', name: '', image: '', restaurantId: '', branchIds: []),
    );

    if (combo.id.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              'Combo unavailable.',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
      sliver: Consumer(
        builder: (context, ref, child) {
          final comboItemsAsync = ref.watch(comboItemsStreamProvider(combo.id));
          final comboItems = comboItemsAsync.value ?? [];

          if (comboItemsAsync.isLoading && comboItems.isEmpty) {
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
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
                childCount: 3,
              ),
            );
          }

          final query = _menuSearchQuery.trim().toLowerCase();
          final filteredComboItems = query.isEmpty
              ? comboItems
              : comboItems.where((item) {
                  return item.name.toLowerCase().contains(query) ||
                      item.description.toLowerCase().contains(query);
                }).toList();

          if (filteredComboItems.isEmpty) {
            return SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.fastfood_outlined,
                        size: 48,
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                      const Gap(12),
                      Text(
                        query.isNotEmpty
                            ? 'No products in "${combo.name}" matching "$query"'
                            : 'No products in "${combo.name}" yet.',
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
            );
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = filteredComboItems[index];
                return _buildComboItemTile(
                  item: item,
                  combo: combo,
                  restaurant: restaurant,
                  isDark: isDark,
                );
              },
              childCount: filteredComboItems.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildComboItemTile({
    required ComboItemModel item,
    required ComboModel combo,
    required Restaurant restaurant,
    required bool isDark,
  }) {
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.isVeg ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: item.isVeg ? Colors.green.shade600 : Colors.red.shade600,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 7,
                        color: item.isVeg ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                      const Gap(4),
                      Text(
                        item.foodType.isNotEmpty ? item.foodType : (item.isVeg ? 'Veg' : 'Non Veg'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: item.isVeg ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(6),
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const Gap(4),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Gap(6),
                Row(
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const Gap(8),
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFEAB308)),
                    const Gap(2),
                    Text(
                      '${item.rating.toStringAsFixed(1)} (${item.ratingCount})',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Gap(12),

          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  item.image,
                  height: 76,
                  width: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 76,
                    width: 76,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    child: const Icon(Icons.fastfood, size: 28, color: AppColors.primary),
                  ),
                ),
              ),
              const Gap(8),
              ElevatedButton(
                onPressed: () => _onAddComboItem(item, combo, restaurant),
                style: ElevatedButton.styleFrom(
                  backgroundColor: combo.isActive ? AppColors.primary : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  minimumSize: const Size(76, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                ),
                child: const Text(
                  'ADD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (item.isCustomisable || item.customizationGroups.isNotEmpty || item.isVariantEnabled) ...[
                const Gap(3),
                Text(
                  'CUSTOMISABLE',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ],
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

class _RestaurantHeaderSlider extends StatefulWidget {
  final Restaurant restaurant;
  final bool isDark;

  const _RestaurantHeaderSlider({
    required this.restaurant,
    required this.isDark,
  });

  @override
  State<_RestaurantHeaderSlider> createState() => _RestaurantHeaderSliderState();
}

class _RestaurantHeaderSliderState extends State<_RestaurantHeaderSlider> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _autoSlideTimer;

  List<String> _getImages() {
    try {
      final list = widget.restaurant.sliderImages;
      if (list.isNotEmpty) {
        return list;
      }
    } catch (_) {}
    return const [
      'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&q=80&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800&q=80&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80&auto=format&fit=crop',
    ];
  }



  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final images = _getImages();
      if (images.length > 1 && _pageController.hasClients) {
        final nextIndex = (_currentIndex + 1) % images.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _getImages();

    if (images.isEmpty) {
      return Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: Icon(Icons.restaurant, size: 48, color: Colors.white),
        ),
      );
    }

    if (images.length == 1) {
      return Hero(
        tag: 'restaurant_banner_${widget.restaurant.id}',
        child: Image.network(
          images.first,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade900,
            child: const Center(child: Icon(Icons.restaurant, size: 48, color: Colors.white)),
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (idx) {
            setState(() {
              _currentIndex = idx;
            });
          },
          itemBuilder: (context, index) {
            return Image.network(
              images[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade900,
                child: const Center(child: Icon(Icons.restaurant, size: 48, color: Colors.white)),
              ),
            );
          },
        ),

        // Gradient Overlay at top & bottom for clarity
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black45, Colors.transparent, Colors.black38],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // Carousel Page Indicators (Dots)
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (index) {
              final bool isSelected = index == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: isSelected ? 20 : 6,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}


