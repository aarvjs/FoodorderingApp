import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order.dart';
import '../../../models/reward_config_model.dart';
import '../../../models/reward_transaction_model.dart';
import '../../../auth/providers/auth_provider.dart';

final rewardRepositoryProvider = Provider<RewardRepository>((ref) {
  return RewardRepository();
});

final userRewardPointsStreamProvider = StreamProvider.autoDispose<int>((ref) {
  final userModel = ref.watch(authProvider).userModel;
  final userId = userModel?.uid ?? '';
  if (userId.isEmpty) return Stream.value(0);
  final repo = ref.watch(rewardRepositoryProvider);
  return repo.getUserRewardPointsStream(userId);
});

final userRewardHistoryStreamProvider =
    StreamProvider.autoDispose<List<RewardTransactionModel>>((ref) {
  final userModel = ref.watch(authProvider).userModel;
  final userId = userModel?.uid ?? '';
  if (userId.isEmpty) return Stream.value([]);
  final repo = ref.watch(rewardRepositoryProvider);
  return repo.getUserRewardTransactionsStream(userId);
});

const List<RewardSlabModel> defaultRewardSlabs = [
  RewardSlabModel(id: 'slab-1', minAmount: 200, rewardPoints: 10, enabled: true),
  RewardSlabModel(id: 'slab-2', minAmount: 300, rewardPoints: 12, enabled: true),
  RewardSlabModel(id: 'slab-3', minAmount: 400, rewardPoints: 15, enabled: true),
  RewardSlabModel(id: 'slab-4', minAmount: 500, rewardPoints: 18, enabled: true),
  RewardSlabModel(id: 'slab-5', minAmount: 600, rewardPoints: 20, enabled: true),
  RewardSlabModel(id: 'slab-6', minAmount: 700, rewardPoints: 25, enabled: true),
  RewardSlabModel(id: 'slab-7', minAmount: 800, rewardPoints: 30, enabled: true),
  RewardSlabModel(id: 'slab-8', minAmount: 1000, rewardPoints: 40, enabled: true),
];

class RewardRepository {
  final FirebaseFirestore _firestore;

  RewardRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetch active Reward Points configuration for a given branch / restaurant with fallback
  Future<RewardConfigModel?> getRewardConfigByBranch(
      String branchId, String restaurantId) async {
    try {
      // 1. Direct Branch lookup
      if (branchId.isNotEmpty) {
        final qBranch = await _firestore
            .collection('reward_points_config')
            .where('branchId', isEqualTo: branchId)
            .get();
        if (qBranch.docs.isNotEmpty) {
          return RewardConfigModel.fromFirestore(
            qBranch.docs.first.data(),
            qBranch.docs.first.id,
          );
        }
      }

      // 2. Global "ALL" Branch lookup fallback
      final qAll = await _firestore
          .collection('reward_points_config')
          .where('branchId', isEqualTo: 'ALL')
          .get();
      if (qAll.docs.isNotEmpty) {
        return RewardConfigModel.fromFirestore(
          qAll.docs.first.data(),
          qAll.docs.first.id,
        );
      }

      // 3. System Default Fallback
      return RewardConfigModel(
        id: 'default',
        restaurantId: restaurantId.isNotEmpty ? restaurantId : 'default',
        branchId: branchId.isNotEmpty ? branchId : 'ALL',
        branchScope: 'ALL',
        pointValue: 0.25,
        slabs: defaultRewardSlabs,
        minimumOrderAmount: 200,
        rewardPoints: 10,
        status: 'ACTIVE',
      );
    } catch (e) {
      return RewardConfigModel(
        id: 'default',
        restaurantId: restaurantId.isNotEmpty ? restaurantId : 'default',
        branchId: branchId.isNotEmpty ? branchId : 'ALL',
        branchScope: 'ALL',
        pointValue: 0.25,
        slabs: defaultRewardSlabs,
        minimumOrderAmount: 200,
        rewardPoints: 10,
        status: 'ACTIVE',
      );
    }
  }

