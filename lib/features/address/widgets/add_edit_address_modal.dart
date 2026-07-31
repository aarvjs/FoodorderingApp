import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import '../../../core/config/app_colors.dart';
import '../../../models/address.dart';
import '../providers/address_provider.dart';

class AddEditAddressModal extends ConsumerStatefulWidget {
  final Address? existingAddress;

  const AddEditAddressModal({
    super.key,
    this.existingAddress,
  });

  @override
  ConsumerState<AddEditAddressModal> createState() => _AddEditAddressModalState();
}

class _AddEditAddressModalState extends ConsumerState<AddEditAddressModal> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedLabel;
  late TextEditingController _houseController;
  late TextEditingController _buildingController;
  late TextEditingController _streetController;
  late TextEditingController _areaController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _landmarkController;

  @override
  void initState() {
    super.initState();
    final a = widget.existingAddress;
    _selectedLabel = a?.label ?? 'Home';
    _houseController = TextEditingController(text: a?.houseNumber ?? '');
    _buildingController = TextEditingController(text: a?.building ?? '');
    _streetController = TextEditingController(text: a?.street ?? '');
    _areaController = TextEditingController(text: a?.area ?? '');
    _cityController = TextEditingController(text: a?.city ?? 'Bengaluru');
    _stateController = TextEditingController(text: a?.state ?? 'Karnataka');
    _pincodeController = TextEditingController(text: a?.pincode ?? '');
    _landmarkController = TextEditingController(text: a?.landmark ?? '');
  }

  @override
  void dispose() {
    _houseController.dispose();
    _buildingController.dispose();
    _streetController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final parts = <String>[];
    if (_houseController.text.trim().isNotEmpty) parts.add(_houseController.text.trim());
    if (_buildingController.text.trim().isNotEmpty) parts.add(_buildingController.text.trim());
    if (_streetController.text.trim().isNotEmpty) parts.add(_streetController.text.trim());
    if (_areaController.text.trim().isNotEmpty) parts.add(_areaController.text.trim());
    if (_cityController.text.trim().isNotEmpty) parts.add(_cityController.text.trim());

    final fullAddressStr = parts.isNotEmpty
        ? parts.join(', ')
        : '${_houseController.text.trim()}, ${_cityController.text.trim()}';

    final addressId = widget.existingAddress?.id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}';

    final updatedAddress = Address(
      id: addressId,
      label: _selectedLabel,
      fullAddress: fullAddressStr,
      houseNumber: _houseController.text.trim(),
      building: _buildingController.text.trim(),
      street: _streetController.text.trim(),
      area: _areaController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      landmark: _landmarkController.text.trim(),
      latitude: widget.existingAddress?.latitude ?? 12.9716,
      longitude: widget.existingAddress?.longitude ?? 77.5946,
      isDefault: widget.existingAddress?.isDefault ?? true,
      createdAt: widget.existingAddress?.createdAt ?? DateTime.now(),
    );

    final notifier = ref.read(addressProvider.notifier);

    if (widget.existingAddress != null) {
      notifier.editAddress(updatedAddress, ref);
    } else {
      notifier.addAddress(updatedAddress, ref);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const Gap(16),

                Text(
                  widget.existingAddress != null ? 'Edit Address' : 'Add New Address',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                const Gap(16),

                // Label selector chips (Home / Work / Other)
                Text(
                  'Save Address As',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                  ),
                ),
                const Gap(8),
                Row(
                  children: ['Home', 'Work', 'Other'].map((label) {
                    final isSel = _selectedLabel == label;
                    IconData iconData = Iconsax.home;
                    if (label == 'Work') iconData = Iconsax.briefcase;
                    if (label == 'Other') iconData = Iconsax.location;

                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              iconData,
                              size: 16,
                              color: isSel ? Colors.white : (isDark ? Colors.white70 : AppColors.textDark),
                            ),
                            const Gap(6),
                            Text(label),
                          ],
                        ),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : (isDark ? Colors.white70 : AppColors.textDark),
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedLabel = label);
                        },
                      ),
                    );
                  }).toList(),
                ),

                const Gap(16),

                // House / Flat Number
                TextFormField(
                  controller: _houseController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter House/Flat No.' : null,
                  decoration: InputDecoration(
                    labelText: 'House / Flat / Door No.*',
                    prefixIcon: const Icon(Iconsax.house),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const Gap(12),

                // Building Name
                TextFormField(
                  controller: _buildingController,
                  decoration: InputDecoration(
                    labelText: 'Building / Apartment Name',
                    prefixIcon: const Icon(Iconsax.building),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const Gap(12),

                // Street & Area
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _streetController,
                        decoration: InputDecoration(
                          labelText: 'Street Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: TextFormField(
                        controller: _areaController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter Area' : null,
                        decoration: InputDecoration(
                          labelText: 'Area / Suburb*',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(12),

                // City & State
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter City' : null,
                        decoration: InputDecoration(
                          labelText: 'City*',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(12),

                // Pincode & Landmark
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter Pincode' : null,
                        decoration: InputDecoration(
                          labelText: 'Pincode*',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: TextFormField(
                        controller: _landmarkController,
                        decoration: InputDecoration(
                          labelText: 'Landmark (Optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),

                const Gap(24),

                // Save Address Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Save Address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
