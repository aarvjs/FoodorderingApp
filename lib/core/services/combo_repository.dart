import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/combo_model.dart';

class ComboRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream active combos for a specific restaurant / branch from Firestore `combos` collection
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
      debugPrint('[ComboRepository] Firestore combos collection raw docs count: ${snapshot.docs.length}');

      final list = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return ComboModel.fromFirestore(data, doc.id);
          })
          .where((combo) {
            if (!combo.isAvailable) {
              debugPrint('[ComboRepository] Combo ID=${combo.id} (${combo.name}) skipped: isAvailable is false');
              return false;
            }

            final String cRestId = combo.restaurantId.trim();
            final String? cBranchId = combo.branchId?.trim();
            final List<String> cBranchIds = combo.branchIds.map((b) => b.trim()).toList();

            // Candidate target IDs
            final Set<String> targetIds = {
              if (targetRestId.isNotEmpty) targetRestId,
              if (targetBranchId.isNotEmpty) targetBranchId,
            };

            // 1. Specific match: any target ID matches combo's restaurantId, branchId, or branchIds list
            final bool matchesTarget = targetIds.isNotEmpty && targetIds.any((id) =>
                (cRestId.isNotEmpty && cRestId == id) ||
                (cBranchId != null && cBranchId.isNotEmpty && cBranchId == id) ||
                cBranchIds.contains(id));

            // 2. Global / Unassigned combo (explicitly marked 'all' or has NO specific restaurant/branch assignment)
            final bool hasExplicitAll = cRestId == 'all' ||
                cBranchId == 'all' ||
                cBranchIds.contains('all');

            final bool hasNoAssignment = cRestId.isEmpty &&
                (cBranchId == null || cBranchId.isEmpty) &&
                (cBranchIds.isEmpty || (cBranchIds.length == 1 && cBranchIds.first.isEmpty));

            final bool isGlobal = hasExplicitAll || hasNoAssignment;

            final bool shouldInclude = matchesTarget || isGlobal;
            if (shouldInclude) {
              debugPrint('[ComboRepository] Matched combo ID=${combo.id} (${combo.name}) - Price: ₹${combo.price}');
            } else {
              debugPrint('[ComboRepository] Skipped combo ID=${combo.id} (${combo.name}): cRestId="$cRestId", cBranchId="$cBranchId", cBranchIds=$cBranchIds vs targetRestId="$targetRestId", targetBranchId="$targetBranchId"');
            }

            return shouldInclude;
          })
          .toList();

      debugPrint('[ComboRepository] Total matched active combos returned to UI: ${list.length}');
      return list;
    });
  }
}
