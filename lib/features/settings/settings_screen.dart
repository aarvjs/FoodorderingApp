import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/state_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Preference options block
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Dark Mode Switch
                  ListTile(
                    leading: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    ),
                    title: const Text(
                      'Dark Mode Theme',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text('Switch between Light and Dark mode', style: TextStyle(fontSize: 11)),
                    trailing: Switch(
                      value: themeMode == ThemeMode.dark,
                      activeColor: AppColors.darkPrimary,
                      onChanged: (val) {
                        themeNotifier.toggleTheme();
                      },
                    ),
                  ),
                  
                  _buildDivider(isDark),
                  
                  // Language selection
                  ListTile(
                    leading: Icon(Icons.language_rounded, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                    title: const Text('Language Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Currently English (US)', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      _showLanguageDialog(context, isDark);
                    },
                  ),

                  _buildDivider(isDark),

                  // Push Notifications tile
                  ListTile(
                    leading: Icon(Iconsax.notification, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                    title: const Text('Order Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Manage status & alert permissions in App Settings', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      openAppSettings();
                    },
                  ),
                ],
              ),
            ),

            const Gap(24),

            // Legal details block
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildLegalTile('About Perfect Pizza', 'Read specifications & build details', isDark, context),
                  _buildDivider(isDark),
                  _buildLegalTile('Terms of Service', 'Terms and conditions guidelines', isDark, context),
                  _buildDivider(isDark),
                  _buildLegalTile('Privacy Policy', 'Review private user data safeguards', isDark, context),
                ],
              ),
            ),

            const Gap(40),
            Center(
              child: Text(
                'Build version 1.0.0 (release)',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalTile(String title, String subtitle, bool isDark, BuildContext context) {
    return ListTile(
      leading: Icon(Iconsax.info_circle, color: isDark ? AppColors.darkPrimary : AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        _showLegalInfo(context, title, isDark);
      },
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, indent: 50, color: isDark ? AppColors.darkDivider : Colors.grey.shade100);
  }

  void _showLanguageDialog(BuildContext context, bool isDark) {
    final languages = ['English (US)', 'Español (Spanish)', 'Français (French)', 'हिन्दी (Hindi)'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: const Text('Select Language', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) {
            return ListTile(
              title: Text(lang, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              trailing: lang == 'English (US)'
                  ? Icon(Icons.check_circle_rounded, color: isDark ? AppColors.darkPrimary : AppColors.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLegalInfo(BuildContext context, String title, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam elementum, dolor ac mollis luctus, dolor est pellentesque massa, in porta ligula urna quis metus. Suspendisse pulvinar erat nec lacus scelerisque.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
