import 'cart_item.dart';
import 'food_item.dart';
import 'address.dart';

class Order {
  final String id;
  final String orderNumber;
  final String restaurantId;
  final String branchId;
  final String branchName;
  final String restaurantName;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final Address? deliveryAddress;
  final List<CartItem> items;
  final double subtotal;
  final double tax;
  final double taxPercentage;
  final double deliveryFee;
  final double deliveryDistanceKm;
  final double discount;
  final double totalAmount;
  final String paymentMethod; // "CASH_ON_DELIVERY" or "UPI"
  final String paymentStatus; // "PENDING" or "PAID"
  final String status; // "PENDING", "ACCEPTED", "PREPARING", "READY", "OUT_FOR_DELIVERY", "DELIVERED", "REJECTED", "CANCELLED"
  final int? estimatedPrepMinutes;
  final String? rejectionReason;
  final String? cancelledBy;
  final String? cancellationReason;
  final String? cancellationNote;
  final DateTime? cancelledAt;
  final DateTime orderDate;

  const Order({
    required this.id,
    this.orderNumber = '',
    required this.restaurantId,
    this.branchId = '',
    this.branchName = '',
    required this.restaurantName,
    this.customerId = '',
    this.customerName = '',
    this.customerPhone = '',
    this.customerAddress = '',
    this.deliveryAddress,
    required this.items,
    this.subtotal = 0.0,
    this.tax = 0.0,
    this.taxPercentage = 0.0,
    this.deliveryFee = 0.0,
    this.deliveryDistanceKm = 0.0,
    this.discount = 0.0,
    required this.totalAmount,


    required this.paymentMethod,
    this.paymentStatus = 'PENDING',
    required this.status,
    this.estimatedPrepMinutes,
    this.rejectionReason,
    this.cancelledBy,
    this.cancellationReason,
    this.cancellationNote,
    this.cancelledAt,
    required this.orderDate,
  });

  /// Map raw status code to active timeline step index
  /// 0: Placed / Pending
  /// 1: Accepted / Preparing
  /// 2: Ready / Out for Delivery
  /// 3: Delivered
  int get activeStep {
    final upper = status.toUpperCase();
    if (upper == 'PENDING') return 0;
    if (upper == 'ACCEPTED') return 1;
    if (upper == 'PREPARING') return 2;
    if (upper == 'READY') return 3;
    if (upper == 'OUT_FOR_DELIVERY') return 4;
    if (upper == 'DELIVERED' || upper == 'COMPLETED') return 5;
    return 0; // Default for REJECTED/CANCELLED
  }

  bool get isOngoing =>
      (status.toUpperCase() == 'PENDING' ||
       status.toUpperCase() == 'ACCEPTED' ||
       status.toUpperCase() == 'PREPARING' ||
       status.toUpperCase() == 'READY' ||
       status.toUpperCase() == 'OUT_FOR_DELIVERY' ||
       status.toUpperCase() == 'ONGOING') &&
      !isCancelled &&
      !isCompleted;

  bool get isCompleted =>
      status.toUpperCase() == 'DELIVERED' || status.toUpperCase() == 'COMPLETED';

  bool get isCancelled =>
      status.toUpperCase() == 'CANCELLED' ||
      status.toUpperCase() == 'REJECTED';

  bool get isCancellable => isOngoing && !isCompleted && !isCancelled;

  bool get isProcessing =>
      status.toUpperCase() == 'PREPARING' ||
      status.toUpperCase() == 'READY' ||
      status.toUpperCase() == 'OUT_FOR_DELIVERY';

