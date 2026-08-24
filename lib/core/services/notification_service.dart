import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String channelId = 'order_status_notifications_v2';
  static const String channelName = 'Order Updates';

  bool _initialized = false;
  GlobalKey<NavigatorState>? navigatorKey;
  String? _lastPlayedNotifId;

  Future<void> initialize({GlobalKey<NavigatorState>? key}) async {
    if (_initialized) return;
    _initialized = true;
    if (key != null) navigatorKey = key;

    try {
      // Register background messaging handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 1. Create Android Notification Channel (v2) with custom sound 'appsound'
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Order status and delivery update notifications',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('appsound'),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 2. Local Notifications Initialization
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

      // 3. FCM Token Refresh listener
      _fcm.onTokenRefresh.listen((newToken) async {
        await syncFcmToken();
      });

      // 4. Foreground FCM Message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      // 5. Background App Tap listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final orderId = message.data['orderId'];
        if (orderId != null && orderId.toString().isNotEmpty) {
          _handleNotificationTap(orderId.toString());
        }
      });

      // 6. Terminated Initial Message
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        final orderId = initialMessage.data['orderId'];
        if (orderId != null && orderId.toString().isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            _handleNotificationTap(orderId.toString());
          });
        }
      }

      // 7. Sync Device FCM Token
      await syncFcmToken();

      // 8. Listen to Auth State to start real-time Firestore notification listener
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          syncFcmToken();
          _listenToCustomerFirestoreNotifications(user.uid);
        }
      });
    } catch (e) {
      debugPrint('NotificationService initialize error: $e');
    }
  }

  Future<void> requestPermission(BuildContext context) async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await syncFcmToken();
      }
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

  void _listenToCustomerFirestoreNotifications(String userId) {
    if (userId.isEmpty) return;

    FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final docId = change.doc.id;
          if (_lastPlayedNotifId == docId) continue;
          _lastPlayedNotifId = docId;

          final String title = (data['title'] ?? 'Order Status Updated').toString();
          final String body = (data['body'] ?? 'Your order status has been updated.').toString();
          final String orderId = (data['orderId'] ?? '').toString();

          _showSystemNotification(docId, title, body, orderId);
        }
      }
    });
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'Order Status Update';
    final body = notification?.body ?? data['body'] ?? 'Your order status has been updated.';
    final orderId = (data['orderId'] ?? '').toString();
    final notifId = (message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString());

    _showSystemNotification(notifId, title, body, orderId);
  }

  void _showSystemNotification(String notifId, String title, String body, String orderId) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Order status updates',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('appsound'),
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    final int id = notifId.hashCode.abs() % 100000;
    _localNotifications.show(
      id: id,
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
}
