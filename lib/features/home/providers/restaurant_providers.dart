import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/restaurant_repository.dart';
import '../../../models/restaurant.dart';
import '../../../models/food_item.dart';
import '../../../models/category_model.dart';
import '../../../models/offer_model.dart';
import '../../../models/table_model.dart';
import '../../address/providers/address_provider.dart';
import '../../../auth/providers/auth_provider.dart';

import '../../../core/services/combo_repository.dart';
import '../../../models/combo_model.dart';
import '../../../models/combo_item_model.dart';

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepository();
});

final comboRepositoryProvider = Provider<ComboRepository>((ref) {
  return ComboRepository();
});

/// Stream provider family for restaurant combos
final restaurantCombosStreamProvider = StreamProvider.family<List<ComboModel>, String>((ref, restaurantId) {
  final repo = ref.watch(comboRepositoryProvider);
  final detailsAsync = ref.watch(restaurantDetailsStreamProvider(restaurantId));
  final restaurant = detailsAsync.value;
  final parentRestId = restaurant?.restaurantId;
  final branchId = restaurant?.id ?? restaurantId;
  return repo.streamRestaurantCombos(parentRestId ?? restaurantId, branchId: branchId);
});

/// Stream provider family for dedicated items in a combo
final comboItemsStreamProvider = StreamProvider.family<List<ComboItemModel>, String>((ref, comboId) {
  final repo = ref.watch(comboRepositoryProvider);
  return repo.streamComboItems(comboId);
});

/// Stream provider family for a single dynamic combo doc (real-time active/inactive status)
final singleComboStreamProvider = StreamProvider.family<ComboModel?, String>((ref, comboId) {
  final repo = ref.watch(comboRepositoryProvider);
  return repo.streamSingleCombo(comboId);
});

/// Stream provider family for a single dynamic combo item (real-time customization groups & options)
final singleComboItemStreamProvider = StreamProvider.family<ComboItemModel?, String>((ref, itemId) {
  final repo = ref.watch(comboRepositoryProvider);
  return repo.streamSingleComboItem(itemId);
});

/// Stream provider for nearby restaurants filtered dynamically by delivery radius of customer's selected address
final nearbyRestaurantsStreamProvider = StreamProvider<List<Restaurant>>((ref) {
  final addressState = ref.watch(addressProvider);
  final selectedAddress = addressState.selectedAddress;

  final userLat = selectedAddress?.latitude ?? 0.0;
  final userLng = selectedAddress?.longitude ?? 0.0;

  final repo = ref.watch(restaurantRepositoryProvider);

  return repo.streamNearbyRestaurants(userLat: userLat, userLng: userLng);
});

/// Stream provider for dynamic food categories from Firestore
final categoriesStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.streamCategories();
});

/// Stream provider for dynamic promotional banners and offers from Firestore
final offersStreamProvider = StreamProvider<List<OfferModel>>((ref) {
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.streamActiveOffers();
});

/// Stream provider family for restaurant specific offers / coupons
final restaurantOffersStreamProvider = StreamProvider.family<List<OfferModel>, String>((ref, restaurantId) {
  final repo = ref.watch(restaurantRepositoryProvider);
  final detailsAsync = ref.watch(restaurantDetailsStreamProvider(restaurantId));
  final restaurant = detailsAsync.value;
  final parentRestId = restaurant?.restaurantId;
  final branchId = restaurant?.id ?? restaurantId;
  return repo.streamRestaurantOffers(parentRestId ?? restaurantId, branchId: branchId);
});

/// Stream provider family for single restaurant details
final restaurantDetailsStreamProvider = StreamProvider.family<Restaurant?, String>((ref, id) {
  final addressState = ref.watch(addressProvider);
  final userLat = addressState.selectedAddress?.latitude ?? 0.0;
  final userLng = addressState.selectedAddress?.longitude ?? 0.0;

  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.streamRestaurantDetails(id, userLat: userLat, userLng: userLng);
});

/// Stream provider family for restaurant menu items
final restaurantMenuStreamProvider = StreamProvider.family<List<FoodItem>, String>((ref, restaurantId) {
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.streamRestaurantMenu(restaurantId);
});

/// Stream provider family for available restaurant tables
final availableTablesStreamProvider = StreamProvider.family<List<TableModel>, String>((ref, idOrRestaurantId) {
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.streamAvailableTables(idOrRestaurantId);
});

/// Stream provider family for branch gallery photos
final branchGalleryStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, idOrBranchId) {
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.streamBranchGallery(idOrBranchId);
});

/// Stream provider for customer table bookings
final customerBookingsStreamProvider = StreamProvider<List<TableBookingModel>>((ref) {
  final authState = ref.watch(authProvider);
  final userId = authState.userModel?.uid ?? '';
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.streamCustomerBookings(userId);
});
