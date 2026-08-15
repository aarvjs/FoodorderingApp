import 'package:cloud_firestore/cloud_firestore.dart';

class RewardTransactionModel {
  final String id;
  final String userId;
  final String orderId;
  final String orderNumber;
  final int points;
  final double qualifyingAmount;
  final String restaurantId;
  final String branchId;
  final String branchName;
  final DateTime createdAt;

  const RewardTransactionModel({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.orderNumber,
    required this.points,
    this.qualifyingAmount = 0.0,
    required this.restaurantId,
    required this.branchId,
    required this.branchName,
    required this.createdAt,
  });

  factory RewardTransactionModel.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is Map && val['seconds'] != null) {
        return DateTime.fromMillisecondsSinceEpoch((val['seconds'] as int) * 1000);
      }
      return DateTime.now();
    }

    int parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val != null) {
        final p = int.tryParse(val.toString());
        if (p != null) return p;
      }
      return 0;
    }

    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val != null) {
        final p = double.tryParse(val.toString());
        if (p != null) return p;
      }
      return 0.0;
    }

    return RewardTransactionModel(
      id: id,
      userId: (data['userId'] ?? data['customerId'] ?? '').toString(),
      orderId: (data['orderId'] ?? '').toString(),
      orderNumber: (data['orderNumber'] ?? '').toString(),
      points: parseInt(data['points']),
      qualifyingAmount: parseDouble(data['qualifyingAmount'] ?? data['eligibleMenuTotal']),
      restaurantId: (data['restaurantId'] ?? '').toString(),
      branchId: (data['branchId'] ?? '').toString(),
      branchName: (data['branchName'] ?? 'Branch').toString(),
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'orderId': orderId,
        'orderNumber': orderNumber,
        'points': points,
        'qualifyingAmount': qualifyingAmount,
        'restaurantId': restaurantId,
        'branchId': branchId,
        'branchName': branchName,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
