import 'package:cloud_firestore/cloud_firestore.dart';

class RewardTransactionModel {
  final String id;
  final String userId;
  final String orderId;
  final String orderNumber;
  final int points;
  final double monetaryValue;
  final double qualifyingAmount;
  final String restaurantId;
  final String branchId;
  final String branchName;
  final String type; // "EARNED", "REDEEMED", "REFUNDED", "EXPIRED", "ADJUSTMENT"
  final int remainingBalance;
  final String description;
  final DateTime createdAt;

  const RewardTransactionModel({
    required this.id,
    required this.userId,
    this.orderId = '',
    this.orderNumber = '',
    required this.points,
    this.monetaryValue = 0.0,
    this.qualifyingAmount = 0.0,
    this.restaurantId = '',
    this.branchId = '',
    this.branchName = '',
    this.type = 'EARNED',
    this.remainingBalance = 0,
    this.description = '',
    required this.createdAt,
  });

  bool get isEarned => type.toUpperCase() == 'EARNED';
  bool get isRedeemed => type.toUpperCase() == 'REDEEMED';
  bool get isRefunded => type.toUpperCase() == 'REFUNDED';

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

    final rawType = (data['type'] ?? data['transactionType'] ?? 'EARNED').toString().toUpperCase();

    return RewardTransactionModel(
      id: id,
      userId: (data['userId'] ?? data['customerId'] ?? '').toString(),
      orderId: (data['orderId'] ?? '').toString(),
      orderNumber: (data['orderNumber'] ?? '').toString(),
      points: parseInt(data['points']),
      monetaryValue: parseDouble(data['monetaryValue'] ?? data['discountAmount']),
      qualifyingAmount: parseDouble(data['qualifyingAmount'] ?? data['eligibleMenuTotal']),
      restaurantId: (data['restaurantId'] ?? '').toString(),
      branchId: (data['branchId'] ?? '').toString(),
      branchName: (data['branchName'] ?? 'Branch').toString(),
      type: rawType,
      remainingBalance: parseInt(data['remainingBalance']),
      description: (data['description'] ?? '').toString(),
      createdAt: parseDate(data['createdAt'] ?? data['timestamp']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'transactionId': id,
        'userId': userId,
        'customerId': userId,
        'orderId': orderId,
        'orderNumber': orderNumber,
        'points': points,
        'monetaryValue': monetaryValue,
        'qualifyingAmount': qualifyingAmount,
        'restaurantId': restaurantId,
        'branchId': branchId,
        'branchName': branchName,
        'type': type,
        'transactionType': type,
        'remainingBalance': remainingBalance,
        'description': description,
        'createdAt': Timestamp.fromDate(createdAt),
        'timestamp': Timestamp.fromDate(createdAt),
      };
}

