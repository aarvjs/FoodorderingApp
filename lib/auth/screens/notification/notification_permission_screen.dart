import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../providers/auth_provider.dart';

class NotificationPermissionScreen extends ConsumerStatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  ConsumerState<NotificationPermissionScreen> createState() => _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState extends ConsumerState<NotificationPermissionScreen> {
  bool _isRequesting = false;

  Future<void> _markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_prompted_notification_permission', true);
  }

  void _advanceNext() {
    final userModel = ref.read(authProvider).userModel;
    if (userModel?.fullName == null || userModel!.fullName!.trim().isEmpty) {
      context.go('/complete-profile');
    } else {
      context.go('/home');
    }
  }

  Future<void> _handleAllowNotifications() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    try {
      await _markOnboardingCompleted();

      // Trigger official Android runtime POST_NOTIFICATIONS / FCM permission
      final status = await Permission.notification.request();

      if (status.isGranted) {
        await NotificationService().syncFcmToken();
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
        _advanceNext();
      }
    }
  }

  Future<void> _handleSkip() async {
    if (_isRequesting) return;
    await _markOnboardingCompleted();
    if (mounted) {
      _advanceNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const Spacer(),

              // Animated Bell & Order Icon Graphic
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.18),
                        AppColors.secondary.withOpacity(0.18),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Iconsax.notification_bing5,
                        size: 65,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                      Positioned(
                        right: 14,
                        top: 18,
                        child: const Text('🔔', style: TextStyle(fontSize: 22))
                            .animate(onPlay: (c) => c.repeat())
                            .shake(hz: 2, duration: 1600.ms),
                      ),
                      Positioned(
                        left: 14,
                        bottom: 18,
                        child: const Text('🍕', style: TextStyle(fontSize: 22))
                            .animate(onPlay: (c) => c.repeat())
                            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1200.ms),
                      ),
                    ],
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              ),

              const Gap(40),

              // Requested Title
              Text(
                'Stay updated on your order',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

              const Gap(14),

              // Requested Subtitle
              Text(
                'Allow notifications to receive order status updates from Perfect Pizza.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                ),
              ).animate().fadeIn(delay: 350.ms, duration: 500.ms),

              const Spacer(),

              // Primary Action Button (Allow Notifications)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isRequesting ? null : _handleAllowNotifications,
                  icon: const Icon(Iconsax.notification, color: Colors.white, size: 20),
                  label: _isRequesting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Allow Notifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 4,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const Gap(14),

              // Secondary Action Button (Maybe Later)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: _isRequesting ? null : _handleSkip,
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                    ),
                  ),
                ),
              ),

              const Gap(10),
            ],
          ),
        ),
      ),
    );
  }
}
