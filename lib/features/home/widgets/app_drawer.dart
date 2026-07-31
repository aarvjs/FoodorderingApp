import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../../core/config/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../address/providers/address_provider.dart';
import '../../address/widgets/address_selection_bottom_sheet.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _openManageAddresses(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddressSelectionBottomSheet(),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context); // Close drawer
              context.go('/login');
              await ref.read(authProvider.notifier).signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final addressState = ref.watch(addressProvider);

    final userModel = authState.userModel;
    final userName = userModel?.fullName?.isNotEmpty == true ? userModel!.fullName! : 'Arvind';
    final userPhone = userModel?.phone.isNotEmpty == true ? userModel!.phone : '+91 98765 43210';
    final photoUrl = userModel?.photoUrl;
    final activeAddr = addressState.selectedAddress;

    return Drawer(
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: isDark
                ? const Color(0xFF181818).withOpacity(0.92)
                : Colors.white.withOpacity(0.95),
            child: Column(
              children: [
                // Top User Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 54, bottom: 20, left: 20, right: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [AppColors.darkPrimary.withOpacity(0.2), Colors.transparent]
                          : [AppColors.primary.withOpacity(0.12), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                width: 2,
                              ),
                              image: photoUrl != null && photoUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(photoUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: photoUrl == null || photoUrl.isEmpty
                                ? Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [AppColors.primary, AppColors.secondary],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const Gap(14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : AppColors.textDark,
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  userPhone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                  ),
                                ),
                                const Gap(6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'GOLD MEMBER 🏆',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (activeAddr != null) ...[
                        const Gap(16),
                        GestureDetector(
                          onTap: () => _openManageAddresses(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : AppColors.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : AppColors.primary.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Iconsax.location5, color: AppColors.primary, size: 16),
                                const Gap(8),
                                Expanded(
                                  child: Text(
                                    '${activeAddr.label}: ${activeAddr.fullAddress}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey.shade300 : AppColors.textDark,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Drawer Menu List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildMenuItem(Iconsax.home_1, 'Home', () {
                        Navigator.pop(context);
                        context.go('/home');
                      }, isDark),
                      _buildMenuItem(Iconsax.bag_2, 'Orders', () {
                        Navigator.pop(context);
                        context.go('/orders');
                      }, isDark),
                      _buildMenuItem(Iconsax.calendar_tick, 'My Table Bookings', () {
                        Navigator.pop(context);
                        context.push('/bookings');
                      }, isDark),
                      _buildMenuItem(Iconsax.heart, 'Favorites', () {
                        Navigator.pop(context);
                        context.push('/home');
                      }, isDark),
                      _buildMenuItem(Iconsax.ticket_discount, 'Coupons & Offers', () {
                        Navigator.pop(context);
                        context.push('/offers');
                      }, isDark),
                      _buildMenuItem(Iconsax.location, 'Manage Addresses', () {
                        _openManageAddresses(context);
                      }, isDark),
                      _buildMenuItem(Iconsax.notification, 'Notifications', () {
                        Navigator.pop(context);
                        context.push('/notifications');
                      }, isDark),
                      _buildMenuItem(Iconsax.crown, 'Gold Premium', () {
                        Navigator.pop(context);
                        context.push('/premium');
                      }, isDark, isGold: true),

                      const Divider(height: 24, indent: 16, endIndent: 16),

                      _buildMenuItem(Iconsax.setting, 'Settings', () {
                        Navigator.pop(context);
                        context.push('/settings');
                      }, isDark),
                      _buildMenuItem(Iconsax.info_circle, 'Help & Support', () {
                        _showInfoDialog(
                          context,
                          'Help & Support',
                          'For support or order queries, reach out at support@flavorsdelivery.com or call 1800-456-789. Available 24/7.',
                          isDark,
                        );
                      }, isDark),
                      _buildMenuItem(Iconsax.security_safe, 'Privacy Policy', () {
                        _showInfoDialog(
                          context,
                          'Privacy Policy',
                          'Flavors App protects your data with end-to-end security. We use your location strictly to show nearby restaurants and faster delivery.',
                          isDark,
                        );
                      }, isDark),
                      _buildMenuItem(Iconsax.message_question, 'About', () {
                        _showInfoDialog(
                          context,
                          'About Flavors Food Delivery',
                          'Flavors v1.0.0 (Build 100)\nDelivering happiness fresh to your door in minutes!',
                          isDark,
                        );
                      }, isDark),
                      _buildMenuItem(Iconsax.logout, 'Logout', () {
                        _showLogoutDialog(context, ref, isDark);
                      }, isDark, isDestructive: true),
                    ],
                  ),
                ),

                // App Version Footer
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Text(
                        'Flavors Food Delivery',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        'v1.0.0 (Build 100)',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap,
    bool isDark, {
    bool isDestructive = false,
    bool isGold = false,
  }) {
    final Color iconColor = isDestructive
        ? AppColors.error
        : isGold
            ? const Color(0xFFFFD700)
            : (isDark ? AppColors.darkPrimary : AppColors.primary);
    final Color textColor = isDestructive
        ? AppColors.error
        : isGold
            ? const Color(0xFFFFAA00)
            : (isDark ? Colors.white.withOpacity(0.9) : AppColors.textDark);

    return ListTile(
      leading: isGold
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            )
          : Icon(icon, color: iconColor, size: 20),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: onTap,
    );
  }
}
