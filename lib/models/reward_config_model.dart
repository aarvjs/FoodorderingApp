class RewardSlabModel {
  final String id;
  final double minAmount;
  final int rewardPoints;
  final bool enabled;

  const RewardSlabModel({
    required this.id,
    required this.minAmount,
    required this.rewardPoints,
    this.enabled = true,
  });

  factory RewardSlabModel.fromMap(Map<String, dynamic> data) {
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

    return RewardSlabModel(
      id: (data['id'] ?? '').toString(),
      minAmount: parseDouble(data['minAmount'] ?? data['minimumOrderAmount']),
      rewardPoints: parseInt(data['rewardPoints'] ?? data['points']),
      enabled: data['enabled'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'minAmount': minAmount,
        'rewardPoints': rewardPoints,
        'enabled': enabled,
      };
}

class RewardConfigModel {
  final String id;
  final String restaurantId;
  final String branchId;
  final String branchScope;
  final double pointValue;
  final List<RewardSlabModel> slabs;
  final double minimumOrderAmount;
  final int rewardPoints;
  final String status;

  const RewardConfigModel({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    this.branchScope = 'BRANCH',
    this.pointValue = 0.25,
    required this.slabs,
    required this.minimumOrderAmount,
    required this.rewardPoints,
    required this.status,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  /// Determine the earned reward points based on qualifying order amount
  int calculateEarnedPoints(double qualifyingAmount) {
    if (!isActive || qualifyingAmount <= 0) return 0;

    // 1. Check dynamic slabs if available
    final activeSlabs = slabs.where((s) => s.enabled && qualifyingAmount >= s.minAmount).toList();
    if (activeSlabs.isNotEmpty) {
      activeSlabs.sort((a, b) => b.minAmount.compareTo(a.minAmount));
      return activeSlabs.first.rewardPoints;
    }

    // 2. Fallback to legacy single-threshold config if slabs array is empty
    if (minimumOrderAmount > 0 && qualifyingAmount >= minimumOrderAmount) {
      return rewardPoints;
    }

    return 0;
  }

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

    final rawSlabs = data['slabs'] as List? ?? [];
    final parsedSlabs = rawSlabs
        .whereType<Map<String, dynamic>>()
        .map((s) => RewardSlabModel.fromMap(s))
        .toList();

    return RewardConfigModel(
      id: id,
      restaurantId: (data['restaurantId'] ?? '').toString(),
      branchId: (data['branchId'] ?? '').toString(),
      branchScope: (data['branchScope'] ?? 'BRANCH').toString(),
      pointValue: parseDouble(data['pointValue'] ?? 0.25),
      slabs: parsedSlabs,
      minimumOrderAmount: parseDouble(data['minimumOrderAmount']),
      rewardPoints: parseInt(data['rewardPoints']),
      status: (data['status'] ?? 'INACTIVE').toString(),
    );
  }
}