  factory Order.fromFirestore(Map<String, dynamic> data, String docId) {
    final rawItems = data['items'] as List? ?? [];
    final List<CartItem> parsedItems = rawItems.map((itemMap) {
      if (itemMap is Map<String, dynamic>) {
        final food = FoodItem(
          id: (itemMap['productId'] ?? itemMap['id'] ?? '').toString(),
          name: (itemMap['productName'] ?? itemMap['name'] ?? 'Item').toString(),
          description: '',
          imageUrl: (itemMap['image'] ?? '').toString(),
          price: _numToDouble(itemMap['price']),
          rating: 4.5,
          reviewCount: 10,
          isVeg: true,
          ingredients: const [],
          nutrition: const {},
          reviews: const [],
          category: 'General',
        );
        final qty = (itemMap['quantity'] is num) ? (itemMap['quantity'] as num).toInt() : 1;
        final baseP = _numToDouble(itemMap['basePrice'] ?? itemMap['price']);
        final unitP = _numToDouble(itemMap['unitPrice'] ?? itemMap['price']);
        final rawCustoms = itemMap['customizations'] as List? ?? itemMap['selectedCustomizations'] as List? ?? [];
        final List<String> parsedCustoms = rawCustoms.map((e) => e.toString()).toList();

        final rawSelections = itemMap['customizationSelections'] as List? ?? [];
        final List<ComboCustomizationSelection> parsedSelections = [];
        for (final s in rawSelections) {
          if (s is Map) {
            parsedSelections.add(ComboCustomizationSelection.fromMap(Map<String, dynamic>.from(s)));
          }
        }

        String? parsedSize;
        if (itemMap['selectedVariant'] != null) {
          if (itemMap['selectedVariant'] is Map) {
            parsedSize = itemMap['selectedVariant']['name']?.toString();
          } else if (itemMap['selectedVariant'] is String) {
            parsedSize = itemMap['selectedVariant'].toString();
          }
        }
        parsedSize ??= itemMap['size']?.toString();

        return CartItem(
          foodItem: food,
          quantity: qty,
          selectedSize: parsedSize,
          basePrice: baseP,
          unitPrice: unitP,
          restaurantId: (data['restaurantId'] ?? '').toString(),
          restaurantName: (data['restaurantName'] ?? data['branchName'] ?? '').toString(),
          isCombo: itemMap['isCombo'] == true || itemMap['itemType'] == 'combo',
          comboId: itemMap['comboId']?.toString(),
          comboName: itemMap['comboName']?.toString(),
          comboItemId: itemMap['comboItemId']?.toString(),
          removedItems: (itemMap['removedItems'] as List?)?.map((e) => e.toString()).toList() ?? [],
          replacements: (itemMap['replacements'] as List?)?.map((e) => e.toString()).toList() ?? [],
          selectedAddons: (itemMap['selectedAddons'] as List?)?.map((e) => e.toString()).toList() ?? [],
          selectedCustomizations: parsedCustoms,
          customizationSelections: parsedSelections,
        );
      }
      return CartItem(
        foodItem: const FoodItem(
          id: 'item',
          name: 'Food Item',
          description: '',
          imageUrl: '',
          price: 0,
          rating: 4.5,
          reviewCount: 0,
          isVeg: true,
          ingredients: [],
          nutrition: {},
          reviews: [],
          category: '',
        ),
        quantity: 1,
        unitPrice: 0.0,
        restaurantId: '',
        restaurantName: '',
      );
    }).toList().cast<CartItem>();

    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] != null) {
      if (data['createdAt'] is String) {
        parsedDate = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
      } else if (data['createdAt'] is Map && data['createdAt']['seconds'] != null) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(
            (data['createdAt']['seconds'] as int) * 1000);
      }
    }

    final String addrStr = (data['customerAddress'] ?? data['deliveryAddress'] ?? '').toString();

    return Order(
      id: docId,
      orderNumber: (data['orderNumber'] ?? docId).toString(),
      restaurantId: (data['restaurantId'] ?? '').toString(),
      branchId: (data['branchId'] ?? '').toString(),
      branchName: (data['branchName'] ?? 'Branch').toString(),
      restaurantName: (data['restaurantName'] ?? data['branchName'] ?? 'Restaurant').toString(),
      customerId: (data['customerId'] ?? data['userId'] ?? '').toString(),
      customerName: (data['customerName'] ?? 'Customer').toString(),
      customerPhone: (data['customerPhone'] ?? '').toString(),
      customerAddress: addrStr,
      deliveryAddress: Address(
        id: 'addr_order',
        label: 'Delivery Address',
        addressLine: addrStr.isNotEmpty ? addrStr : 'User Address',
        landmark: '',
        city: 'City',
        state: 'State',
        zipCode: '',
        isDefault: true,
      ),
      items: parsedItems,
      subtotal: _numToDouble(data['subtotal']),
      tax: _numToDouble(data['tax']),
      taxPercentage: _numToDouble(data['taxPercentage'] ?? data['gstPercentage']),
      deliveryFee: _numToDouble(data['deliveryFee'] ?? data['deliveryCharge']),

      deliveryDistanceKm: _numToDouble(data['deliveryDistanceKm'] ?? data['distanceKm']),
      discount: _numToDouble(data['discount']),

      totalAmount: _numToDouble(data['totalAmount'] ?? data['grandTotal']),
      paymentMethod: (data['paymentMethod'] ?? 'CASH_ON_DELIVERY').toString(),
      paymentStatus: (data['paymentStatus'] ?? 'PENDING').toString(),
      status: (data['status'] ?? 'PENDING').toString(),
      estimatedPrepMinutes: data['estimatedPrepMinutes'] != null
          ? (data['estimatedPrepMinutes'] as num).toInt()
          : null,
      rejectionReason: data['rejectionReason']?.toString(),
      cancelledBy: data['cancelledBy']?.toString(),
      cancellationReason: data['cancellationReason']?.toString(),
      cancellationNote: data['cancellationNote']?.toString(),
      cancelledAt: data['cancelledAt'] != null
          ? (data['cancelledAt'] is String
              ? DateTime.tryParse(data['cancelledAt'])
              : (data['cancelledAt'] is Map && data['cancelledAt']['seconds'] != null
                  ? DateTime.fromMillisecondsSinceEpoch((data['cancelledAt']['seconds'] as int) * 1000)
                  : null))
          : null,
      orderDate: parsedDate,
    );
  }

  static double _numToDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val != null) {
      final parsed = double.tryParse(val.toString());
      if (parsed != null) return parsed;
    }
    return 0.0;
  }

  Order copyWith({
    String? id,
    String? orderNumber,
    String? restaurantId,
    String? branchId,
    String? branchName,
    String? restaurantName,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    Address? deliveryAddress,
    List<CartItem>? items,
    double? subtotal,
    double? tax,
    double? deliveryFee,
    double? discount,
    double? totalAmount,
    String? paymentMethod,
    String? paymentStatus,
    String? status,
    int? estimatedPrepMinutes,
    String? rejectionReason,
    String? cancelledBy,
    String? cancellationReason,
    String? cancellationNote,
    DateTime? cancelledAt,
    DateTime? orderDate,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      restaurantId: restaurantId ?? this.restaurantId,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      restaurantName: restaurantName ?? this.restaurantName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      estimatedPrepMinutes: estimatedPrepMinutes ?? this.estimatedPrepMinutes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationNote: cancellationNote ?? this.cancellationNote,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      orderDate: orderDate ?? this.orderDate,
    );
  }
}
