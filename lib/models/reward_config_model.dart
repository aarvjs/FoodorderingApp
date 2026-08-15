class RewardConfigModel {
  final String id;
  final String restaurantId;
  final String branchId;
  final double minimumOrderAmount;
  final int rewardPoints;
  final String status;

  const RewardConfigModel({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    required this.minimumOrderAmount,
    required this.rewardPoints,
    required this.status,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory RewardConfigModel.fromFirestore(Map<String, dynamic> data, String id) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val != null) {
        final p = double.tryParse(val.toString());
        if (p != null) return p;
      }
      return 0.0;
    }

    int parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val != null) {
        final p = int.tryParse(val.toString());
        if (p != null) return p;
      }
      return 0;
    }

    return RewardConfigModel(
      id: id,
      restaurantId: (data['restaurantId'] ?? '').toString(),
      branchId: (data['branchId'] ?? '').toString(),
      minimumOrderAmount: parseDouble(data['minimumOrderAmount']),
      rewardPoints: parseInt(data['rewardPoints']),
      status: (data['status'] ?? 'INACTIVE').toString(),
    );
  }
}
