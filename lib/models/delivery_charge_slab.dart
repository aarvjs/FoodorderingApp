class DeliveryChargeSlab {
  final String id;
  final String restaurantId;
  final String branchId;
  final double minDistanceKm;
  final double maxDistanceKm;
  final double deliveryCharge;
  final double freeDeliveryThreshold;
  final bool isActive;

  const DeliveryChargeSlab({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    required this.minDistanceKm,
    required this.maxDistanceKm,
    required this.deliveryCharge,
    this.freeDeliveryThreshold = 0.0,
    this.isActive = true,
  });

  factory DeliveryChargeSlab.fromFirestore(Map<String, dynamic> data, String docId) {
    return DeliveryChargeSlab(
      id: docId,
      restaurantId: (data['restaurantId'] ?? '').toString(),
      branchId: (data['branchId'] ?? '').toString(),
      minDistanceKm: (data['minDistanceKm'] is num)
          ? (data['minDistanceKm'] as num).toDouble()
          : double.tryParse(data['minDistanceKm']?.toString() ?? '0') ?? 0.0,
      maxDistanceKm: (data['maxDistanceKm'] is num)
          ? (data['maxDistanceKm'] as num).toDouble()
          : double.tryParse(data['maxDistanceKm']?.toString() ?? '0') ?? 0.0,
      deliveryCharge: (data['deliveryCharge'] is num)
          ? (data['deliveryCharge'] as num).toDouble()
          : double.tryParse(data['deliveryCharge']?.toString() ?? '0') ?? 0.0,
      freeDeliveryThreshold: (data['freeDeliveryThreshold'] is num)
          ? (data['freeDeliveryThreshold'] as num).toDouble()
          : double.tryParse(data['freeDeliveryThreshold']?.toString() ?? '0') ?? 0.0,
      isActive: (data['status'] ?? 'ACTIVE').toString().toUpperCase() == 'ACTIVE',
    );
  }
}
