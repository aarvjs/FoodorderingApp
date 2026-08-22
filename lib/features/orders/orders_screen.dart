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

    final List<Order> allOrders = realOrdersAsync.value ?? memoryOrders;

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
                color: Colors.black.withValues(alpha: 0.02),
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
                              ? Colors.amber.withValues(alpha: 0.15) 
                              : (order.isCompleted ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15)),
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
                    color: Colors.blue.withValues(alpha: 0.1),
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
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Reason: ${order.rejectionReason}',
                    style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
              ],

              if (order.isCancelled) ...[
                const Gap(8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ORDER CANCELLED',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.red),
                          ),
                          if (order.cancelledBy != null && order.cancelledBy!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'BY: ${order.cancelledBy!.replaceAll('_', ' ').toUpperCase()}',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                      if (order.cancellationReason != null && order.cancellationReason!.isNotEmpty) ...[
                        const Gap(4),
                        Text(
                          'Reason: ${order.cancellationReason}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (order.cancellationNote != null && order.cancellationNote!.isNotEmpty) ...[
                        const Gap(2),
                        Text(
                          'Note: ${order.cancellationNote}',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (order.cancelledAt != null) ...[
                        const Gap(2),
                        Text(
                          'Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(order.cancelledAt!)}',
                          style: const TextStyle(fontSize: 9, color: AppColors.textLight),
                        ),
                      ],
                    ],
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.paymentMethod == 'ONLINE' || order.paymentGateway == 'PAYU'
                            ? 'Payment Method: Online • Gateway: PayU'
                            : 'Payment Method: Cash on Delivery • Gateway: COD',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight),
                      ),
                      const Gap(2),
                      Row(
                        children: [
                          Text(
                            'Status: ${order.paymentStatus}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: order.paymentStatus == 'SUCCESS' || order.paymentStatus == 'COD_COMPLETED'
                                  ? Colors.green
                                  : (order.paymentStatus == 'FAILED' ? Colors.red : AppColors.textLight),
                            ),
                          ),
                          if (order.transactionId != null && order.transactionId!.isNotEmpty) ...[
                            const Text(' • ', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                            Text(
                              'Txn: ${order.transactionId}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (order.isCancellable) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(85, 34),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => _CancelOrderDialog(order: order),
                            );
                          },
                          child: const Text('Cancel Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const Gap(8),
                      ],
                      CustomButton(
                        text: isOngoing ? 'Helpline' : 'Reorder',
                        width: 90,
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

class _CancelOrderDialog extends ConsumerStatefulWidget {
  final Order order;
  const _CancelOrderDialog({required this.order});

  @override
  ConsumerState<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends ConsumerState<_CancelOrderDialog> {
  final List<String> _reasons = const [
    'Ordered by mistake',
    'Changed my mind',
    'Taking too long',
    'Found another option',
    'Incorrect order',
    'Other',
  ];

  late String _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedReason = _reasons.first;
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmCancel() async {
    final finalReason = (_selectedReason == 'Other' && _customReasonController.text.trim().isNotEmpty)
        ? _customReasonController.text.trim()
        : _selectedReason;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(orderRepositoryProvider);
      final res = await repo.cancelOrder(
        orderId: widget.order.id,
        cancelledBy: 'customer',
        cancellationReason: finalReason,
        cancellationNote: _noteController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (res['success'] == true) {
        ref.read(ordersProvider.notifier).updateOrder(
          widget.order.copyWith(
            status: 'CANCELLED',
            cancelledBy: 'customer',
            cancellationReason: finalReason,
            cancellationNote: _noteController.text.trim(),
            cancelledAt: DateTime.now(),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to cancel order.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel_outlined, color: Colors.red, size: 22),
                const Gap(8),
                const Expanded(
                  child: Text(
                    'Cancel Order',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const Gap(8),

            if (widget.order.isProcessing) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        'This order is already being processed. Cancellation/refund may be subject to the restaurant\'s cancellation policy.',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
            ],

            const Text(
              'Why are you cancelling this order?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Gap(8),

            ..._reasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return InkWell(
                onTap: () => setState(() => _selectedReason = reason),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 20,
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      const Gap(10),
                      Text(
                        reason,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            if (_selectedReason == 'Other') ...[
              const Gap(6),
              TextField(
                controller: _customReasonController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Specify Reason *',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const Gap(12),
            TextField(
              controller: _noteController,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Additional Note (Optional)',
                hintText: 'Tell us more (optional)',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const Gap(20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Keep Order', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting ? null : _handleConfirmCancel,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Cancel Order', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
