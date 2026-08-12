import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../features/address/providers/address_provider.dart';
import '../../../features/address/widgets/address_selection_bottom_sheet.dart';

class GlassAppBar extends ConsumerStatefulWidget {
  final bool isDark;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onWalletTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLocationTap;

  // Set to > 0 to show the notification badge
  final int unreadNotifications;

  const GlassAppBar({
    super.key,
    required this.isDark,
    this.onMenuTap,
    this.onNotificationTap,
    this.onWalletTap,
    this.onProfileTap,
    this.onLocationTap,
    this.unreadNotifications = 0,
  });

  @override
  ConsumerState<GlassAppBar> createState() => _GlassAppBarState();
}

class _GlassAppBarState extends ConsumerState<GlassAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _menuAnimController;

  // Track drawer open state correctly using the ScaffoldState
  bool _drawerIsOpen = false;

  @override
  void initState() {
    super.initState();
    _menuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _menuAnimController.dispose();
    super.dispose();
  }

  void _openAddressBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddressSelectionBottomSheet(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync hamburger icon with actual drawer state on every dependency change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold != null) {
        _syncDrawerState(scaffold.isDrawerOpen);
      }
    });
  }

  void _handleMenuTap() {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold == null) return;

    if (_drawerIsOpen) {
      scaffold.closeDrawer();
    } else {
      scaffold.openDrawer();
    }
  }

  void _syncDrawerState(bool isOpen) {
    if (_drawerIsOpen == isOpen) return;
    setState(() => _drawerIsOpen = isOpen);
    if (isOpen) {
      _menuAnimController.forward();
    } else {
      _menuAnimController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final authState = ref.watch(authProvider);
    final addressState = ref.watch(addressProvider);

    final userModel = authState.userModel;
    final activeAddr = addressState.selectedAddress;


    final photoUrl = userModel?.photoUrl;
    final initial = (userModel?.fullName?.isNotEmpty == true)
        ? userModel!.fullName![0].toUpperCase()
        : 'U';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0A192F), Color(0xFF112240)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : const LinearGradient(
                colors: [Color(0xFFEAF6FF), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated Hamburger ↔ X button
          GestureDetector(
            onTap: _handleMenuTap,
            child: AnimatedBuilder(
              animation: _menuAnimController,
              builder: (context, _) {
                final t = _menuAnimController.value;
                return Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _drawerIsOpen
                          ? [AppColors.primary, AppColors.secondary]
                          : (isDark
                              ? [
                                  const Color(0xFF1E293B),
                                  const Color(0xFF0F172A)
                                ]
                              : [Colors.white, AppColors.lightBlue]),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _drawerIsOpen
                            ? AppColors.primary.withOpacity(0.4)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Top line → first arm of X
                      Positioned(
                        top: _drawerIsOpen
                            ? 21
                            : (14.0 + (1 - t) * 0),
                        left: 12,
                        right: 12,
                        child: Transform.rotate(
                          angle: _drawerIsOpen ? 0.785398 : 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: _drawerIsOpen
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white
                                      : AppColors.primary),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      // Middle line fades out when open
                      AnimatedOpacity(
                        opacity: _drawerIsOpen ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          height: 2,
                          width: 16,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white70
                                : AppColors.primary.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Bottom line → second arm of X
                      Positioned(
                        bottom: _drawerIsOpen ? 21 : 14,
                        left: 12,
                        right: 12,
                        child: Transform.rotate(
                          angle: _drawerIsOpen ? -0.785398 : 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: _drawerIsOpen
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white
                                      : AppColors.primary),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Gap(12),

          // Location selector (Swiggy style: Area as Title, City/State as Subtitle)
          Expanded(
            child: GestureDetector(
              onTap: widget.onLocationTap ?? _openAddressBottomSheet,
              child: Builder(
                builder: (context) {
                  String cleanPart(String text) {
                    final s = text.trim();
                    if (s.contains(',')) return s.split(',').first.trim();
                    return s;
                  }

                  String areaTitle = 'Select Location';
                  if (activeAddr != null) {
                    if (activeAddr.subLocality.trim().isNotEmpty && activeAddr.subLocality != activeAddr.fullAddress) {
                      areaTitle = cleanPart(activeAddr.subLocality);
                    } else if (activeAddr.locality.trim().isNotEmpty && activeAddr.locality != activeAddr.fullAddress) {
                      areaTitle = cleanPart(activeAddr.locality);
                    } else if (activeAddr.area.trim().isNotEmpty && activeAddr.area != activeAddr.fullAddress) {
                      areaTitle = cleanPart(activeAddr.area);
                    } else if (activeAddr.label.isNotEmpty && activeAddr.label != 'Current Location' && activeAddr.label != 'Saved Address') {
                      areaTitle = cleanPart(activeAddr.label);
                    } else if (activeAddr.fullAddress.isNotEmpty) {
                      areaTitle = cleanPart(activeAddr.fullAddress);
                    }
                  } else if (userModel?.area?.trim().isNotEmpty == true) {
                    areaTitle = cleanPart(userModel!.area!);
                  }

                  final citySubTitle = (activeAddr?.city.trim().isNotEmpty == true)
                      ? (activeAddr!.state.trim().isNotEmpty ? '${cleanPart(activeAddr.city)}, ${cleanPart(activeAddr.state)}' : cleanPart(activeAddr.city))
                      : (userModel?.city?.trim().isNotEmpty == true
                          ? (userModel!.state?.trim().isNotEmpty == true ? '${cleanPart(userModel.city!)}, ${cleanPart(userModel.state!)}' : cleanPart(userModel.city!))
                          : 'Tap to choose location');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Iconsax.location5,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                          const Gap(6),
                          Flexible(
                            child: Text(
                              areaTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.textDark,
                              ),
                            ),
                          ),
                          const Gap(2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.grey.shade400
                                : AppColors.primary,
                          ),
                        ],
                      ),
                      Text(
                        citySubTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade500
                              : AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Notification bell
          GestureDetector(
            onTap: widget.onNotificationTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Icon(
                    Iconsax.notification,
                    size: 20,
                    color: isDark ? Colors.white70 : AppColors.textDark,
                  ),
                ),
                if (widget.unreadNotifications > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.3, 1.3),
                          duration: 800.ms,
                          curve: Curves.easeInOut,
                        )
                        .then()
                        .scale(
                          begin: const Offset(1.3, 1.3),
                          end: const Offset(1, 1),
                          duration: 800.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
              ],
            ),
          ),

          const Gap(8),

          // Gold Membership Badge
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () {
                widget.onWalletTap?.call();
                ctx.push('/premium');
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.award5, color: Colors.white, size: 13),
                    const Gap(4),
                    Text(
                      'GOLD',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Gap(10),

          // Profile Avatar
          GestureDetector(
            onTap: widget.onProfileTap,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
              ),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF2A1010) : Colors.white,
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildInitialAvatar(initial),
                        )
                      : _buildInitialAvatar(initial),
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.3, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }

  Widget _buildInitialAvatar(String initial) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
