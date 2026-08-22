import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/services/state_providers.dart';
import '../../home/providers/restaurant_providers.dart';

class CouponSelectionBottomSheet extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const CouponSelectionBottomSheet({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  static Future<void> show(
    BuildContext context, {
    required String restaurantId,
    required String restaurantName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CouponSelectionBottomSheet(
        restaurantId: restaurantId,
        restaurantName: restaurantName,
      ),
    );
  }

  @override
  ConsumerState<CouponSelectionBottomSheet> createState() => _CouponSelectionBottomSheetState();
}

class _CouponSelectionBottomSheetState extends ConsumerState<CouponSelectionBottomSheet> {
  final TextEditingController _customCodeController = TextEditingController();
  bool _isApplyingCustomCode = false;

  @override
  void dispose() {
    _customCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleApplyCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isApplyingCustomCode = true);
    final result = await ref.read(cartProvider.notifier).applyCoupon(trimmed);
    if (!mounted) return;
    setState(() => _isApplyingCustomCode = false);

    if (result.isSuccess) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const Gap(8),
              Expanded(child: Text(result.message, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const Gap(8),
              Expanded(child: Text(result.message, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final activeBranchId = (cartState.items.isNotEmpty && cartState.items.first.branchId.isNotEmpty)
        ? cartState.items.first.branchId
        : widget.restaurantId;
    final offersAsync = ref.watch(restaurantOffersStreamProvider(activeBranchId));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Iconsax.ticket_discount, color: AppColors.primary, size: 20),
                    ),
                    const Gap(10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Coupon',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        Text(
                          widget.restaurantName.isNotEmpty
                              ? 'Coupons for ${widget.restaurantName}'
                              : 'Restaurant-specific coupons',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Manual code entry row inside bottom sheet
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.ticket, size: 18, color: AppColors.accent),
                  const Gap(10),
                  Expanded(
                    child: TextField(
                      controller: _customCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Enter coupon code (e.g. FLAT20)',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: _handleApplyCode,
                    ),
                  ),
                  const Gap(8),
                  TextButton(
                    onPressed: _isApplyingCustomCode
                        ? null
                        : () => _handleApplyCode(_customCodeController.text),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    child: _isApplyingCustomCode
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Text('APPLY'),
                  ),
                ],
              ),
            ),
          ),

          // Offers List Area
          Expanded(
            child: offersAsync.when(
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const Gap(16),
                      Text(
                        'Fetching available coupons...',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                      const Gap(10),
                      Text(
                        'Unable to load coupons',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        'Please check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
                      ),
                      const Gap(14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          ref.invalidate(restaurantOffersStreamProvider(widget.restaurantId));
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                        label: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              data: (offers) {
                if (offers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Iconsax.ticket_discount,
                              size: 42,
                              color: AppColors.textLight,
                            ),
                          ),
                          const Gap(16),
                          Text(
                            'No coupons available',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                          const Gap(6),
                          Text(
                            'There are currently no active coupons for this restaurant.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: offers.length,
                  separatorBuilder: (context, index) => const Gap(12),
                  itemBuilder: (context, index) {
                    final offer = offers[index];
                    final isApplied = cartState.appliedCoupon != null &&
                        (cartState.appliedCoupon!.toUpperCase() == offer.couponCode.toUpperCase() ||
                            cartState.appliedCoupon!.toUpperCase() == offer.title.toUpperCase());

                    final bool meetsMinOrder = offer.minimumOrder <= 0 || cartState.subtotal >= offer.minimumOrder;
                    final double shortage = offer.minimumOrder > cartState.subtotal
                        ? (offer.minimumOrder - cartState.subtotal)
                        : 0.0;

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isApplied
                              ? AppColors.success
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                          width: isApplied ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isApplied
                                ? AppColors.success.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Coupon code badge & Discount Pill
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Coupon Code Box
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Iconsax.ticket, size: 14, color: AppColors.primary),
                                    const Gap(6),
                                    Text(
                                      offer.couponCode,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Formatted Discount Tag
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade700,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  offer.formattedDiscount,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Gap(10),

                          // Offer Title & Description
                          Text(
                            offer.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                          if (offer.description.isNotEmpty) ...[
                            const Gap(3),
                            Text(
                              offer.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade300 : AppColors.textLight,
                              ),
                            ),
                          ],
                          const Gap(10),

                          // Meta Tags: Minimum Order, Expiry, Remaining Uses & Schedule
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (offer.minimumOrder > 0) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Iconsax.shopping_bag, size: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    const Gap(4),
                                    Text(
                                      'Min order ₹${offer.minimumOrder.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (offer.usageLimit > 0) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Iconsax.people, size: 13, color: offer.remainingUses <= 5 ? Colors.orange.shade700 : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                    const Gap(4),
                                    Text(
                                      '${offer.remainingUses} / ${offer.usageLimit} left',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: offer.remainingUses <= 5 ? Colors.orange.shade700 : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (offer.maximumDiscountAmount > 0) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Iconsax.card, size: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    const Gap(4),
                                    Text(
                                      'Max ₹${offer.maximumDiscountAmount.toStringAsFixed(0)} OFF',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (offer.validityType == 'SCHEDULED_TIME' && offer.startTime != null && offer.endTime != null && offer.startTime!.isNotEmpty) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Iconsax.clock, size: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    const Gap(4),
                                    Text(
                                      '${offer.startTime} - ${offer.endTime}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (offer.endDate != null && offer.endDate!.isNotEmpty) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Iconsax.calendar, size: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    const Gap(4),
                                    Text(
                                      'Till ${offer.endDate}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),

                          // If minimum order is not met, show unlock indicator
                          if (!meetsMinOrder) ...[
                            const Gap(8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 13, color: Colors.orange.shade800),
                                  const Gap(4),
                                  Text(
                                    'Add ₹${shortage.toStringAsFixed(0)} more items to unlock this coupon',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const Gap(10),
                          const Divider(height: 1),
                          const Gap(8),

                          // Bottom Row: Copy Code & Apply / Applied Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Copy Code Button
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: offer.couponCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Coupon "${offer.couponCode}" copied to clipboard!'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.copy_rounded, size: 13, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
                                      const Gap(4),
                                      Text(
                                        'Copy Code',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Apply / Applied / Remove Action
                              if (isApplied) ...[
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                                          Gap(4),
                                          Text(
                                            'Applied',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Gap(8),
                                    TextButton(
                                      onPressed: () {
                                        cartNotifier.removeCoupon();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Coupon removed.'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                ElevatedButton(
                                  onPressed: () => _handleApplyCode(offer.couponCode),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                                    foregroundColor: isDark ? AppColors.textDark : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'APPLY',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
