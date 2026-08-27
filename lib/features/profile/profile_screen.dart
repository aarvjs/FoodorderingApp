import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../address/providers/address_provider.dart';
import '../address/widgets/address_selection_bottom_sheet.dart';
import '../address/widgets/add_edit_address_modal.dart';
import '../home/providers/restaurant_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _openEditProfileModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.read(authProvider);
    final userModel = authState.userModel;

    final nameController = TextEditingController(text: userModel?.fullName ?? 'Arvind');
    File? selectedImage;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final safeBottomPadding = MediaQuery.of(context).padding.bottom;

          return Padding(
            padding: EdgeInsets.only(
              bottom: bottomInset > 0 ? bottomInset : (safeBottomPadding + 20),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),

              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const Gap(16),
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                    const Gap(20),

                    // Avatar Picker
                    GestureDetector(
                      onTap: isSaving ? null : () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 600,
                          imageQuality: 85,
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedImage = File(picked.path);
                          });
                        }
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                              border: Border.all(color: AppColors.primary, width: 2),
                              image: selectedImage != null
                                  ? DecorationImage(
                                      image: FileImage(selectedImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : (userModel?.photoUrl != null && userModel!.photoUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(userModel.photoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null),
                            ),
                            child: selectedImage == null && (userModel?.photoUrl == null || userModel!.photoUrl!.isEmpty)
                                ? Center(
                                    child: Text(
                                      (userModel?.fullName?.isNotEmpty == true)
                                          ? userModel!.fullName![0].toUpperCase()
                                          : 'A',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Iconsax.camera, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ),

                    const Gap(24),

                    // Name Input
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Iconsax.user),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),

                    const Gap(16),

                    // Phone Number Field (Verified)
                    if (userModel?.phone.isNotEmpty == true || authState.phoneNumber.isNotEmpty) ...[
                      TextField(
                        controller: TextEditingController(
                          text: (userModel?.phone != null && userModel!.phone.trim().isNotEmpty)
                              ? userModel.phone.trim()
                              : authState.phoneNumber,
                        ),
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Phone Number (Verified)',
                          prefixIcon: const Icon(Iconsax.call),
                          suffixIcon: const Icon(Icons.verified, color: Colors.green, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ],

                    const Gap(24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          final trimmedName = nameController.text.trim();
                          if (trimmedName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid full name'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          // Check if anything actually changed
                          final isNameChanged = trimmedName != (userModel?.fullName ?? '');
                          final isImageChanged = selectedImage != null;

                          if (!isNameChanged && !isImageChanged) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            return;
                          }

                          setModalState(() {
                            isSaving = true;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          final success = await ref.read(authProvider.notifier).saveUserData(
                            fullName: trimmedName,
                            imageFile: selectedImage,
                          );

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (mounted) {
                            if (success) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } else {
                              final err = ref.read(authProvider).errorMessage;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(err ?? 'Failed to save profile changes'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  void _openManageAddressesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddressSelectionBottomSheet(),
    );
  }

  void _showLogoutDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final addressState = ref.watch(addressProvider);

    final userModel = authState.userModel;
    final userName = userModel?.fullName?.isNotEmpty == true ? userModel!.fullName! : 'Arvind';
    final userPhone = (userModel?.phone != null && userModel!.phone.trim().isNotEmpty)
        ? userModel.phone.trim()
        : (authState.phoneNumber.isNotEmpty ? authState.phoneNumber : '');
    final photoUrl = userModel?.photoUrl;

    final selectedAddr = addressState.selectedAddress;
    final addressesList = addressState.addresses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.edit_2),
            onPressed: _openEditProfileModal,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: _openEditProfileModal,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 75,
                                height: 75,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary, width: 2),
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
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                              ),
                            ],
                          ),
                        ),

                        const Gap(16),

                        // Name, Phone & Badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : AppColors.textDark,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                userPhone,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (selectedAddr != null) ...[
                      const Divider(height: 28),
                      GestureDetector(
                        onTap: _openManageAddressesSheet,
                        child: Row(
                          children: [
                            const Icon(Iconsax.location5, color: AppColors.primary, size: 18),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                '${selectedAddr.label}: ${selectedAddr.fullAddress}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade300 : AppColors.textDark,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),

              const Gap(20),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openEditProfileModal,
                      icon: const Icon(Iconsax.user_edit, size: 16),
                      label: const Text('Edit Profile'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openManageAddressesSheet,
                      icon: const Icon(Iconsax.location, color: Colors.white, size: 16),
                      label: const Text('Manage Address', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 150.ms, duration: 500.ms),

              const Gap(24),

              // Saved Addresses Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved Addresses 🏠',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AddEditAddressModal(),
                      );
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add New'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                    ),
                  ),
                ],
              ),

              const Gap(10),

              // Saved Addresses Cards List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: addressesList.length,
                separatorBuilder: (_, __) => const Gap(12),
                itemBuilder: (context, index) {
                  final address = addressesList[index];
                  final isSelected = selectedAddr?.id == address.id;

                  IconData labelIcon = Iconsax.home;
                  if (address.label == 'Work') labelIcon = Iconsax.briefcase;
                  if (address.label == 'Other') labelIcon = Iconsax.location;

                  return GestureDetector(
                    onTap: () {
                      ref.read(addressProvider.notifier).selectAddress(address, ref);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Radio Green Tick Selection
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? AppColors.success : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.success
                                    : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const Gap(14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      labelIcon,
                                      size: 15,
                                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                    ),
                                    const Gap(4),
                                    Flexible(
                                      child: Text(
                                        address.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : AppColors.textDark,
                                        ),
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const Gap(6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'DEFAULT',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const Gap(6),
                                Text(
                                  address.fullAddress,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Edit & Delete Icons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Iconsax.edit, size: 16),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => AddEditAddressModal(existingAddress: address),
                                    );
                                  },
                                ),
                              ),
                              const Gap(4),
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Iconsax.trash, size: 16, color: AppColors.error),
                                  onPressed: () {
                                    ref.read(addressProvider.notifier).deleteAddress(address.id, ref);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

              const Gap(24),

              // Menu Group Container
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Iconsax.ticket_discount, color: AppColors.primary),
                      title: const Text('Offers & Coupons', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/offers'),
                    ),
                    Builder(
                      builder: (context) {
                        final nearbyAsync = ref.watch(nearbyRestaurantsStreamProvider);
                        final bool hasDineIn = nearbyAsync.value?.any((r) => r.hasDineIn) ?? true;
                        if (!hasDineIn) return const SizedBox.shrink();
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.table_restaurant_rounded, color: AppColors.primary),
                              title: const Text('My Table Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => context.push('/bookings'),
                            ),
                          ],
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Iconsax.setting, color: AppColors.primary),
                      title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/settings'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Iconsax.logout, color: AppColors.error),
                      title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.error),
                      onTap: _showLogoutDialog,
                    ),
                  ],
                ),
              ),

              const Gap(30),
            ],
          ),
        ),
      ),
    );
  }
}
