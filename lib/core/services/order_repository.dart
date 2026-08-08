import 'dart:math';
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
  }) async {
    final docRef = _firestore.collection(_collectionName).doc();
    final nowIso = DateTime.now().toIso8601String();
    final randomNum = Random().nextInt(900000) + 100000;
    final orderNum = 'ORD-$randomNum';

    final int totalQuantity = items.fold<int>(0, (sum, i) => sum + i.quantity);

    final orderItemsData = items.map((item) {
      return {
        'productId': item.foodItem.id,
        'productName': item.foodItem.name,
        'quantity': item.quantity,
        'price': item.foodItem.price,
        'basePrice': item.basePrice,
        'unitPrice': item.unitPrice,
        'totalPrice': item.totalPrice,
        'image': item.foodItem.imageUrl,
        'isCombo': item.isCombo,
        if (item.comboId != null) 'comboId': item.comboId,
        if (item.comboName != null) 'comboName': item.comboName,
        if (item.comboItemId != null) 'comboItemId': item.comboItemId,
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
        if (item.selectedSize != null) 'size': item.selectedSize,
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
      'totalAmount': grandTotal,
      'grandTotal': grandTotal,
      'paymentMethod': paymentMethod,
      'paymentStatus': 'PENDING',
      'orderType': 'DELIVERY',
      'status': 'PENDING',
      'createdAt': nowIso,
      'updatedAt': nowIso,
    };

    await docRef.set(orderData);

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
      print('Order notification error: $e');
    }

    return Order.fromFirestore(orderData, docRef.id);
  }
}
