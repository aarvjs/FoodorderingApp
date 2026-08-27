import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String channelId = 'order_status_notifications_v3';
  static const String channelName = 'Order Updates';

  bool _initialized = false;
  bool _spLoaded = false;
  GlobalKey<NavigatorState>? navigatorKey;
  final Set<String> _processedNotifIds = {};

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

  Future<void> initialize({GlobalKey<NavigatorState>? key}) async {
    if (_initialized) return;
    _initialized = true;
    if (key != null) navigatorKey = key;
    await _loadProcessedNotifIds();

    try {
      // Register background messaging handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 1. Android Notification Channel (v3) with custom sound 'appsound'
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Order status and delivery update notifications',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('appsound'),
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Clean up legacy channel IDs if present to enforce sound settings
        try {
          await androidPlugin.deleteNotificationChannel(channelId: 'order_status_notifications');
          await androidPlugin.deleteNotificationChannel(channelId: 'order_status_notifications_v2');
        } catch (_) {}
        await androidPlugin.createNotificationChannel(channel);
      }

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

    bool isInitialSnapshot = true;

    FirebaseFirestore.instance
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

          _processedNotifIds.add(docId);
          if (orderId.isNotEmpty && status.isNotEmpty) {
            _processedNotifIds.add('${orderId}_$status');
            _processedNotifIds.add('notif_${orderId}_$status');
          }
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
          final status = (data['status'] ?? '').toString();

          final String primaryKey = docId;
          final String secondaryKey = (orderId.isNotEmpty && status.isNotEmpty)
              ? '${orderId}_$status'
              : docId;

          if (_processedNotifIds.contains(primaryKey) || _processedNotifIds.contains(secondaryKey)) {
            continue;
          }

          final bool isFresh = _isFreshNotification(data);
          if (!isFresh) {
            _processedNotifIds.add(primaryKey);
            _processedNotifIds.add(secondaryKey);
            await _saveProcessedNotifIds();
            continue;
          }

          final String title = (data['title'] ?? 'Order Status Updated').toString();
          final String body = (data['body'] ?? 'Your order status has been updated.').toString();

          _processForegroundNotification(
            notifKey: primaryKey,
            secondaryKey: secondaryKey,
            title: title,
            body: body,
            orderId: orderId,
          );
        }
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

    final title = notification?.title ?? data['title'] ?? 'Order Status Update';
    final body = notification?.body ?? data['body'] ?? 'Your order status has been updated.';
    final orderId = (data['orderId'] ?? '').toString();
    final status = (data['status'] ?? '').toString();

    final String primaryKey = data['id'] ?? message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final String secondaryKey = (orderId.isNotEmpty && status.isNotEmpty)
        ? '${orderId}_$status'
        : (data['id'] ?? primaryKey);

    if (_processedNotifIds.contains(primaryKey) || _processedNotifIds.contains(secondaryKey)) {
      return;
    }

    _processForegroundNotification(
      notifKey: primaryKey,
      secondaryKey: secondaryKey,
      title: title,
      body: body,
      orderId: orderId,
    );
  }

  void _processForegroundNotification({
    required String notifKey,
    required String secondaryKey,
    required String title,
    required String body,
    required String orderId,
  }) {
    // 1. Mark as processed for deduplication
    _processedNotifIds.add(notifKey);
    _processedNotifIds.add(secondaryKey);
    if (notifKey.startsWith('notif_')) {
      // Strip 'notif_' prefix if key format is notif_orderId_status
      final stripped = notifKey.replaceFirst('notif_', '');
      _processedNotifIds.add(stripped);
    }
    _saveProcessedNotifIds();
    if (_processedNotifIds.length > 200) {
      _processedNotifIds.remove(_processedNotifIds.first);
    }

    // 2. Trigger Local Notification UI Banner
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

    final int notificationId = notifKey.hashCode.abs() % 100000;
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
}
