import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/combo_model.dart';
import '../../models/combo_item_model.dart';

class ComboRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream combo categories/banners for a specific restaurant / branch from Firestore `combos` collection
  Stream<List<ComboModel>> streamRestaurantCombos(String restaurantId, {String? branchId}) {
    final String targetRestId = restaurantId.trim();
    final String targetBranchId = (branchId ?? '').trim();

    debugPrint('[ComboRepository] Streaming combos for targetRestId="$targetRestId", targetBranchId="$targetBranchId"');

    return _firestore
        .collection('combos')
        .snapshots()
        .handleError((err) {
          debugPrint('[ComboRepository] Firestore snapshot error on combos collection: $err');
        })
        .asyncExpand((snapshot) async* {
          yield snapshot;
          yield* Stream.periodic(const Duration(seconds: 5), (_) => snapshot);
        })
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return ComboModel.fromFirestore(data, doc.id);
          })
          .where((combo) {
            if (!combo.isActive) return false;

            final String cRestId = combo.restaurantId.trim();
            final String? cBranchId = combo.branchId?.trim();
            final List<String> cBranchIds = combo.branchIds.map((b) => b.trim()).toList();

            // 1. Restaurant matching check (if targetRestId is specified)
            final bool matchesRestaurant = targetRestId.isEmpty ||
                cRestId.isEmpty ||
                cRestId.toLowerCase() == 'all' ||
                cRestId == targetRestId ||
                (targetBranchId.isNotEmpty && cRestId == targetBranchId);

            if (!matchesRestaurant) return false;

            // 2. Strict Branch matching check when a target branch ID is specified (e.g. nearest branch)
            if (targetBranchId.isNotEmpty) {
              final bool matchesSpecificBranch =
                  (cBranchId != null && cBranchId.isNotEmpty && (cBranchId == targetBranchId || cBranchId.toLowerCase() == 'all')) ||
                  cBranchIds.contains(targetBranchId) ||
                  cBranchIds.any((b) => b.toLowerCase() == 'all');

              final bool hasNoBranchAssignment =
                  (cBranchId == null || cBranchId.isEmpty) &&
                  (cBranchIds.isEmpty || (cBranchIds.length == 1 && cBranchIds.first.isEmpty));

              // If combo has explicit branch assignment(s) and NONE of them match targetBranchId, exclude it!
              if (!matchesSpecificBranch && !hasNoBranchAssignment) {
                return false;
              }
            }

            return true;
          })
          .toList();

      debugPrint('[ComboRepository] Total matched combos returned for branch "$targetBranchId": ${list.length}');
      return list;
    });
  }


  /// Stream dedicated combo items belonging specifically to a comboId from Firestore `comboItems` collection
  Stream<List<ComboItemModel>> streamComboItems(String comboId, {String? branchId}) {
    final String targetComboId = comboId.trim();

    return _firestore
        .collection('comboItems')
        .snapshots()
        .handleError((err) {
          debugPrint('[ComboRepository] Firestore snapshot error on comboItems collection: $err');
        })
        .asyncExpand((snapshot) async* {
          yield snapshot;
          yield* Stream.periodic(const Duration(seconds: 5), (_) => snapshot);
        })
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return ComboItemModel.fromFirestore(data, doc.id);
          })
          .where((item) => item.comboId == targetComboId && item.isCurrentlyAvailableForBranch(branchId))
          .toList();

      debugPrint('[ComboRepository] Total matched items for comboId="$targetComboId": ${list.length}');
      return list;
    });
  }

  /// Stream dynamic real-time data for a single combo category/banner by docId
  Stream<ComboModel?> streamSingleCombo(String comboId) {
    final String targetId = comboId.trim();
    if (targetId.isEmpty) return Stream.value(null);

    return _firestore
        .collection('combos')
        .doc(targetId)
        .snapshots()
        .handleError((err) {
          debugPrint('[ComboRepository] Firestore snapshot error on single combo="$targetId": $err');
        })
        .map((docSnap) {
          if (!docSnap.exists || docSnap.data() == null) return null;
          return ComboModel.fromFirestore(docSnap.data()!, docSnap.id);
        });
  }

  /// Stream dynamic real-time data for a single combo item by docId
  Stream<ComboItemModel?> streamSingleComboItem(String itemId) {
    final String targetId = itemId.trim();
    if (targetId.isEmpty) return Stream.value(null);

    return _firestore
        .collection('comboItems')
        .doc(targetId)
        .snapshots()
        .handleError((err) {
          debugPrint('[ComboRepository] Firestore snapshot error on single comboItem="$targetId": $err');
        })
        .map((docSnap) {
          if (!docSnap.exists || docSnap.data() == null) return null;
          return ComboItemModel.fromFirestore(docSnap.data()!, docSnap.id);
        });
  }
}
