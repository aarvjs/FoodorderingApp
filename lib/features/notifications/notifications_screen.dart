import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/state_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final notificationsAsync = ref.watch(userNotificationsStreamProvider);
    final realtimeList = notificationsAsync.value ?? [];

    final bool hasRealtime = realtimeList.isNotEmpty;
    final int count = hasRealtime ? realtimeList.length : _defaultNotifications.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: ListView.builder(
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
                    color: Colors.black.withOpacity(0.02),
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
                          ? Colors.orange.withOpacity(0.12) 
                          : AppColors.success.withOpacity(0.12),
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
