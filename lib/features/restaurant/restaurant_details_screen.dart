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
import '../../auth/providers/auth_provider.dart';
import '../home/providers/restaurant_providers.dart';

class RestaurantDetailsScreen extends ConsumerStatefulWidget {
  final String restaurantId;

  const RestaurantDetailsScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<RestaurantDetailsScreen> createState() => _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState extends ConsumerState<RestaurantDetailsScreen> {
  String? _selectedCategory;
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
    final menuAsync = ref.watch(restaurantMenuStreamProvider(widget.restaurantId));

    final restaurant = detailsAsync.value;
    final List<FoodItem> dynamicMenu = (menuAsync.value != null && menuAsync.value!.isNotEmpty)
        ? menuAsync.value!
        : (restaurant?.items ?? []);

    // Watch cart state to show floating 'View Cart' banner
    final cartState = ref.watch(cartProvider);
    final totalItemsInCart = cartState.items.fold<int>(0, (sum, item) => sum + item.quantity);

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
                          _buildLogisticsColumn(Iconsax.ticket_discount, 'Offer', restaurant.offerText, isDark, highlight: true),
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
                      const Gap(16),

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
                            hintText: 'Search within restaurant menu...',
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

              // Sticky Categories Header Tabs
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

              // Menu Dishes List
              SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                sliver: filteredItems.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              'No dishes found matching filters.',
                              style: TextStyle(color: isDark ? Colors.grey.shade400 : AppColors.textLight),
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
                      ),
              ),
            ],
          ),

          // Floating View Cart Bar (at bottom)
          if (totalItemsInCart > 0 && cartState.items.first.restaurantId == restaurant.id)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: isDark ? AppColors.darkGradient : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? AppColors.darkPrimary : AppColors.primary).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$totalItemsInCart ITEM${totalItemsInCart > 1 ? 'S' : ''} ADDED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '₹${cartState.total}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => context.push('/cart'),
                      child: const Row(
                        children: [
                          Text(
                            'View Cart',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Gap(4),
                          Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to book table. Please try again.')),
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
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No tables currently available for online booking.',
                      style: TextStyle(color: isDark ? Colors.grey.shade400 : AppColors.textLight),
                    ),
                  ),
                );
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
