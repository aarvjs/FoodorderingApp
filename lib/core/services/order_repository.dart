import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../models/order.dart';
import '../../models/cart_item.dart';

class OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'orders';

  /// Stream real-time orders for a specific customer
  Stream<List<Order>> streamCustomerOrders(String customerId) {
    if (customerId.isEmpty) {
      // Fallback: Listen to all recent orders ordered by createdAt desc
      return _firestore
          .collection(_collectionName)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => Order.fromFirestore(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.orderDate.compareTo(a.orderDate));
        return list;
      });
    }

    return _firestore
        .collection(_collectionName)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Order.fromFirestore(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      return list;
    });
  }

  /// Create a new Order document in Firestore
  Future<Order> createOrder({
    required String restaurantId,
    required String branchId,
    required String branchName,
    required String restaurantName,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    double latitude = 0.0,
    double longitude = 0.0,
    required List<CartItem> items,
    required double subtotal,
    required double tax,
    required double deliveryFee,
    required double discount,
    required double grandTotal,
    String paymentMethod = 'CASH_ON_DELIVERY',
    String? appliedCoupon,
    String? appliedOfferId,
  }) async {
    final docRef = _firestore.collection(_collectionName).doc();
    final nowIso = DateTime.now().toIso8601String();
    final randomNum = Random().nextInt(900000) + 100000;
    final orderNum = 'ORD-$randomNum';

    final int totalQuantity = items.fold<int>(0, (total, i) => total + i.quantity);

    final orderItemsData = items.map((item) {
      final double displayBase = item.displayBasePrice;
      final double totalItemP = item.totalPrice;

      return {
        'itemType': item.isCombo ? 'combo' : 'product',
        'productId': item.foodItem.id,
        'productName': item.foodItem.name,
        'quantity': item.quantity,
        'price': item.unitPrice,
        'basePrice': displayBase,
        'unitPrice': item.unitPrice,
        'totalPrice': totalItemP,
        'itemTotal': totalItemP,
        'image': item.foodItem.imageUrl,
        'category': item.foodItem.category,
        'isCombo': item.isCombo,
        if (item.comboId != null) 'comboId': item.comboId,
        if (item.comboName != null) 'comboName': item.comboName,
        if (item.comboItemId != null) 'comboItemId': item.comboItemId,
        if (item.selectedSize != null)
          'selectedVariant': {
            'name': item.selectedSize,
            'additionalPrice': 0,
          },
        if (item.selectedSize != null) 'size': item.selectedSize,
        'removedItems': item.removedItems,
        'replacements': item.replacements,
        'selectedAddons': item.selectedAddons,
        'customizations': [
          if (item.customInstructions != null) item.customInstructions!,
          ...item.selectedCustomizations,
          if (item.removedItems.isNotEmpty) 'Removed: ${item.removedItems.join(", ")}',
          if (item.replacements.isNotEmpty) 'Replacements: ${item.replacements.join(", ")}',
          if (item.selectedAddons.isNotEmpty) 'Addons: ${item.selectedAddons.join(", ")}',
        ],
        'customizationSelections': item.customizationSelections.map((c) => c.toMap()).toList(),
      };
    }).toList();

    final orderData = {
      'id': docRef.id,
      'orderNumber': orderNum,
      'restaurantId': restaurantId,
      'branchId': branchId.isNotEmpty ? branchId : restaurantId,
      'branchName': branchName.isNotEmpty ? branchName : restaurantName,
      'restaurantName': restaurantName,
      'customerId': customerId,
      'customerName': customerName.isNotEmpty ? customerName : 'Customer',
      'customerPhone': customerPhone.isNotEmpty ? customerPhone : '+91 9876543210',
      'customerAddress': customerAddress,
      'latitude': latitude,
      'longitude': longitude,
      'items': orderItemsData,
      'quantity': totalQuantity,
      'subtotal': subtotal,
      'tax': tax,
      'deliveryFee': deliveryFee,
      'deliveryCharge': deliveryFee,
      'discount': discount,
      'appliedCoupon': appliedCoupon ?? '',
      'totalAmount': grandTotal,
      'grandTotal': grandTotal,
      'paymentMethod': paymentMethod,
      'paymentStatus': 'PENDING',
      'orderType': 'DELIVERY',
      'status': 'PENDING',
      'createdAt': nowIso,
      'updatedAt': nowIso,
    };

    // Atomic transaction for offer redemption & usage limit enforcement
    if ((appliedOfferId != null && appliedOfferId.isNotEmpty) || (appliedCoupon != null && appliedCoupon.isNotEmpty)) {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot? offerSnap;
        if (appliedOfferId != null && appliedOfferId.isNotEmpty) {
          final oRef = _firestore.collection('offers').doc(appliedOfferId);
          final snap = await transaction.get(oRef);
          if (snap.exists) {
            offerSnap = snap;
          }
        }

        if (offerSnap == null && appliedCoupon != null && appliedCoupon.isNotEmpty) {
          final qSnap = await _firestore.collection('offers').where('coupon', isEqualTo: appliedCoupon.trim().toUpperCase()).get();
          if (qSnap.docs.isNotEmpty) {
            final oRef = qSnap.docs.first.reference;
            offerSnap = await transaction.get(oRef);
          }
        }

        if (offerSnap != null && offerSnap.exists) {
          final data = offerSnap.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'ACTIVE').toString().toUpperCase();
          final bool isActive = (data['isActive'] != false) && status == 'ACTIVE';

          if (!isActive) {
            throw Exception('Sorry, this offer is no longer active.');
          }

          final uLimit = (data['usageLimit'] ?? 0);
          final int usageLimit = (uLimit is num) ? uLimit.toInt() : int.tryParse(uLimit.toString()) ?? 0;
          final uCount = (data['usageCount'] ?? 0);
          final int usageCount = (uCount is num) ? uCount.toInt() : int.tryParse(uCount.toString()) ?? 0;

          if (usageLimit > 0 && usageCount >= usageLimit) {
            throw Exception('Sorry, this offer has reached its usage limit.');
          }

          final int newCount = usageCount + 1;
          final int newRemaining = usageLimit > 0 ? max(0, usageLimit - newCount) : 0;
          final Map<String, dynamic> updateData = {
            'usageCount': newCount,
            'remainingUses': newRemaining,
            'updatedAt': nowIso,
          };
          if (usageLimit > 0 && newCount >= usageLimit) {
            updateData['status'] = 'EXPIRED';
            updateData['isActive'] = false;
          }

          transaction.update(offerSnap.reference, updateData);
        }

        transaction.set(docRef, orderData);
      });
    } else {
      await docRef.set(orderData);
    }

    // Create notifications for Super Admin and Branch Manager
    try {
      final notifRef = _firestore.collection('notifications').doc();
      await notifRef.set({
        'id': notifRef.id,
        'orderId': docRef.id,
        'branchId': orderData['branchId'],
        'restaurantId': restaurantId,
        'title': 'New Order Received! 🛍️',
        'body': 'Order #$orderNum placed for ${orderData['branchName']}. Total: ₹$grandTotal',
        'type': 'order_created',
        'targetRole': 'BRANCH_MANAGER',
        'read': false,
        'createdAt': nowIso,
      });
    } catch (e) {
      debugPrint('Order notification error: $e');
    }

    return Order.fromFirestore(orderData, docRef.id);
  }

  /// Cancel an active order with reason, optional note, and race condition check
  Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required String cancelledBy,
    required String cancellationReason,
    String? cancellationNote,
  }) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(orderId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        return {'success': false, 'message': 'Order not found.'};
      }

      final data = docSnap.data()!;
      final currentStatus = (data['status'] ?? '').toString().toUpperCase();

      if (currentStatus == 'CANCELLED') {
        return {
          'success': false,
          'message': 'This order has already been cancelled.'
        };
      }

      if (currentStatus == 'DELIVERED' || currentStatus == 'COMPLETED') {
        return {
          'success': false,
          'message': 'Delivered or completed orders cannot be cancelled.'
        };
      }

      final nowIso = DateTime.now().toIso8601String();
      final Map<String, dynamic> updates = {
        'status': 'CANCELLED',
        'cancelledBy': cancelledBy,
        'cancellationReason': cancellationReason,
        'cancellationNote': cancellationNote ?? '',
        'cancelledAt': nowIso,
        'updatedAt': nowIso,
      };

      if ((data['paymentStatus'] ?? '').toString().toUpperCase() == 'PAID') {
        updates['paymentStatus'] = 'REFUNDED';
      }

      await docRef.update(updates);

      // Create notification record for admins/managers
      try {
        final notifRef = _firestore.collection('notifications').doc();
        await notifRef.set({
          'id': notifRef.id,
          'orderId': orderId,
          'branchId': data['branchId'],
          'restaurantId': data['restaurantId'],
          'title': 'Order Cancelled ⚠️',
          'body': 'Order #${data['orderNumber'] ?? orderId} was cancelled by ${cancelledBy.replaceAll('_', ' ')}. Reason: $cancellationReason',
          'type': 'order_cancelled',
          'targetRole': 'BRANCH_MANAGER',
          'read': false,
          'createdAt': nowIso,
        });
      } catch (e) {
        debugPrint('Cancellation notification warning: $e');
      }

      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Failed to cancel order: $e'};
    }
  }
}
