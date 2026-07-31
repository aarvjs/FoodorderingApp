import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String id;
  final String userId;
  final String orderId;
  final String title;
  final String body;
  final String type; // 'delivery' | 'promo' | 'system'
  final bool read;
  final DateTime createdAt;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
  });

  factory AppNotificationModel.fromFirestore(Map<String, dynamic> data, String docId) {
    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] != null) {
      if (data['createdAt'] is String) {
        parsedDate = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
      } else if (data['createdAt'] is Map && data['createdAt']['seconds'] != null) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(
            (data['createdAt']['seconds'] as int) * 1000);
      }
    }

    return AppNotificationModel(
      id: docId,
      userId: (data['userId'] ?? '').toString(),
      orderId: (data['orderId'] ?? '').toString(),
      title: (data['title'] ?? 'Notification').toString(),
      body: (data['body'] ?? '').toString(),
      type: (data['type'] ?? 'delivery').toString(),
      read: data['read'] == true,
      createdAt: parsedDate,
    );
  }
}

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'notifications';

  /// Stream real-time notifications for a customer
  Stream<List<AppNotificationModel>> streamCustomerNotifications(String userId) {
    if (userId.isEmpty) {
      return _firestore
          .collection(_collectionName)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => AppNotificationModel.fromFirestore(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    }

    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AppNotificationModel.fromFirestore(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Create notification document in Firestore
  Future<void> createNotification({
    required String userId,
    required String orderId,
    required String title,
    required String body,
    String type = 'delivery',
  }) async {
    final docRef = _firestore.collection(_collectionName).doc();
    await docRef.set({
      'id': docRef.id,
      'userId': userId,
      'orderId': orderId,
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
