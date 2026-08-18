import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/delivery_charge_slab.dart';
import '../utils/location_utils.dart';
import 'state_providers.dart';

class DeliveryChargeCalculationResult {
  final double distanceKm;
  final double deliveryFee;
  final double maxRadiusKm;
  final double taxPercentage;
  final bool isMaxRadiusConfigured;
  final bool isOutsideRadius;
  final bool hasSlabs;
  final String? errorMessage;

  const DeliveryChargeCalculationResult({
    required this.distanceKm,
    required this.deliveryFee,
    required this.maxRadiusKm,
    this.taxPercentage = 0.0,
    required this.isMaxRadiusConfigured,
    required this.isOutsideRadius,
    required this.hasSlabs,
    this.errorMessage,
  });

  factory DeliveryChargeCalculationResult.empty() {
    return const DeliveryChargeCalculationResult(
      distanceKm: 0.0,
      deliveryFee: 0.0,
      maxRadiusKm: 20.0,
      taxPercentage: 0.0,
      isMaxRadiusConfigured: false,
      isOutsideRadius: false,
      hasSlabs: false,
    );
  }
}

class DeliveryChargeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate distance-based delivery charge & fetch branch GST percentage for given customer GPS and target branch/restaurant ID
  Future<DeliveryChargeCalculationResult> calculateDeliveryCharge({
    required String branchId,
    required String restaurantId,
    required double userLat,
    required double userLng,
  }) async {
    final String targetBranchId = branchId.isNotEmpty ? branchId : restaurantId;
    if (targetBranchId.isEmpty) {
      return DeliveryChargeCalculationResult.empty();
    }

    try {
      // 1. Fetch Branch or Restaurant Document from Firestore
      double branchLat = 0.0;
      double branchLng = 0.0;
      double maxRadiusKm = 20.0;
      double taxPercentage = 0.0;
      bool isMaxRadiusConfigured = false;

      Map<String, dynamic>? branchData;

      // Direct lookup in 'branches' collection by document ID
      DocumentSnapshot branchSnap = await _firestore.collection('branches').doc(targetBranchId).get();
      if (branchSnap.exists && branchSnap.data() != null) {
        branchData = branchSnap.data() as Map<String, dynamic>?;
      }

      // If not found by doc ID, check if branchId field matches targetBranchId
      if (branchData == null) {
        final querySnap = await _firestore
            .collection('branches')
            .where('branchId', isEqualTo: targetBranchId)
            .limit(1)
            .get();
        if (querySnap.docs.isNotEmpty) {
          branchData = querySnap.docs.first.data();
        }
      }

      // Fallback only if targetBranchId is not a branch ID at all
      if (branchData == null && restaurantId.isNotEmpty && restaurantId != targetBranchId) {
        final restBranchSnap = await _firestore.collection('branches').doc(restaurantId).get();
        if (restBranchSnap.exists && restBranchSnap.data() != null) {
          branchData = restBranchSnap.data();
        } else {
          final restSnap = await _firestore.collection('restaurants').doc(restaurantId).get();
          if (restSnap.exists) {
            branchData = restSnap.data();
          }
        }
      }

      if (branchData != null) {
        branchLat = _numToDouble(branchData['latitude'] ?? branchData['location']?['latitude']);
        branchLng = _numToDouble(branchData['longitude'] ?? branchData['location']?['longitude']);

        isMaxRadiusConfigured = branchData['maxRadiusConfigured'] == true;
        maxRadiusKm = _numToDouble(
          branchData['serviceRadiusKm'] ?? branchData['maximumDeliveryRadius'] ?? branchData['deliveryRadiusKm'] ?? branchData['deliveryRadius'] ?? branchData['radius'],
          fallback: 20.0,
        );

        taxPercentage = _numToDouble(
          branchData['taxPercentage'] ?? branchData['gstPercentage'] ?? branchData['tax'] ?? branchData['taxRate'],
          fallback: 0.0,
        );
      }

      // 2. Customer location validation
      if (userLat == 0.0 || userLng == 0.0 || branchLat == 0.0 || branchLng == 0.0) {
        return DeliveryChargeCalculationResult(
          distanceKm: 0.0,
          deliveryFee: 0.0,
          maxRadiusKm: maxRadiusKm,
          taxPercentage: taxPercentage,
          isMaxRadiusConfigured: isMaxRadiusConfigured,
          isOutsideRadius: false,
          hasSlabs: false,
          errorMessage: 'Location coordinates unavailable to calculate distance.',
        );
      }

      // 3. Calculate distance using Haversine formula
      final double distKm = LocationUtils.calculateDistance(userLat, userLng, branchLat, branchLng);

      // 4. Fetch Active Slabs from Firestore collection 'delivery_charge_slabs'
      List<DeliveryChargeSlab> slabs = [];

      // Query slabs by branchId first
      QuerySnapshot slabSnap = await _firestore
          .collection('delivery_charge_slabs')
          .where('branchId', isEqualTo: targetBranchId)
          .get();

      if (slabSnap.docs.isEmpty && restaurantId.isNotEmpty) {
        slabSnap = await _firestore
            .collection('delivery_charge_slabs')
            .where('restaurantId', isEqualTo: restaurantId)
            .get();
      }

      slabs = slabSnap.docs
          .map((doc) => DeliveryChargeSlab.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((s) => s.isActive)
          .toList();

      slabs.sort((a, b) => a.minDistanceKm.compareTo(b.minDistanceKm));

      // 5. Check if distance exceeds Maximum Delivery Radius
      final bool isOutsideRadius = distKm > maxRadiusKm;
      if (isOutsideRadius) {
        final String formattedDist = LocationUtils.formatDistance(distKm);
        return DeliveryChargeCalculationResult(
          distanceKm: distKm,
          deliveryFee: 0.0,
          maxRadiusKm: maxRadiusKm,
          taxPercentage: taxPercentage,
          isMaxRadiusConfigured: isMaxRadiusConfigured,
          isOutsideRadius: true,
          hasSlabs: slabs.isNotEmpty,
          errorMessage: 'Delivery unavailable: Your location ($formattedDist) is outside the maximum delivery radius of ${maxRadiusKm.toStringAsFixed(1)} KM.',
        );
      }

      // 6. Find matching distance slab
      double calculatedFee = 0.0;
      bool matched = false;

      if (slabs.isNotEmpty) {
        for (final slab in slabs) {
          // Range check: min <= dist < max (or <= max if dist equals max boundary)
          if (distKm >= slab.minDistanceKm && (distKm < slab.maxDistanceKm || (distKm == slab.maxDistanceKm))) {
            calculatedFee = slab.deliveryCharge;
            matched = true;
            break;
          }
        }

        // If distance is past the last slab's min distance but within maxRadius, match highest slab
        if (!matched && distKm >= slabs.last.minDistanceKm) {
          calculatedFee = slabs.last.deliveryCharge;
          matched = true;
        }

        // If distance is below the first slab's min distance, match lowest slab
        if (!matched && distKm < slabs.first.minDistanceKm) {
          calculatedFee = slabs.first.deliveryCharge;
          matched = true;
        }
      }

      return DeliveryChargeCalculationResult(
        distanceKm: distKm,
        deliveryFee: calculatedFee,
        maxRadiusKm: maxRadiusKm,
        taxPercentage: taxPercentage,
        isMaxRadiusConfigured: isMaxRadiusConfigured,
        isOutsideRadius: false,
        hasSlabs: slabs.isNotEmpty,
      );
    } catch (e) {
      debugPrint('[DeliveryChargeService] Error calculating charge: $e');
      return DeliveryChargeCalculationResult.empty();
    }
  }


  static double _numToDouble(dynamic val, {double fallback = 0.0}) {
    if (val is num) return val.toDouble();
    if (val != null) {
      final parsed = double.tryParse(val.toString());
      if (parsed != null) return parsed;
    }
    return fallback;
  }
}

