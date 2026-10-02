import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Handle data-only push notifications in background / terminated states
  if (message.notification == null && message.data.isNotEmpty) {
    final data = message.data;
    final title = data['title'] ?? 'Order Status Update';
    final body = data['body'] ?? 'Your order status has been updated.';
    final orderId = (data['orderId'] ?? '').toString();

    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'order_status_notifications_v4',
      'Order Updates',
      description: 'Order status and delivery update notifications',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('appsound'),
      enableVibration: true,
    );

    final androidPlugin = localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }

    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
    );

    await localNotifications.initialize(settings: initSettings);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'order_status_notifications_v4',
      'Order Updates',
      channelDescription: 'Order status updates',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('appsound'),
      icon: '@mipmap/ic_launcher',
      ticker: 'Order Update',
      visibility: NotificationVisibility.public,
      enableVibration: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    final String notifKey = data['id'] ?? message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final int notificationId = notifKey.hashCode.abs() % 100000;

    await localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: orderId,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String channelId = 'order_status_notifications_v4';
  static const String channelName = 'Order Updates';

  bool _initialized = false;
  bool _spLoaded = false;
  GlobalKey<NavigatorState>? navigatorKey;
  final Set<String> _processedNotifIds = {};
  final Map<String, String> _orderLastStatus = {};

  StreamSubscription? _notifSubscription;
  StreamSubscription? _orderSubscription;

  Future<void> _loadProcessedNotifIds() async {
    if (_spLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('processed_notification_ids') ?? [];
      _processedNotifIds.addAll(saved);
      _spLoaded = true;
    } catch (_) {}
  }

  Future<void> _saveProcessedNotifIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _processedNotifIds.toList();
      if (list.length > 500) {
        final trimmed = list.sublist(list.length - 500);
        await prefs.setStringList('processed_notification_ids', trimmed);
      } else {
        await prefs.setStringList('processed_notification_ids', list);
      }
    } catch (_) {}
  }

  bool _isEventProcessed({
    required String orderId,
    required String status,
    String? docId,
    String? customKey,
  }) {
    final cleanStatus = status.trim().toUpperCase();
    final cleanOrderId = orderId.trim();

    if (docId != null && docId.isNotEmpty && _processedNotifIds.contains(docId)) {
      return true;
    }
    if (customKey != null && customKey.isNotEmpty && _processedNotifIds.contains(customKey)) {
      return true;
    }

    if (cleanOrderId.isNotEmpty) {
      if (cleanStatus.isNotEmpty) {
        if (_processedNotifIds.contains('${cleanOrderId}_$cleanStatus') ||
            _processedNotifIds.contains('notif_${cleanOrderId}_$cleanStatus') ||
            _processedNotifIds.contains('order_status_${cleanOrderId}_$cleanStatus')) {
          return true;
        }
      }

      if (cleanStatus == 'PLACED' || cleanStatus == 'ORDER_CREATED') {
        if (_processedNotifIds.contains('${cleanOrderId}_PLACED') ||
            _processedNotifIds.contains('${cleanOrderId}_ORDER_CREATED') ||
            _processedNotifIds.contains('notif_${cleanOrderId}_PLACED') ||
            _processedNotifIds.contains('order_status_${cleanOrderId}_PLACED')) {
          return true;
        }
      }

      if (cleanStatus == 'PENDING') {
        if (_processedNotifIds.contains('${cleanOrderId}_PENDING') ||
            _processedNotifIds.contains('notif_${cleanOrderId}_PENDING') ||
            _processedNotifIds.contains('order_status_${cleanOrderId}_PENDING')) {
          return true;
        }
      }
    }

    return false;
  }

  void _markEventProcessed({
    required String orderId,
    required String status,
    String? docId,
    String? customKey,
  }) {
    final cleanStatus = status.trim().toUpperCase();
    final cleanOrderId = orderId.trim();

    if (docId != null && docId.isNotEmpty) {
      _processedNotifIds.add(docId);
    }
    if (customKey != null && customKey.isNotEmpty) {
      _processedNotifIds.add(customKey);
    }

    if (cleanOrderId.isNotEmpty) {
      if (cleanStatus.isNotEmpty) {
        _processedNotifIds.add('${cleanOrderId}_$cleanStatus');
        _processedNotifIds.add('notif_${cleanOrderId}_$cleanStatus');
        _processedNotifIds.add('order_status_${cleanOrderId}_$cleanStatus');
      }

      if (cleanStatus == 'PLACED' || cleanStatus == 'ORDER_CREATED') {
        _processedNotifIds.add('${cleanOrderId}_PLACED');
        _processedNotifIds.add('${cleanOrderId}_ORDER_CREATED');
        _processedNotifIds.add('notif_${cleanOrderId}_PLACED');
        _processedNotifIds.add('order_status_${cleanOrderId}_PLACED');
      }

      if (cleanStatus == 'PENDING') {
        _processedNotifIds.add('${cleanOrderId}_PENDING');
        _processedNotifIds.add('notif_${cleanOrderId}_PENDING');
        _processedNotifIds.add('order_status_${cleanOrderId}_PENDING');
      }
    }

    _saveProcessedNotifIds();
  }

  Future<void> initialize({GlobalKey<NavigatorState>? key}) async {
    if (_initialized) return;
    _initialized = true;
    if (key != null) navigatorKey = key;
    await _loadProcessedNotifIds();

    try {
      // 1. Register background messaging handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2. Android Notification Channel (v4) with custom sound 'appsound'
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Order status and delivery update notifications',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('appsound'),
        enableVibration: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Clean up legacy channel IDs to ensure new channel settings take effect
        try {
          await androidPlugin.deleteNotificationChannel(channelId: 'order_status_notifications');
          await androidPlugin.deleteNotificationChannel(channelId: 'order_status_notifications_v2');
          await androidPlugin.deleteNotificationChannel(channelId: 'order_status_notifications_v3');
        } catch (_) {}
        await androidPlugin.createNotificationChannel(channel);
      }

      // 3. Local Notifications Initialization
      const AndroidInitializationSettings androidInitSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInitSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            _handleNotificationTap(response.payload!);
          }
        },
      );

      // 4. FCM Token Refresh listener
      _fcm.onTokenRefresh.listen((newToken) async {
        await syncFcmToken();
      });

      // 5. Foreground FCM Message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      // 6. Background App Tap listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final orderId = message.data['orderId'];
        if (orderId != null && orderId.toString().isNotEmpty) {
          _handleNotificationTap(orderId.toString());
        }
      });

      // 7. Terminated Initial Message
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        final orderId = initialMessage.data['orderId'];
        if (orderId != null && orderId.toString().isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            _handleNotificationTap(orderId.toString());
          });
        }
      }

      // 8. Sync Device FCM Token
      await syncFcmToken();

      // 9. Listen to Auth State to start real-time Firestore listeners
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          syncFcmToken();
          _startCustomerFirestoreListeners(user.uid);
        } else {
          _stopCustomerFirestoreListeners();
        }
      });
    } catch (e) {
      debugPrint('NotificationService initialize error: $e');
    }
  }

  Future<void> requestPermission(BuildContext context) async {
    try {
      // 1. Request FCM permission
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // 2. Request Android 13+ POST_NOTIFICATIONS runtime permission
      await Permission.notification.request();

      await syncFcmToken();
    } catch (e) {
      debugPrint('Notification permission request error: $e');
    }
  }

  Future<void> syncFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenSync': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('FCM Token sync error: $e');
    }
  }

  Future<void> removeFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (_) {}
  }

  void _stopCustomerFirestoreListeners() {
    _notifSubscription?.cancel();
    _notifSubscription = null;
    _orderSubscription?.cancel();
    _orderSubscription = null;
  }

  void _startCustomerFirestoreListeners(String userId) {
    _stopCustomerFirestoreListeners();
    if (userId.isEmpty) return;

    _listenToCustomerNotificationsCollection(userId);
    _listenToCustomerOrdersCollection(userId);
  }

  void _listenToCustomerNotificationsCollection(String userId) {
    bool isInitialSnapshot = true;

    _notifSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      await _loadProcessedNotifIds();

      if (isInitialSnapshot) {
        // Seed all existing notification IDs from initial snapshot so old notifications NEVER pop up on app launch
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final docId = doc.id;
          final orderId = (data['orderId'] ?? '').toString();
          final status = (data['status'] ?? '').toString();

          _markEventProcessed(orderId: orderId, status: status, docId: docId);
        }
        isInitialSnapshot = false;
        await _saveProcessedNotifIds();
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final docId = change.doc.id;
          final orderId = (data['orderId'] ?? '').toString();
          String status = (data['status'] ?? '').toString();
          final type = (data['type'] ?? '').toString();

          if (status.isEmpty) {
            final titleStr = (data['title'] ?? '').toString().toLowerCase();
            if (type == 'delivery' || type == 'order_created' || titleStr.contains('placed')) {
              status = 'PLACED';
            }
          }

          if (_isEventProcessed(orderId: orderId, status: status, docId: docId)) {
            continue;
          }

          final bool isFresh = _isFreshNotification(data);
          if (!isFresh) {
            _markEventProcessed(orderId: orderId, status: status, docId: docId);
            continue;
          }

          final String title = (data['title'] ?? _getTitleForStatus(status)).toString();
          final String body = (data['body'] ?? _getBodyForStatus(status, orderId)).toString();

          _processForegroundNotification(
            docId: docId,
            status: status,
            title: title,
            body: body,
            orderId: orderId,
          );
        }
      }
    });
  }

  void _listenToCustomerOrdersCollection(String userId) {
    bool isInitialSnapshot = true;

    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      await _loadProcessedNotifIds();

      if (isInitialSnapshot) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final orderId = doc.id;
          final status = (data['status'] ?? '').toString().toUpperCase();
          if (status.isNotEmpty) {
            _orderLastStatus[orderId] = status;
            _markEventProcessed(orderId: orderId, status: status, docId: doc.id);
          }
        }
        isInitialSnapshot = false;
        await _saveProcessedNotifIds();
        return;
      }

      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final orderId = change.doc.id;
        final orderNum = (data['orderNumber'] ?? orderId).toString();
        final currentStatus = (data['status'] ?? '').toString().toUpperCase();
        final previousStatus = _orderLastStatus[orderId];

        _orderLastStatus[orderId] = currentStatus;

        // Skip if status is empty or hasn't changed (e.g. ACCEPTED -> ACCEPTED)
        if (currentStatus.isEmpty || currentStatus == previousStatus) {
          continue;
        }

        // Do NOT trigger a second notification for the initial PENDING status of a newly created order.
        // The initial order creation notification ("Order Placed") is already generated by checkout / notifications collection.
        if (previousStatus == null && currentStatus == 'PENDING') {
          _markEventProcessed(orderId: orderId, status: 'PENDING');
          continue;
        }

        if (_isEventProcessed(orderId: orderId, status: currentStatus)) {
          continue;
        }

        final estPrep = (data['estimatedPrepMinutes'] is num)
            ? (data['estimatedPrepMinutes'] as num).toInt()
            : int.tryParse(data['estimatedPrepMinutes']?.toString() ?? '');
        final rejReason = data['rejectionReason']?.toString();

        final String title = _getTitleForStatus(currentStatus);
        final String body = _getBodyForStatus(currentStatus, orderNum, prepTime: estPrep, reason: rejReason);

        _processForegroundNotification(
          docId: 'order_status_${orderId}_$currentStatus',
          status: currentStatus,
          title: title,
          body: body,
          orderId: orderId,
        );
      }
    });
  }

  bool _isFreshNotification(Map<String, dynamic> data) {
    if (data['createdAt'] == null) return true;
    try {
      DateTime notifTime = DateTime.now();
      final raw = data['createdAt'];
      if (raw is String) {
        notifTime = DateTime.tryParse(raw) ?? DateTime.now();
      } else if (raw is Timestamp) {
        notifTime = raw.toDate();
      } else if (raw is Map && raw['seconds'] != null) {
        notifTime = DateTime.fromMillisecondsSinceEpoch((raw['seconds'] as int) * 1000);
      }
      final ageInSeconds = DateTime.now().difference(notifTime).inSeconds;
      return ageInSeconds >= 0 && ageInSeconds < 300;
    } catch (_) {
      return true;
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    final orderId = (data['orderId'] ?? '').toString();
    final status = (data['status'] ?? '').toString();
    final messageId = message.messageId;

    if (_isEventProcessed(orderId: orderId, status: status, docId: messageId)) {
      return;
    }

    final title = notification?.title ?? data['title'] ?? _getTitleForStatus(status);
    final body = notification?.body ?? data['body'] ?? _getBodyForStatus(status, orderId);

    _processForegroundNotification(
      docId: messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      status: status,
      title: title,
      body: body,
      orderId: orderId,
    );
  }

  void _processForegroundNotification({
    required String docId,
    required String status,
    required String title,
    required String body,
    required String orderId,
  }) {
    // 1. Mark as processed for deduplication
    _markEventProcessed(orderId: orderId, status: status, docId: docId);

    // 2. Trigger Local Notification UI Banner in Android System Tray with custom sound
    // Note: AudioPlayer is NOT called here because the Android notification channel
    // has playSound: true with RawResourceAndroidNotificationSound('appsound').
    // The system notification automatically plays the sound ONCE.
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Order status updates',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('appsound'),
      icon: '@mipmap/ic_launcher',
      ticker: 'Order Update',
      visibility: NotificationVisibility.public,
      enableVibration: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    final int notificationId = '${orderId}_${status}_$docId'.hashCode.abs() % 100000;
    _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: orderId,
    );
  }

  void _handleNotificationTap(String orderId) {
    if (navigatorKey?.currentContext != null) {
      try {
        GoRouter.of(navigatorKey!.currentContext!).push('/orders');
      } catch (e) {
        debugPrint('Error navigating on notification tap: $e');
      }
    }
  }

  String _getTitleForStatus(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return 'Order Accepted! 🍳';
      case 'PREPARING':
        return 'Kitchen Preparing Your Order 👨‍🍳';
      case 'READY':
        return 'Order Ready! 📦';
      case 'OUT_FOR_DELIVERY':
        return 'Out for Delivery! 🛵';
      case 'DELIVERED':
        return 'Order Delivered! 🎉';
      case 'REJECTED':
        return 'Order Rejected ❌';
      case 'CANCELLED':
        return 'Order Cancelled ⚠️';
      default:
        return 'Order Status Updated';
    }
  }

  String _getBodyForStatus(String status, String orderId, {int? prepTime, String? reason}) {
    final displayOrder = orderId.isNotEmpty ? '#$orderId' : '';
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return 'Your order $displayOrder has been accepted. Estimated prep time: ${prepTime ?? 20} mins.';
      case 'PREPARING':
        return 'The chef is now preparing your meal for order $displayOrder.';
      case 'READY':
        return 'Your order $displayOrder is ready and waiting for pickup/dispatch.';
      case 'OUT_FOR_DELIVERY':
        return 'Your order $displayOrder is on the way. Our rider will reach you soon!';
      case 'DELIVERED':
        return 'Your order $displayOrder has been delivered. Bon appétit!';
      case 'REJECTED':
        return 'Order $displayOrder was rejected. Reason: ${reason ?? 'Kitchen busy'}';
      case 'CANCELLED':
        return 'Order $displayOrder has been cancelled.';
      default:
        return 'Your order $displayOrder status is now ${status.replaceAll('_', ' ')}.';
    }
  }
}

