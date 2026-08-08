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

            // Candidate target IDs
            final Set<String> targetIds = {
              if (targetRestId.isNotEmpty) targetRestId,
              if (targetBranchId.isNotEmpty) targetBranchId,
            };

            // 1. Specific match: matches combo's restaurantId, branchId, or branchIds list
            final bool matchesTarget = targetIds.isNotEmpty && targetIds.any((id) =>
                (cRestId.isNotEmpty && cRestId == id) ||
                (cBranchId != null && cBranchId.isNotEmpty && cBranchId == id) ||
                cBranchIds.contains(id));

            // 2. Global / Unassigned combo
            final bool hasExplicitAll = cRestId == 'all' ||
                cBranchId == 'all' ||
                cBranchIds.contains('all');

            final bool hasNoAssignment = cRestId.isEmpty &&
                (cBranchId == null || cBranchId.isEmpty) &&
                (cBranchIds.isEmpty || (cBranchIds.length == 1 && cBranchIds.first.isEmpty));

            final bool isGlobal = hasExplicitAll || hasNoAssignment;

            return matchesTarget || isGlobal;
          })
          .toList();

      debugPrint('[ComboRepository] Total matched combos returned to UI: ${list.length}');
      return list;
    });
  }

  /// Stream dedicated combo items belonging specifically to a comboId from Firestore `comboItems` collection
  Stream<List<ComboItemModel>> streamComboItems(String comboId) {
    final String targetComboId = comboId.trim();

    return _firestore
        .collection('comboItems')
        .snapshots()
        .handleError((err) {
          debugPrint('[ComboRepository] Firestore snapshot error on comboItems collection: $err');
        })
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return ComboItemModel.fromFirestore(data, doc.id);
          })
          .where((item) => item.comboId == targetComboId)
          .toList();

      debugPrint('[ComboRepository] Total matched items for comboId="$targetComboId": ${list.length}');
      return list;
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
