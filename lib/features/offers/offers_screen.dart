import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  final List<Map<String, String>> _coupons = const [
    {
      'code': 'WELCOME50',
      'discount': '50% OFF',
      'desc': 'Use code WELCOME50 to get 50% discount on your first order. Up to ₹100.',
    },
    {
      'code': 'BINGE20',
      'discount': '20% OFF',
      'desc': 'Get 20% flat discount on orders above ₹300. Max saving ₹80.',
    },
    {
      'code': 'FREEDEL',
      'discount': 'FREE DELIVERY',
      'desc': 'Save on shipping! Get free delivery on orders above ₹199.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Offers & Coupons')),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Festival Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isDark ? AppColors.darkGradient : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monsoon Food Fest ⛈️',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Gap(6),
                    Text(
                      'Get up to 60% discounts across all top dessert and pizza outlets nearby!',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),

              const Gap(24),

              Text(
                'Available Coupon Codes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              const Gap(12),

              // Coupon Cards
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _coupons.length,
                itemBuilder: (context, index) {
                  final coupon = _coupons[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkDivider : Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkPrimary.withOpacity(0.1) : AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                coupon['discount']!,
                                style: TextStyle(
                                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: coupon['code']!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Code "${coupon['code']}" copied to clipboard.')),
                                );
                              },
                              child: Row(
                                children: [
                                  Text(
                                    coupon['code']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Gap(6),
                                  const Icon(Icons.copy, size: 14, color: AppColors.textLight),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Gap(10),
                        Text(
                          coupon['desc']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Gap(12),

              // Referral Bonus Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
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
                          const Text(
                            'Refer & Earn Free Meals!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Gap(2),
                          Text(
                            'Invite your friends to order. Get ₹100 cash benefits inside your wallet.',
                            style: TextStyle(
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