final deliveryChargeServiceProvider = Provider<DeliveryChargeService>((ref) {
  return DeliveryChargeService();
});

/// Riverpod FutureProvider to compute delivery charge calculation result for current cart & selected delivery address
final deliveryChargeCalculationProvider = FutureProvider<DeliveryChargeCalculationResult>((ref) async {
  final cartState = ref.watch(cartProvider);
  if (cartState.items.isEmpty) {
    return DeliveryChargeCalculationResult.empty();
  }

  final firstItem = cartState.items.first;
  final String branchId = firstItem.branchId.isNotEmpty
      ? firstItem.branchId
      : (firstItem.foodItem.branchId ?? firstItem.restaurantId);
  final String restId = firstItem.restaurantId;

  final addressState = ref.watch(addressProvider);
  final selectedAddress = addressState.selectedAddress;

  if (selectedAddress == null || selectedAddress.latitude == 0.0 || selectedAddress.longitude == 0.0) {
    return const DeliveryChargeCalculationResult(
      distanceKm: 0.0,
      deliveryFee: 0.0,
      maxRadiusKm: 20.0,
      isMaxRadiusConfigured: false,
      isOutsideRadius: false,
      hasSlabs: false,
      errorMessage: 'Please select a valid delivery address with location.',
    );
  }

  final service = ref.watch(deliveryChargeServiceProvider);
  return await service.calculateDeliveryCharge(
    branchId: branchId,
    restaurantId: restId,
    userLat: selectedAddress.latitude,
    userLng: selectedAddress.longitude,
  );
});