  /// Calculate eligible menu total and award points for a DELIVERED order
  Future<int> awardPointsForOrder(Order order) async {
    if (order.id.isEmpty || order.customerId.isEmpty) return 0;

    // 0. Strict status check: Reward points are credited ONLY when order is DELIVERED or COMPLETED
    final upperStatus = order.status.toUpperCase();
    if (upperStatus != 'DELIVERED' && upperStatus != 'COMPLETED') {
      return 0;
    }

    try {
      // 1. Guard against duplicate reward awarding for the same order ID
      final existingTxSnap = await _firestore
          .collection('reward_transactions')
          .where('orderId', isEqualTo: order.id)
          .where('type', isEqualTo: 'EARNED')
          .limit(1)
          .get();

      if (existingTxSnap.docs.isNotEmpty) {
        return 0;
      }

      // 2. Calculate eligible menu product total ONLY (excluding combos)
      double eligibleMenuTotal = 0.0;
      for (final item in order.items) {
        if (!item.isCombo) {
          eligibleMenuTotal += (item.unitPrice * item.quantity);
        }
      }

      if (eligibleMenuTotal <= 0) {
        return 0;
      }

      // 3. Fetch active configuration for the ordering branch
      final config = await getRewardConfigByBranch(order.branchId, order.restaurantId);
      if (config == null || !config.isActive) {
        return 0;
      }

      // 4. Calculate points earned using dynamic slabs
      final pointsToAward = config.calculateEarnedPoints(eligibleMenuTotal);
      if (pointsToAward <= 0) {
        return 0;
      }

      // 5. Fetch user current balance to record remainingBalance
      final userDocRef = _firestore.collection('users').doc(order.customerId);
      final userSnap = await userDocRef.get();
      final currentPts = userSnap.exists
          ? (userSnap.data()?['rewardPoints'] is num
              ? (userSnap.data()?['rewardPoints'] as num).toInt()
              : int.tryParse(userSnap.data()?['rewardPoints']?.toString() ?? '0') ?? 0)
          : 0;
      final newBalance = currentPts + pointsToAward;

      // 6. Save transaction record in Firestore reward_transactions collection
      final txDocRef = _firestore.collection('reward_transactions').doc();
      final monetaryVal = pointsToAward * config.pointValue;

      final transaction = RewardTransactionModel(
        id: txDocRef.id,
        userId: order.customerId,
        orderId: order.id,
        orderNumber: order.orderNumber.isNotEmpty ? order.orderNumber : order.id,
        points: pointsToAward,
        monetaryValue: monetaryVal,
        qualifyingAmount: eligibleMenuTotal,
        restaurantId: order.restaurantId,
        branchId: order.branchId,
        branchName: order.branchName.isNotEmpty ? order.branchName : order.restaurantName,
        type: 'EARNED',
        remainingBalance: newBalance,
        description: 'Earned $pointsToAward Reward Points on Order #${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}',
        createdAt: DateTime.now(),
      );

      await txDocRef.set(transaction.toMap());

      // 7. Atomically increment customer's reward points balance in users collection
      await userDocRef.set({
        'rewardPoints': FieldValue.increment(pointsToAward),
        'totalEarnedPoints': FieldValue.increment(pointsToAward),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return pointsToAward;
    } catch (e) {
      return 0;
    }
  }

  /// Perform transaction-safe reward points redemption when creating an order
  Future<String> redeemRewardPoints({
    required String userId,
    required String orderId,
    required String orderNumber,
    required int pointsToRedeem,
    required double monetaryValue,
    required String restaurantId,
    required String branchId,
    required String branchName,
  }) async {
    if (userId.isEmpty || pointsToRedeem <= 0) return '';

    final userRef = _firestore.collection('users').doc(userId);
    final txRef = _firestore.collection('reward_transactions').doc();

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw Exception('User account not found.');
      }

      final data = userSnap.data()!;
      final currentPoints = data['rewardPoints'] is num
          ? (data['rewardPoints'] as num).toInt()
          : int.tryParse(data['rewardPoints']?.toString() ?? '0') ?? 0;

      if (currentPoints < pointsToRedeem) {
        throw Exception('Insufficient reward points balance.');
      }

      final newBalance = currentPoints - pointsToRedeem;
      final now = DateTime.now();

      // 1. Deduct points from user
      transaction.set(
        userRef,
        {
          'rewardPoints': newBalance,
          'totalRedeemedPoints': FieldValue.increment(pointsToRedeem),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 2. Create REDEEMED ledger transaction
      final txData = RewardTransactionModel(
        id: txRef.id,
        userId: userId,
        orderId: orderId,
        orderNumber: orderNumber,
        points: -pointsToRedeem,
        monetaryValue: monetaryValue,
        restaurantId: restaurantId,
        branchId: branchId,
        branchName: branchName,
        type: 'REDEEMED',
        remainingBalance: newBalance,
        description: 'Redeemed $pointsToRedeem Points (₹${monetaryValue.toStringAsFixed(2)} discount) on Order #$orderNumber',
        createdAt: now,
      ).toMap();

      transaction.set(txRef, txData);
    });

    return txRef.id;
  }

  /// Scan all past delivered orders for a user and claim any unclaimed reward points
  Future<int> syncAndAwardDeliveredOrders(String userId) async {
    if (userId.isEmpty) return 0;

    int totalAwarded = 0;
    try {
      final snapCust = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .get();

      final snapUser = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();

      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> uniqueDocs = {};
      for (final doc in snapCust.docs) {
        uniqueDocs[doc.id] = doc;
      }
      for (final doc in snapUser.docs) {
        uniqueDocs[doc.id] = doc;
      }

      for (final docSnap in uniqueDocs.values) {
        final data = docSnap.data();
        final status = (data['status'] ?? '').toString().toUpperCase();

        if (status == 'DELIVERED' || status == 'COMPLETED') {
          final order = Order.fromFirestore(data, docSnap.id);
          final awarded = await awardPointsForOrder(order);
          totalAwarded += awarded;
        }
      }
    } catch (e) {
      // Ignore sync error silently
    }
    return totalAwarded;
  }

  /// Calculate total unclaimed reward points from qualifying delivered orders
  Future<int> getUnclaimedRewardPoints(String userId) async {
    if (userId.isEmpty) return 0;

    int unclaimedPoints = 0;
    try {
      final snapCust = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .get();

      final snapUser = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();

      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> uniqueDocs = {};
      for (final doc in snapCust.docs) {
        uniqueDocs[doc.id] = doc;
      }
      for (final doc in snapUser.docs) {
        uniqueDocs[doc.id] = doc;
      }

      for (final docSnap in uniqueDocs.values) {
        final data = docSnap.data();
        final status = (data['status'] ?? '').toString().toUpperCase();

        if (status == 'DELIVERED' || status == 'COMPLETED') {
          final existingTxSnap = await _firestore
              .collection('reward_transactions')
              .where('orderId', isEqualTo: docSnap.id)
              .where('type', isEqualTo: 'EARNED')
              .limit(1)
              .get();

          if (existingTxSnap.docs.isNotEmpty) {
            continue;
          }

          final order = Order.fromFirestore(data, docSnap.id);
          double eligibleMenuTotal = 0.0;
          for (final item in order.items) {
            if (!item.isCombo) {
              eligibleMenuTotal += (item.unitPrice * item.quantity);
            }
          }

          if (eligibleMenuTotal <= 0) continue;

          final config = await getRewardConfigByBranch(order.branchId, order.restaurantId);
          if (config != null && config.isActive) {
            final pts = config.calculateEarnedPoints(eligibleMenuTotal);
            if (pts > 0) {
              unclaimedPoints += pts;
            }
          }
        }
      }
    } catch (_) {}
    return unclaimedPoints;
  }

  /// Listen to user's current total reward points balance in real-time
  Stream<int> getUserRewardPointsStream(String userId) {
    if (userId.isEmpty) return Stream.value(0);

    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return 0;
      final data = doc.data()!;
      final rawPoints = data['rewardPoints'] ?? data['points'] ?? 0;
      if (rawPoints is num) return rawPoints.toInt();
      return int.tryParse(rawPoints.toString()) ?? 0;
    });
  }

  /// Listen to user's reward transaction history in real-time
  Stream<List<RewardTransactionModel>> getUserRewardTransactionsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _firestore
        .collection('reward_transactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => RewardTransactionModel.fromFirestore(doc.data(), doc.id))
          .toList();
      // Sort descending by creation date
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
