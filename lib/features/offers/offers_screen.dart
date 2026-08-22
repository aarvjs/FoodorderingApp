import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/app_colors.dart';
import '../home/providers/restaurant_providers.dart';
import '../../core/services/state_providers.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve target branch ID: Cart items' branch ID or Nearest restaurant's branch ID
    final cartState = ref.watch(cartProvider);
    final nearbyAsync = ref.watch(nearbyRestaurantsStreamProvider);

    String targetBranchId = '';
    String targetBranchName = '';

    if (cartState.items.isNotEmpty && cartState.items.first.branchId.isNotEmpty) {
      targetBranchId = cartState.items.first.branchId;
      targetBranchName = cartState.items.first.restaurantName;
    } else {
      final nearbyList = nearbyAsync.asData?.value ?? [];
      if (nearbyList.isNotEmpty) {
        targetBranchId = nearbyList.first.id;
        targetBranchName = nearbyList.first.name;
      }
    }

    final offersAsync = ref.watch(restaurantOffersStreamProvider(targetBranchId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Offers & Coupons',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Outlet Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91D25), Color(0xFFFF5252)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE91D25).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.location5, color: Colors.white, size: 18),
                        const Gap(6),
                        Expanded(
                          child: Text(
                            targetBranchName.isNotEmpty ? targetBranchName : 'Nearest Branch Outlet',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Gap(10),
                    Text(
                      'Exclusive Branch Offers 🏷️',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      'Get real-time promo codes and discount deals valid for your active branch.',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Gap(24),

              Text(
                'Available Branch Coupons',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              const Gap(12),

              offersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Failed to load offers. Please try again.',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                ),
                data: (offers) {
                  if (offers.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Iconsax.discount_shape, size: 48, color: Colors.grey.shade400),
                          const Gap(12),
                          Text(
                            'No Active Offers Right Now',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                          const Gap(6),
                          Text(
                            'Check back soon for exclusive deals from your nearest branch!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: offers.length,
                    itemBuilder: (context, index) {
                      final offer = offers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFE91D25), Color(0xFFFF5252)],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    offer.formattedDiscount,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: offer.couponCode));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Coupon "${offer.couponCode}" copied to clipboard!'),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkPrimary.withOpacity(0.15)
                                          : AppColors.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkPrimary.withOpacity(0.3)
                                            : AppColors.primary.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          offer.couponCode,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const Gap(6),
                                        Icon(
                                          Icons.copy,
                                          size: 14,
                                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Gap(12),
                            Text(
                              offer.title,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark ? Colors.white : AppColors.textDark,
                              ),
                            ),
                            if (offer.description.isNotEmpty) ...[
                              const Gap(4),
                              Text(
                                offer.description,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                  height: 1.3,
                                ),
                              ),
                            ],
                            const Gap(10),
                            Row(
                              children: [
                                if (offer.minimumOrderAmount > 0) ...[
                                  Icon(Iconsax.shopping_bag, size: 14, color: Colors.grey.shade500),
                                  const Gap(4),
                                  Text(
                                    'Min Order: ₹${offer.minimumOrderAmount.toStringAsFixed(0)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const Gap(12),
                                ],
                                Icon(Iconsax.clock, size: 14, color: Colors.grey.shade500),
                                const Gap(4),
                                Text(
                                  offer.validityType == 'SCHEDULED_TIME'
                                      ? '${offer.startTime ?? '00:00'} - ${offer.endTime ?? '23:59'}'
                                      : 'Valid All Day',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              const Gap(16),

              // Referral Bonus Banner Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Iconsax.gift, color: Colors.orange, size: 24),
                    ),
                    const Gap(16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Refer & Earn Benefits! 🎁',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            'Invite friends to order from nearby outlets and unlock wallet cash rewards.',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
