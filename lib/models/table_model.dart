class TableModel {
  final String id;
  final String restaurantId;
  final String branchId;
  final String tableNumber;
  final int capacity;
  final String section;
  final String type; // Indoor, Outdoor, Rooftop, VIP Room
  final String environment; // AC, Non AC, Open Air
  final String status; // AVAILABLE, BOOKED, OCCUPIED, RESERVED, MAINTENANCE
  final String? qrCodeUrl;

  const TableModel({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    required this.tableNumber,
    required this.capacity,
    this.section = 'Main Area',
    this.type = 'Indoor',
    this.environment = 'AC',
    this.status = 'AVAILABLE',
    this.qrCodeUrl,
  });

  factory TableModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return TableModel(
      id: docId,
      restaurantId: (data['restaurantId'] ?? '').toString(),
      branchId: (data['branchId'] ?? '').toString(),
      tableNumber: (data['tableNumber'] ?? data['number'] ?? 'T-1').toString(),
      capacity: (data['capacity'] is num) ? (data['capacity'] as num).toInt() : 4,
      section: (data['section'] ?? 'Main Area').toString(),
      type: (data['type'] ?? 'Indoor').toString(),
      environment: (data['environment'] ?? 'AC').toString(),
      status: (data['status'] ?? 'AVAILABLE').toString().toUpperCase(),
      qrCodeUrl: data['qrCodeUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'branchId': branchId,
      'tableNumber': tableNumber,
      'capacity': capacity,
      'section': section,
      'type': type,
      'environment': environment,
      'status': status,
      if (qrCodeUrl != null) 'qrCodeUrl': qrCodeUrl,
    };
  }
}

class TableBookingModel {
  final String id;
  final String restaurantId;
  final String branchId;
  final String restaurantName;
  final String branchName;
  final String tableId;
  final String tableNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String date;
  final String time;
  final int guests;
  final String? specialRequest;
  final double charges;
  final double gst;
  final double grandTotal;
  final String status; // CONFIRMED, PENDING, CANCELLED, COMPLETED
  final DateTime createdAt;

  const TableBookingModel({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    this.restaurantName = '',
    this.branchName = '',
    required this.tableId,
    required this.tableNumber,
    this.customerId = '',
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.date,
    required this.time,
    required this.guests,
    this.specialRequest,
    this.charges = 0.0,
    this.gst = 0.0,
    this.grandTotal = 0.0,
    this.status = 'CONFIRMED',
    required this.createdAt,
  });

  factory TableBookingModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final double ch = (data['charges'] is num) ? (data['charges'] as num).toDouble() : (data['bookingFee'] is num ? (data['bookingFee'] as num).toDouble() : 0.0);
    final double g = (data['gst'] is num) ? (data['gst'] as num).toDouble() : (data['tax'] is num ? (data['tax'] as num).toDouble() : 0.0);
    final double total = (data['grandTotal'] is num) ? (data['grandTotal'] as num).toDouble() : (data['totalAmount'] is num ? (data['totalAmount'] as num).toDouble() : (ch + g));

    return TableBookingModel(
      id: docId,
      restaurantId: (data['restaurantId'] ?? '').toString(),
      branchId: (data['branchId'] ?? '').toString(),
      restaurantName: (data['restaurantName'] ?? '').toString(),
      branchName: (data['branchName'] ?? '').toString(),
      tableId: (data['tableId'] ?? '').toString(),
      tableNumber: (data['tableNumber'] ?? 'T-1').toString(),
      customerId: (data['customerId'] ?? data['userId'] ?? '').toString(),
      customerName: (data['customerName'] ?? 'Customer').toString(),
      customerPhone: (data['customerPhone'] ?? '').toString(),
      customerEmail: data['customerEmail']?.toString(),
      date: (data['date'] ?? data['bookingDate'] ?? '').toString(),
      time: (data['time'] ?? data['bookingTime'] ?? '').toString(),
      guests: (data['guests'] is num) ? (data['guests'] as num).toInt() : (data['guestCount'] is num ? (data['guestCount'] as num).toInt() : 2),
      specialRequest: data['specialRequest']?.toString() ?? data['notes']?.toString(),
      charges: ch,
      gst: g,
      grandTotal: total,
      status: (data['status'] ?? 'CONFIRMED').toString().toUpperCase(),
      createdAt: data['createdAt'] != null ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': id,
      'restaurantId': restaurantId,
      'branchId': branchId,
      'restaurantName': restaurantName,
      'branchName': branchName,
      'tableId': tableId,
      'tableNumber': tableNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      if (customerEmail != null) 'customerEmail': customerEmail,
      'date': date,
      'bookingDate': date,
      'time': time,
      'bookingTime': time,
      'guests': guests,
      'guestCount': guests,
      if (specialRequest != null && specialRequest!.isNotEmpty) 'specialRequest': specialRequest,
      'charges': charges,
      'gst': gst,
      'grandTotal': grandTotal,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
