import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/services/state_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../models/order.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final userUid = authState.userModel?.uid ?? '';

    final realOrdersAsync = ref.watch(userOrdersStreamProvider);
    final memoryOrders = ref.watch(ordersProvider);

    // Strictly filter transactions belonging ONLY to the logged-in customer
    final List<Order> allOrders = (realOrdersAsync.value ?? memoryOrders)
        .where((o) => userUid.isNotEmpty ? o.customerId == userUid : true)
        .toList();

    // Sort transactions by date (newest first)
    allOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: realOrdersAsync.isLoading && allOrders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : (allOrders.isEmpty
                ? const EmptyState(
                    title: 'No Transactions Found',
                    description: 'You haven\'t made any payment transactions yet.',
                    fallbackIcon: Iconsax.card,
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: allOrders.length,
                    itemBuilder: (context, index) {
                      final order = allOrders[index];
                      return _buildTransactionCard(context, order, isDark);
                    },
                  )),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, Order order, bool isDark) {
    final orderNum = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;
    final String razorpayId = (order.transactionId != null && order.transactionId!.isNotEmpty)
        ? order.transactionId!
        : 'N/A';

    final String payGateway = (order.paymentGateway.toUpperCase() == 'PAYU' || order.paymentGateway.toUpperCase() == 'RAZORPAY')
        ? 'Razorpay'
        : (order.paymentGateway.toUpperCase() == 'STORE' ? 'Store Counter' : 'Cash on Delivery');

    final String payStatus = _getPaymentStatusText(order);
    final Color payStatusColor = _getPaymentStatusColor(order);

    final String refundStatusLabel = order.displayRefundStatusLabel;
    final Color refundStatusColor = _getRefundStatusColor(order);

    return GestureDetector(
      onTap: () => _showTransactionDetailsSheet(context, order),
      child: Container(
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
          border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade100,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Order Number & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        payGateway == 'Razorpay'
                            ? Iconsax.card_pos
                            : (payGateway == 'Store Counter' ? Iconsax.shop : Iconsax.wallet_3),
                        size: 18,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          'Order #$orderNum',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(order.paidAt ?? order.orderDate),
                  style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
                ),
              ],
            ),

            const Gap(10),
            const Divider(height: 1),
            const Gap(10),

            // Main Info Row: Amount & Restaurant Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.restaurantName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(2),
                      Text(
                        'Gateway: $payGateway • Razorpay ID: $razorpayId',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                    ),
                    const Text('Original Amount', style: TextStyle(fontSize: 9.5, color: AppColors.textLight)),
                  ],
                ),
              ],
            ),

            const Gap(12),

            // Status Badges Row
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Payment Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: payStatusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: payStatusColor.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        payStatus == 'Successful'
                            ? Icons.check_circle_rounded
                            : (payStatus == 'Failed' ? Icons.cancel_rounded : Icons.info_rounded),
                        size: 11,
                        color: payStatusColor,
                      ),
                      const Gap(4),
                      Text(
                        'Payment: $payStatus',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: payStatusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Order Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: order.isCancelled
                        ? Colors.red.withValues(alpha: 0.12)
                        : (order.isCompleted
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.blue.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Order: ${order.status.replaceAll('_', ' ').toUpperCase()}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: order.isCancelled
                          ? Colors.red.shade800
                          : (order.isCompleted ? Colors.green.shade800 : Colors.blue.shade800),
                    ),
                  ),
                ),

                // Refund Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: refundStatusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: refundStatusColor.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: Text(
                    'Refund: $refundStatusLabel',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: refundStatusColor,
                    ),
                  ),
                ),
              ],
            ),

            // Refund Banner message if online paid & cancelled
            if (order.isCancelled && order.isOnlinePaid && order.customerRefundNotice.isNotEmpty) ...[
              const Gap(12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: isDark ? 0.15 : 0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber.shade900),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        order.customerRefundNotice,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getPaymentStatusText(Order order) {
    final statusUpper = order.paymentStatus.toUpperCase();
    if (statusUpper == 'SUCCESS' || statusUpper == 'PAID' || statusUpper == 'COD_COMPLETED') {
      return 'Successful';
    }
    if (statusUpper == 'FAILED') return 'Failed';
    if (statusUpper == 'CANCELLED') return 'Cancelled';
    return 'Pending';
  }

  Color _getPaymentStatusColor(Order order) {
    final statusUpper = order.paymentStatus.toUpperCase();
    if (statusUpper == 'SUCCESS' || statusUpper == 'PAID' || statusUpper == 'COD_COMPLETED') {
      return Colors.green;
    }
    if (statusUpper == 'FAILED') return Colors.red;
    if (statusUpper == 'CANCELLED') return Colors.orange;
    return Colors.amber.shade900;
  }

  Color _getRefundStatusColor(Order order) {
    final status = order.displayRefundStatus;
    if (status == 'REFUNDED') return Colors.green;
    if (status == 'PROCESSING') return Colors.amber.shade900;
    if (status == 'FAILED') return Colors.red;
    return Colors.grey.shade700;
  }

  void _showTransactionDetailsSheet(BuildContext context, Order order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderNum = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;
    final String razorpayId = (order.transactionId != null && order.transactionId!.isNotEmpty)
        ? order.transactionId!
        : 'N/A';

    final String payGateway = (order.paymentGateway.toUpperCase() == 'PAYU' || order.paymentGateway.toUpperCase() == 'RAZORPAY')
        ? 'Razorpay'
        : (order.paymentGateway.toUpperCase() == 'STORE' ? 'Store Counter' : 'Cash on Delivery (COD)');

    final String payStatus = _getPaymentStatusText(order);
    final Color payStatusColor = _getPaymentStatusColor(order);
    final String refundStatusLabel = order.displayRefundStatusLabel;
    final Color refundStatusColor = _getRefundStatusColor(order);
    final double refundAmt = order.refundAmount ?? order.totalAmount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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

                // Title Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Transaction Receipt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: payStatusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        payStatus,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: payStatusColor),
                      ),
                    ),
                  ],
                ),

                const Gap(16),
                const Divider(),
                const Gap(8),

                // Original Amount Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text('Original Charged Amount', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                      const Gap(4),
                      Text(
                        '₹${order.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const Gap(16),
                const Text('Payment Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const Gap(8),

                _buildDetailRow('Order ID', '#$orderNum'),
                _buildDetailRow('Razorpay Payment ID', razorpayId),
                _buildDetailRow('Payment Gateway', payGateway),
                _buildDetailRow('Payment Method', order.paymentMethod == 'PAY_AT_STORE' ? 'Pay at Store' : order.paymentMethod),
                _buildDetailRow('Payment Status', payStatus, valueColor: payStatusColor),
                _buildDetailRow('Transaction Date', DateFormat('dd MMM yyyy, hh:mm:ss a').format(order.paidAt ?? order.orderDate)),

                const Gap(16),
                const Divider(),
                const Gap(8),

                const Text('Order Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const Gap(8),

                _buildDetailRow('Order Status', order.status.replaceAll('_', ' ').toUpperCase()),
                _buildDetailRow('Order Type', order.isTakeAway ? 'Take Away (Self Pickup)' : 'Delivery'),
                _buildDetailRow('Restaurant Branch', '${order.restaurantName} (${order.branchName.isNotEmpty ? order.branchName : "Branch"})'),
                _buildDetailRow('Total Items', '${order.items.length} Item(s)'),

                // Refund Information Section
                const Gap(16),
                const Divider(),
                const Gap(8),
                const Text('Refund Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const Gap(8),

                _buildDetailRow('Refund Status', refundStatusLabel, valueColor: refundStatusColor),
                _buildDetailRow('Eligible Refund Amount', '₹${(order.isOnlinePaid && order.isCancelled ? refundAmt : 0.0).toStringAsFixed(2)}'),
                if (order.refundDate != null)
                  _buildDetailRow('Refund Processed Date', DateFormat('dd MMM yyyy, hh:mm a').format(order.refundDate!)),
                if (order.refundId != null && order.refundId!.isNotEmpty)
                  _buildDetailRow('Refund Reference ID', order.refundId!),

                if (order.isCancelled && order.isOnlinePaid && order.customerRefundNotice.isNotEmpty) ...[
                  const Gap(12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: isDark ? 0.15 : 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade900),
                            const Gap(6),
                            Text(
                              'Refund Note',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                        const Gap(6),
                        Text(
                          order.customerRefundNotice,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade300 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Gap(24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
          ),
          const Gap(8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
