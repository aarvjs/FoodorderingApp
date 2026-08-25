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
                  : _buildOrdersList(ongoingOrders, true, isDark, ref),

              // Completed Tab
              completedOrders.isEmpty
                  ? _buildEmptyState(context, 'No completed orders', 'You haven\'t completed any orders yet. Try placing one!')
                  : _buildOrdersList(completedOrders, false, isDark, ref),

              // Cancelled Tab
              cancelledOrders.isEmpty
                  ? _buildEmptyState(context, 'No cancelled orders', 'No cancelled transactions recorded.')
                  : _buildOrdersList(cancelledOrders, false, isDark, ref),
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

  Widget _buildOrdersList(List<Order> orders, bool isOngoing, bool isDark, WidgetRef ref) {
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
                      const Gap(4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: order.isTakeAway
                                  ? Colors.purple.withValues(alpha: 0.15)
                                  : Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: order.isTakeAway ? Colors.purple.shade300 : Colors.blue.shade300,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              order.isTakeAway ? '🛍️ TAKE AWAY' : '🛵 DELIVERY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: order.isTakeAway ? Colors.purple.shade800 : Colors.blue.shade800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.paymentMethod == 'PAY_AT_STORE'
                              ? 'Payment: Pay at Store'
                              : (order.paymentMethod == 'ONLINE' || order.paymentGateway == 'PAYU'
                                  ? 'Payment: Online • PayU'
                                  : 'Payment: Cash on Delivery'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Gap(2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            Text(
                              'Status: ${order.paymentStatus}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: order.paymentStatus == 'SUCCESS' || order.paymentStatus == 'COD_COMPLETED' || order.paymentStatus == 'PAID'
                                    ? Colors.green
                                    : (order.paymentStatus == 'FAILED' ? Colors.red : AppColors.textLight),
                              ),
                            ),
                            if (order.transactionId != null && order.transactionId!.isNotEmpty) ...[
                              Text(
                                '• Txn: ${order.transactionId}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // View Bill Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.receipt_long, size: 14),
                        label: const Text('View Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                          side: BorderSide(color: isDark ? AppColors.darkPrimary : AppColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: const Size(80, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => _OrderBillSheet(order: order),
                          );
                        },
                      ),

                      if (order.isCancellable)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(80, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

                      if (!isOngoing)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          tooltip: 'Delete from history',
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete from History?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                content: const Text('This order will be hidden from your order history. The store record remains intact.', style: TextStyle(fontSize: 13)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await ref.read(orderRepositoryProvider).hideOrderFromUserHistory(order.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Order removed from history.')),
                                );
                              }
                            }
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

class _OrderBillSheet extends StatelessWidget {
  final Order order;
  const _OrderBillSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderNum = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Gap(16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.restaurantName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      if (order.branchName.isNotEmpty)
                        Text(
                          'Branch: ${order.branchName}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'TAX INVOICE / BILL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),

              const Gap(16),
              const Divider(),
              const Gap(8),

              // Order Type & Status Banner
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: order.isTakeAway ? Colors.purple.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: order.isTakeAway ? Colors.purple.shade200 : Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          order.isTakeAway ? '🛍️ TAKE AWAY / SELF PICKUP' : '🛵 DELIVERY ORDER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: order.isTakeAway ? Colors.purple.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Order #$orderNum',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ],
              ),

              const Gap(12),
              // Customer Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer: ${order.customerName.isNotEmpty ? order.customerName : "Customer"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const Gap(2),
                    Text('Phone: ${order.customerPhone.isNotEmpty ? order.customerPhone : "N/A"}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                    const Gap(2),
                    Text('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(order.orderDate)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                    if (order.customerAddress.isNotEmpty) ...[
                      const Gap(4),
                      Text('Address: ${order.customerAddress}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),

              const Gap(16),
              const Text('Itemized Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const Gap(8),

              // Items List
              ...order.items.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black12 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.quantity}x ${item.foodItem.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (item.selectedSize != null)
                              Text('Size: ${item.selectedSize}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                            if (item.customInstructions != null && item.customInstructions!.isNotEmpty)
                              Text('Note: ${item.customInstructions}',
                                  style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      Text(
                        '₹${item.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }),

              const Gap(16),
              const Divider(),
              const Gap(8),

              // Payment & Financial Summary
              const Text('Payment Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const Gap(8),

              _buildBillRow('Item Subtotal', '₹${order.subtotal.toStringAsFixed(2)}'),
              if (order.discount > 0)
                _buildBillRow('Coupon Discount', '- ₹${order.discount.toStringAsFixed(2)}', isDiscount: true),
              if (order.rewardDiscountAmount > 0)
                _buildBillRow('Reward Points Discount', '- ₹${order.rewardDiscountAmount.toStringAsFixed(2)}', isDiscount: true),
              _buildBillRow('Delivery Fee', order.deliveryFee == 0 ? 'FREE (₹0.00)' : '₹${order.deliveryFee.toStringAsFixed(2)}'),
              if (order.tax > 0)
                _buildBillRow('Taxes & GST (${order.taxPercentage}%)', '₹${order.tax.toStringAsFixed(2)}'),

              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    ),
                  ),
                ],
              ),

              const Gap(16),
              // Payment Mode Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Method: ${order.paymentMethod == "PAY_AT_STORE" ? "PAY AT STORE" : order.paymentMethod}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: order.paymentStatus == 'SUCCESS' || order.paymentStatus == 'PAID' || order.paymentStatus == 'COD_COMPLETED'
                            ? Colors.green.shade100
                            : Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.paymentStatus,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: order.paymentStatus == 'SUCCESS' || order.paymentStatus == 'PAID' || order.paymentStatus == 'COD_COMPLETED'
                              ? Colors.green.shade900
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Gap(20),
              CustomButton(
                text: 'Close Invoice',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBillRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDiscount ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }
}
