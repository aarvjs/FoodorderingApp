import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/restaurant.dart';
import '../../models/food_item.dart';
import '../../models/category_model.dart';
import '../../models/offer_model.dart';
import '../../models/table_model.dart';
import '../utils/location_utils.dart';

class RestaurantRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? lastBookingError;

  /// Stream nearby restaurants/branches matching customer location delivery radius in real-time.
  Stream<List<Restaurant>> streamNearbyRestaurants({
    required double userLat,
    required double userLng,
  }) {
    if (userLat == 0.0 || userLng == 0.0) {
      print('[Restaurant Filter] Aborted: Valid user GPS coordinates are required before calculating restaurant distance (User: $userLat, $userLng).');
      return Stream.value([]);
    }

    return _firestore.collection('branches').snapshots().asyncMap((branchSnapshot) async {
      List<Restaurant> branchesList = [];

      print('[Restaurant Filter] Filtering branches against User Coordinates ($userLat, $userLng)...');

      for (var doc in branchSnapshot.docs) {
        final data = doc.data();

        // Check active / open status
        final status = (data['status'] ?? 'OPEN').toString().toUpperCase();
        if (status == 'INACTIVE' || status == 'DELETED' || status == 'CLOSED') continue;

        // Coordinates & service radius
        final double bLat = Restaurant.parseDouble(data['latitude'] ?? data['location']?['latitude']);
        final double bLng = Restaurant.parseDouble(data['longitude'] ?? data['location']?['longitude']);
        final double serviceRadiusKm = Restaurant.parseDouble(
          data['serviceRadiusKm'] ?? data['deliveryRadiusKm'] ?? data['deliveryRadius'] ?? data['radius'],
          fallback: 5.0,
        );

        final String outletName = (data['restaurantName'] ?? data['name'] ?? 'Restaurant').toString();

        // Strict GPS distance calculation using Geolocator.distanceBetween / Haversine formula
        final double distKm = (userLat != 0.0 && userLng != 0.0 && bLat != 0.0 && bLng != 0.0)
            ? (Geolocator.distanceBetween(userLat, userLng, bLat, bLng) / 1000.0)
            : LocationUtils.calculateDistance(userLat, userLng, bLat, bLng);

        final bool isWithinRadius = (userLat != 0.0 && userLng != 0.0 && bLat != 0.0 && bLng != 0.0) && distKm <= serviceRadiusKm;

        print('========================================');
        print('GPS\n$userLat\n$userLng');
        print('Restaurant\n$outletName');
        print('Restaurant Coordinates\n$bLat\n$bLng');
        print('Distance\n${distKm.toStringAsFixed(1)} km');
        print('Radius\n${serviceRadiusKm.toStringAsFixed(0)} km');
        print('Decision\n${isWithinRadius ? "VISIBLE" : "HIDDEN"}');
        print('========================================');

        if (!isWithinRadius) {
          continue; // Exclude branch if user is outside service radius
        }

        final restId = (data['restaurantId'] ?? doc.id).toString();
        final menuItems = await _fetchMenuForBranch(restId, doc.id);

        final restaurant = Restaurant.fromFirestore(
          docData: data,
          docId: doc.id,
          userLat: userLat,
          userLng: userLng,
          menuItems: menuItems,
        );

        branchesList.add(restaurant);
      }

      // Fallback query top-level `restaurants` collection if `branches` has no matches
      if (branchesList.isEmpty) {
        final restSnapshot = await _firestore.collection('restaurants').get();
        for (var doc in restSnapshot.docs) {
          final data = doc.data();
          final status = (data['status'] ?? 'ACTIVE').toString().toUpperCase();
          if (status == 'INACTIVE' || status == 'DELETED' || status == 'CLOSED') continue;

          final double rLat = Restaurant.parseDouble(data['latitude'] ?? data['location']?['latitude']);
          final double rLng = Restaurant.parseDouble(data['longitude'] ?? data['location']?['longitude']);
          final double serviceRadiusKm = Restaurant.parseDouble(
            data['serviceRadiusKm'] ?? data['deliveryRadiusKm'] ?? data['deliveryRadius'] ?? data['radius'],
            fallback: 5.0,
          );

          final String outletName = (data['name'] ?? 'Restaurant').toString();

          final double distKm = (userLat != 0.0 && userLng != 0.0 && rLat != 0.0 && rLng != 0.0)
              ? (Geolocator.distanceBetween(userLat, userLng, rLat, rLng) / 1000.0)
              : LocationUtils.calculateDistance(userLat, userLng, rLat, rLng);

          final bool isWithinRadius = (userLat != 0.0 && userLng != 0.0 && rLat != 0.0 && rLng != 0.0) && distKm <= serviceRadiusKm;

          print('========================================');
          print('Outlet (Fallback): "$outletName"');
          print('User Coordinates:\n$userLat\n$userLng');
          print('Branch Coordinates:\n$rLat\n$rLng');
          print('Distance:\n${distKm.toStringAsFixed(2)} km');
          print('Delivery Radius:\n${serviceRadiusKm.toStringAsFixed(0)} km');
          print('Decision:\n${isWithinRadius ? "VISIBLE" : "HIDDEN"}');
          print('========================================');

          if (!isWithinRadius) continue;

          final menuItems = await _fetchMenuForBranch(doc.id, doc.id);
          branchesList.add(Restaurant.fromFirestore(
            docData: data,
            docId: doc.id,
            userLat: userLat,
            userLng: userLng,
            menuItems: menuItems,
          ));
        }
      }

      print('[Restaurant Filter] Total nearby restaurants accepted: ${branchesList.length}');

      // Sort nearby restaurants strictly by distance ascending (closest first)
      branchesList.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return branchesList;
    });
  }

  /// Query food items from `menuItems` collection in Firestore
  Future<List<FoodItem>> _fetchMenuForBranch(String restaurantId, String branchId) async {
    try {
      var snap = await _firestore
          .collection('menuItems')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();

      if (snap.docs.isEmpty && branchId.isNotEmpty) {
        snap = await _firestore
            .collection('menuItems')
            .where('branchId', isEqualTo: branchId)
            .get();
      }

      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((doc) => FoodItem.fromFirestore(doc.data(), doc.id))
            .where((item) => item.isAvailable)
            .toList();
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  /// Stream real-time categories from Firestore `categories` collection
  Stream<List<CategoryModel>> streamCategories() {
    return _firestore.collection('categories').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc.data(), doc.id))
          .where((cat) => cat.isActive)
          .toList();
      return list;
    });
  }

  /// Stream real-time offers & banners from Firestore `offers` and `banners` collections
  Stream<List<OfferModel>> streamActiveOffers() {
    return _firestore.collection('offers').snapshots().asyncMap((snapshot) async {
      final offers = snapshot.docs
          .map((doc) => OfferModel.fromFirestore(doc.data(), doc.id))
          .where((offer) => offer.isActive)
          .toList();

      if (offers.isNotEmpty) return offers;

      // If `offers` collection is empty, check `banners` collection
      final bannerSnap = await _firestore.collection('banners').get();
      return bannerSnap.docs
          .map((doc) => OfferModel.fromFirestore(doc.data(), doc.id))
          .where((offer) => offer.isActive)
          .toList();
    });
  }

  /// Stream real-time active offers/coupons for a specific restaurant/branch from Firestore `offers` collection
  Stream<List<OfferModel>> streamRestaurantOffers(String restaurantId, {String? branchId}) {
    final String rId = restaurantId.trim();
    final String bId = (branchId ?? '').trim();

    return _firestore.collection('offers').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => OfferModel.fromFirestore(doc.data(), doc.id))
          .where((offer) {
            if (!offer.isActive) return false;

            final oRestId = (offer.restaurantId ?? '').trim();
            final oBranchId = (offer.branchId ?? '').trim();

            final bool matchesRest = oRestId.isEmpty ||
                oRestId.toLowerCase() == 'all' ||
                (rId.isNotEmpty && oRestId == rId);

            final bool matchesBranch = oBranchId.isEmpty ||
                oBranchId.toLowerCase() == 'all' ||
                (bId.isNotEmpty && oBranchId == bId) ||
                (rId.isNotEmpty && oBranchId == rId);

            return matchesRest || matchesBranch;
          })
          .toList();
    });
  }

  /// Stream real-time single restaurant details by ID (listening to `branches` or `restaurants`)
  Stream<Restaurant?> streamRestaurantDetails(String id, {double userLat = 0.0, double userLng = 0.0}) {
    return _firestore.collection('branches').doc(id).snapshots().asyncMap((doc) async {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final restId = (data['restaurantId'] ?? doc.id).toString();
        final menuItems = await _fetchMenuForBranch(restId, doc.id);
        return Restaurant.fromFirestore(
          docData: data,
          docId: doc.id,
          userLat: userLat,
          userLng: userLng,
          menuItems: menuItems,
        );
      }

      final restDoc = await _firestore.collection('restaurants').doc(id).get();
      if (restDoc.exists && restDoc.data() != null) {
        final menuItems = await _fetchMenuForBranch(id, id);
        return Restaurant.fromFirestore(
          docData: restDoc.data()!,
          docId: restDoc.id,
          userLat: userLat,
          userLng: userLng,
          menuItems: menuItems,
        );
      }

      return null;
    });
  }

  /// Stream real-time menu items for a specific restaurant/branch from Firestore `menuItems` collection
  Stream<List<FoodItem>> streamRestaurantMenu(String restaurantId, {String? branchId}) {
    return _firestore.collection('menuItems').snapshots().map((snapshot) {
      final String id1 = restaurantId.trim();
      final String id2 = (branchId ?? '').trim();

      return snapshot.docs
          .map((doc) => FoodItem.fromFirestore(doc.data(), doc.id))
          .where((item) {
            if (id1.isEmpty && id2.isEmpty) return true;

            final rMatch = (item.restaurantId != null && item.restaurantId!.isNotEmpty) &&
                (item.restaurantId == id1 || item.restaurantId == id2);

            final bMatch = (item.branchId != null && item.branchId!.isNotEmpty) &&
                (item.branchId == id1 || item.branchId == id2);

            final docMatch = (item.restaurantId == null || item.restaurantId!.isEmpty) &&
                (item.branchId == null || item.branchId!.isEmpty);

            return (rMatch || bMatch || docMatch) && item.isAvailable;
          })
          .toList();
    });
  }

  /// Stream real-time available tables for Table Booking feature
  Stream<List<TableModel>> streamAvailableTables(String idOrRestaurantId, {String? branchId}) {
    final String targetBranchId = (branchId != null && branchId.isNotEmpty) ? branchId.trim() : idOrRestaurantId.trim();
    final String targetRestId = idOrRestaurantId.trim();

    return _firestore.collection('tables').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TableModel.fromFirestore(doc.data(), doc.id))
          .where((table) {
            final String bId = table.branchId.trim();
            final String rId = table.restaurantId.trim();

            final bool bMatch = (bId.isNotEmpty && (bId == targetBranchId || bId == targetRestId)) ||
                (rId.isNotEmpty && (rId == targetBranchId || rId == targetRestId));

            final String st = table.status.toUpperCase();
            final bool isAvail = st == 'AVAILABLE' || st == 'OPEN' || st == 'ACTIVE';
            return bMatch && isAvail;
          })
          .toList();
    });
  }

  /// Stream branch gallery photos from `gallery` collection
  Stream<List<Map<String, dynamic>>> streamBranchGallery(String idOrRestaurantId, {String? branchId}) {
    final String targetBranchId = (branchId != null && branchId.isNotEmpty) ? branchId : idOrRestaurantId;
    final String targetRestId = idOrRestaurantId;

    return _firestore.collection('gallery').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((item) {
            final bId = (item['branchId'] ?? '').toString();
            final rId = (item['restaurantId'] ?? '').toString();
            return bId == targetBranchId || rId == targetBranchId || bId == targetRestId || rId == targetRestId;
          })
          .toList();
    });
  }

  /// Stream real-time table bookings for a specific customer
  Stream<List<TableBookingModel>> streamCustomerBookings(String customerId) {
    if (customerId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('tableBookings')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TableBookingModel.fromFirestore(doc.data(), doc.id))
          .where((b) => b.customerId == customerId || b.customerPhone.isNotEmpty)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Book a table in Firestore `tableBookings` collection
  Future<bool> createTableBooking(TableBookingModel booking) async {
    lastBookingError = null;
    print('[createTableBooking] Starting booking process...');
    print('[createTableBooking] Restaurant ID: ${booking.restaurantId}');
    print('[createTableBooking] Branch ID: ${booking.branchId}');
    print('[createTableBooking] Table ID: ${booking.tableId}');
    print('[createTableBooking] User ID: ${booking.customerId}');

    try {
      final docRef = _firestore.collection('tableBookings').doc();
      final newBooking = TableBookingModel(
        id: docRef.id,
        restaurantId: booking.restaurantId,
        branchId: booking.branchId,
        restaurantName: booking.restaurantName,
        branchName: booking.branchName,
        tableId: booking.tableId,
        tableNumber: booking.tableNumber,
        customerId: booking.customerId,
        customerName: booking.customerName,
        customerPhone: booking.customerPhone,
        customerEmail: booking.customerEmail,
        date: booking.date,
        time: booking.time,
        guests: booking.guests,
        specialRequest: booking.specialRequest,
        charges: booking.charges,
        gst: booking.gst,
        grandTotal: booking.grandTotal,
        status: 'PENDING',
        createdAt: DateTime.now(),
      );

      await docRef.set(newBooking.toMap());
      print('[createTableBooking] Firestore Write Result: SUCCESS');
      print('[createTableBooking] Firestore Document ID: ${docRef.id}');

      // Create notification for Branch Manager & Super Admin
      try {
        final notifRef = _firestore.collection('notifications').doc();
        await notifRef.set({
          'id': notifRef.id,
          'bookingId': docRef.id,
          'branchId': booking.branchId,
          'restaurantId': booking.restaurantId,
          'title': 'New Table Reservation Request! 🪑',
          'body': 'Table reservation for ${booking.customerName} (${booking.guests} Guests) on ${booking.date} at ${booking.time}.',
          'type': 'booking_created',
          'targetRole': 'BRANCH_MANAGER',
          'read': false,
          'createdAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('[createTableBooking] Notification error: $e');
      }

      // Update table status to RESERVED / PENDING (non-fatal if document missing or restricted)
      if (booking.tableId.isNotEmpty) {
        try {
          await _firestore.collection('tables').doc(booking.tableId).update({
            'status': 'RESERVED',
            'updatedAt': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          print('[createTableBooking] Non-fatal table status update error: $e');
        }
      }

      print('[createTableBooking] Success Flag: true');
      print('[createTableBooking] Return Value: true');
      return true;
    } catch (e) {
      lastBookingError = e.toString();
      print('[createTableBooking] Exception Message: $e');
      print('[createTableBooking] Success Flag: false');
      print('[createTableBooking] Return Value: false');
      return false;
    }
  }
}
