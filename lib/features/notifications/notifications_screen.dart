import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/state_providers.dart';
import '../../auth/providers/auth_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      final userId = authState.userModel?.uid ?? '';
      if (userId.isNotEmpty) {
        ref.read(notificationRepositoryProvider).markNotificationsAsRead(userId);
      }
    });
  }

  void _confirmDeleteAll(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete All Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to clear your notification history? This will only clear your notification history and will not affect your orders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = ref.read(authProvider).userModel?.uid ?? '';
              if (userId.isNotEmpty) {
                await ref.read(notificationRepositoryProvider).deleteAllNotifications(userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification history cleared'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  final List<Map<String, String>> _defaultNotifications = const [
    {
      'title': 'Order Dispatched! 🛵',
      'body': 'Your order from Burger Bistro is on the way. Our rider is driving safely to reach you fast.',
      'time': '5 mins ago',
      'type': 'delivery',
    },
    {
      'title': 'Mega Weekend Cashback Alert! 💰',
      'body': 'Pay using UPI and get flat 10% cashback inside your wallet. Claim code UPI10 now.',
      'time': '2 hours ago',
      'type': 'promo',
    },
    {
      'title': 'Kitchen Preparing Your Meal 🍳',
      'body': 'The chef is slow cooking your Shahi Biryani Special. Get plates ready!',
      'time': '1 day ago',
      'type': 'delivery',
    },
    {
      'title': 'Welcome Gift Inside! 🎁',
      'body': 'Use coupon WELCOME50 on checkout and claim 50% flat discount on your very first order.',
      'time': '3 days ago',
      'type': 'promo',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationsAsync = ref.watch(userNotificationsStreamProvider);
    final realtimeList = notificationsAsync.value ?? [];

    final bool hasRealtime = realtimeList.isNotEmpty;
    final int count = hasRealtime ? realtimeList.length : _defaultNotifications.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasRealtime)
            TextButton.icon(
              onPressed: () => _confirmDeleteAll(context),
              icon: const Icon(Iconsax.trash, size: 18, color: AppColors.error),
              label: const Text(
                'Delete All',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: count == 0
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.notification,
                      size: 64,
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                    const Gap(16),
                    Text(
                      'No Notifications Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      'Your order updates and offer notifications will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: count,
                itemBuilder: (context, index) {
                  String title = '';
                  String body = '';
                  String timeStr = '';
                  String typeStr = 'delivery';

                  if (hasRealtime) {
                    final n = realtimeList[index];
                    title = n.title;
                    body = n.body;
                    timeStr = DateFormat('dd MMM, hh:mm a').format(n.createdAt);
                    typeStr = n.type;
                  } else {
                    final n = _defaultNotifications[index];
                    title = n['title']!;
                    body = n['body']!;
                    timeStr = n['time']!;
                    typeStr = n['type']!;
                  }

                  final isPromo = typeStr == 'promo';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isPromo
                                ? Colors.orange.withValues(alpha: 0.12)
                                : AppColors.success.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPromo ? Iconsax.award : Iconsax.truck_fast,
                            size: 20,
                            color: isPromo ? Colors.orange : AppColors.success,
                          ),
                        ),
                        const Gap(16),

                        // Text details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const Gap(4),
                              Text(
                                body,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                  height: 1.3,
                                ),
                              ),
                              const Gap(8),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
