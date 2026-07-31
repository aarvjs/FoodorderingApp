import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/state_providers.dart';
import '../../models/order.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final realOrdersAsync = ref.watch(userOrdersStreamProvider);
    final memoryOrders = ref.watch(ordersProvider);

    final List<Order> allOrders = (realOrdersAsync.value != null && realOrdersAsync.value!.isNotEmpty)
        ? realOrdersAsync.value!
        : memoryOrders;

    final ongoingOrders = allOrders.where((o) => o.isOngoing).toList();
    final completedOrders = allOrders.where((o) => o.isCompleted).toList();
    final cancelledOrders = allOrders.where((o) => o.isCancelled).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            indicatorColor: isDark ? AppColors.darkPrimary : AppColors.primary,
            labelColor: isDark ? AppColors.darkPrimary : AppColors.primary,
            unselectedLabelColor: isDark ? Colors.grey.shade500 : AppColors.textLight,
            tabs: const [
              Tab(text: 'Ongoing'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // Ongoing Tab
              ongoingOrders.isEmpty
                  ? _buildEmptyState(context, 'No active orders', 'Add items to your cart and place an order to track delivery in real time.')
                  : _buildOrdersList(ongoingOrders, true, isDark),

              // Completed Tab
              completedOrders.isEmpty
                  ? _buildEmptyState(context, 'No completed orders', 'You haven\'t completed any orders yet. Try placing one!')
                  : _buildOrdersList(completedOrders, false, isDark),

              // Cancelled Tab
              cancelledOrders.isEmpty
                  ? _buildEmptyState(context, 'No cancelled orders', 'No cancelled transactions recorded.')
                  : _buildOrdersList(cancelledOrders, false, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String title, String desc) {
    return EmptyState(
      title: title,
      description: desc,
      fallbackIcon: Iconsax.bag_cross,
    );
  }

  Widget _buildOrdersList(List<Order> orders, bool isOngoing, bool isDark) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final orderNum = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.restaurantName,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const Gap(2),
                        Text(
                          '$orderNum • ${DateFormat('dd MMM, hh:mm a').format(order.orderDate)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${order.totalAmount}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOngoing 
                              ? Colors.amber.withOpacity(0.15) 
                              : (order.isCompleted ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isOngoing 
                                ? Colors.amber.shade900 
                                : (order.isCompleted ? Colors.green : Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (order.estimatedPrepMinutes != null && isOngoing) ...[
                const Gap(8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.blue),
                      const Gap(4),
                      Text(
                        'Est. Prep Time: ${order.estimatedPrepMinutes} mins',
                        style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],

              if (order.rejectionReason != null && order.rejectionReason!.isNotEmpty) ...[
                const Gap(8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Text(
                    'Reason: ${order.rejectionReason}',
                    style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
              ],

              const Divider(height: 24),

              // Timeline or item lists
              if (isOngoing) ...[
                const Text(
                  'Live Delivery Timeline',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textLight),
                ),
                const Gap(16),
                _buildTimeline(order.activeStep, isDark),
                const Gap(16),
                const Divider(),
              ],

              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payment: ${order.paymentMethod}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  CustomButton(
                    text: isOngoing ? 'Helpline' : 'Reorder',
                    width: 100,
                    height: 36,
                    isSecondary: true,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isOngoing ? 'Support team notified.' : 'Items added back to cart.')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeline(int activeStep, bool isDark) {
    final steps = [
      {'title': 'Received', 'desc': 'Placed'},
      {'title': 'Accepted', 'desc': 'Confirmed'},
      {'title': 'Preparing', 'desc': 'Kitchen'},
      {'title': 'Ready', 'desc': 'Packed'},
      {'title': 'Out', 'desc': 'On the way'},
      {'title': 'Delivered', 'desc': 'Arrived'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isCompleted = index <= activeStep;
        final isCurrent = index == activeStep;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  // Left connector line
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index == 0
                          ? Colors.transparent
                          : (index <= activeStep
                              ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                    ),
                  ),
                  // Checkmark node
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCurrent 
                          ? (isDark ? AppColors.darkPrimary : AppColors.primary) 
                          : (isCompleted ? Colors.green : Colors.transparent),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted ? Colors.transparent : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isCurrent ? Icons.circle : (isCompleted ? Icons.check : Icons.circle),
                        size: isCurrent ? 8 : 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Right connector line
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index == steps.length - 1
                          ? Colors.transparent
                          : (index < activeStep
                              ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                    ),
                  ),
                ],
              ),
              const Gap(8),
              Text(
                step['title']!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isCurrent
                      ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                      : (isCompleted ? Colors.green : AppColors.textLight),
                ),
              ),
              Text(
                step['desc']!,
                style: TextStyle(
                  fontSize: 8,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
