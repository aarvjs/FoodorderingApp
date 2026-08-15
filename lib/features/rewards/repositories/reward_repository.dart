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

class RewardRepository {
  final FirebaseFirestore _firestore;

  RewardRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetch active Reward Points configuration for a given branch / restaurant with fallback
  Future<RewardConfigModel?> getRewardConfigByBranch(
      String branchId, String restaurantId) async {
    try {
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

      if (restaurantId.isNotEmpty) {
        final qRest = await _firestore
            .collection('reward_points_config')
            .where('restaurantId', isEqualTo: restaurantId)
            .get();
        if (qRest.docs.isNotEmpty) {
          return RewardConfigModel.fromFirestore(
            qRest.docs.first.data(),
            qRest.docs.first.id,
          );
        }
      }

      // Fallback: Check if any active reward points config exists
      final qAll = await _firestore
          .collection('reward_points_config')
          .limit(10)
          .get();
      if (qAll.docs.isNotEmpty) {
        for (final docSnap in qAll.docs) {
          final config = RewardConfigModel.fromFirestore(
            docSnap.data(),
            docSnap.id,
          );
          if (config.isActive) {
            return config;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Calculate eligible menu total and award points for a DELIVERED order
  Future<int> awardPointsForOrder(Order order) async {
    if (order.id.isEmpty || order.customerId.isEmpty) return 0;

    // 0. Strict status check: Reward points are credited ONLY when order is DELIVERED
    final upperStatus = order.status.toUpperCase();
    if (upperStatus != 'DELIVERED' && upperStatus != 'COMPLETED') {
      return 0;
    }

    try {
      // 1. Guard against duplicate reward awarding for the same order ID
      final existingTxSnap = await _firestore
          .collection('reward_transactions')
          .where('orderId', isEqualTo: order.id)
          .limit(1)
          .get();

      if (existingTxSnap.docs.isNotEmpty) {
        return 0;
      }

      // 2. Calculate eligible menu product total ONLY (excluding combos, tax, delivery, coupons)
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

      if (config == null || !config.isActive || config.rewardPoints <= 0) {
        return 0;
      }

      // 4. Check if eligible menu total satisfies minimum order amount threshold
      if (eligibleMenuTotal < config.minimumOrderAmount) {
        return 0;
      }

      final pointsToAward = config.rewardPoints;

      // 5. Save transaction record in Firestore reward_transactions collection
      final txDocRef = _firestore.collection('reward_transactions').doc();
      final transaction = RewardTransactionModel(
        id: txDocRef.id,
        userId: order.customerId,
        orderId: order.id,
        orderNumber: order.orderNumber.isNotEmpty ? order.orderNumber : order.id,
        points: pointsToAward,
        qualifyingAmount: eligibleMenuTotal,
        restaurantId: order.restaurantId,
        branchId: order.branchId,
        branchName: order.branchName.isNotEmpty ? order.branchName : order.restaurantName,
        createdAt: DateTime.now(),
      );

      await txDocRef.set(transaction.toMap());

      // 6. Atomically increment customer's reward points balance in users collection
      final userDocRef = _firestore.collection('users').doc(order.customerId);
      await userDocRef.set({
        'rewardPoints': FieldValue.increment(pointsToAward),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return pointsToAward;
    } catch (e) {
      return 0;
    }
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
          if (config != null && config.isActive && config.rewardPoints > 0) {
            if (eligibleMenuTotal >= config.minimumOrderAmount) {
              unclaimedPoints += config.rewardPoints;
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

  /// Listen to user's earned reward transaction history in real-time
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
