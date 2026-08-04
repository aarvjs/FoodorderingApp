class ComboReplacementItem {
  final String productId;
  final String productName;
  final String? productImage;
  final double extraPrice;

  const ComboReplacementItem({
    required this.productId,
    required this.productName,
    this.productImage,
    required this.extraPrice,
  });

  factory ComboReplacementItem.fromMap(Map<String, dynamic> data) {
    final extraVal = data['extraPrice'];
    final double extraPrice = (extraVal is num)
        ? extraVal.toDouble()
        : double.tryParse(extraVal?.toString() ?? '0.0') ?? 0.0;

    return ComboReplacementItem(
      productId: (data['productId'] ?? '').toString(),
      productName: (data['productName'] ?? 'Replacement Item').toString(),
      productImage: data['productImage']?.toString(),
      extraPrice: extraPrice,
    );
  }
}

class ComboItemReference {
  final String productId;
  final String productName;
  final String? productImage;
  final double? productPrice;
  final int defaultQuantity;
  final bool canRemove;
  final double priceDeductionOnRemoval;
  final List<ComboReplacementItem> allowedReplacements;

  const ComboItemReference({
    required this.productId,
    required this.productName,
    this.productImage,
    this.productPrice,
    required this.defaultQuantity,
    required this.canRemove,
    required this.priceDeductionOnRemoval,
    required this.allowedReplacements,
  });

  factory ComboItemReference.fromMap(Map<String, dynamic> data) {
    final dedVal = data['priceDeductionOnRemoval'];
    final double priceDeductionOnRemoval = (dedVal is num)
        ? dedVal.toDouble()
        : double.tryParse(dedVal?.toString() ?? '0.0') ?? 0.0;

    final priceVal = data['productPrice'];
    final double? productPrice = (priceVal is num)
        ? priceVal.toDouble()
        : (priceVal != null ? double.tryParse(priceVal.toString()) : null);

    final qtyVal = data['defaultQuantity'];
    final int defaultQuantity = (qtyVal is num) ? qtyVal.toInt() : 1;

    final replacementsList = (data['allowedReplacements'] as List?)
            ?.map((item) => ComboReplacementItem.fromMap(Map<String, dynamic>.from(item)))
            .toList() ??
        [];

    return ComboItemReference(
      productId: (data['productId'] ?? '').toString(),
      productName: (data['productName'] ?? 'Item').toString(),
      productImage: data['productImage']?.toString(),
      productPrice: productPrice,
      defaultQuantity: defaultQuantity,
      canRemove: data['canRemove'] == true,
      priceDeductionOnRemoval: priceDeductionOnRemoval,
      allowedReplacements: replacementsList,
    );
  }
}

class ComboAddonOption {
  final String id;
  final String name;
  final double price;
  final bool isAvailable;

  const ComboAddonOption({
    required this.id,
    required this.name,
    required this.price,
    required this.isAvailable,
  });

  factory ComboAddonOption.fromMap(Map<String, dynamic> data) {
    final pVal = data['price'];
    final double price = (pVal is num)
        ? pVal.toDouble()
        : double.tryParse(pVal?.toString() ?? '0.0') ?? 0.0;

    return ComboAddonOption(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? 'Extra Option').toString(),
      price: price,
      isAvailable: data['isAvailable'] != false,
    );
  }
}

class ComboAddonGroup {
  final String id;
  final String title;
  final String type; // 'single' or 'multi'
  final bool isRequired;
  final int minSelection;
  final int maxSelection;
  final List<ComboAddonOption> options;

  const ComboAddonGroup({
    required this.id,
    required this.title,
    this.type = 'multi',
    this.isRequired = false,
    this.minSelection = 0,
    this.maxSelection = 0,
    required this.options,
  });

  factory ComboAddonGroup.fromMap(Map<String, dynamic> data) {
    final optionsList = (data['options'] as List?)
            ?.map((opt) => ComboAddonOption.fromMap(Map<String, dynamic>.from(opt)))
            .toList() ??
        [];

    final minSel = data['minSelection'];
    final maxSel = data['maxSelection'];
    final rawType = (data['type'] ?? (data['isSingle'] == true ? 'single' : 'multi')).toString().toLowerCase();

    return ComboAddonGroup(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? 'Extras').toString(),
      type: (rawType == 'single' || data['isSingle'] == true || maxSel == 1) ? 'single' : 'multi',
      isRequired: data['isRequired'] == true || data['required'] == true,
      minSelection: (minSel is num) ? minSel.toInt() : 0,
      maxSelection: (maxSel is num) ? maxSel.toInt() : 0,
      options: optionsList,
    );
  }
}

class ComboModel {
  final String id;
  final String restaurantId;
  final String? branchId;
  final List<String> branchIds;
  final String name;
  final String description;
  final double price;
  final double? discountPrice;
  final String image;
  final bool isAvailable;
  final String availabilitySlot;
  final List<ComboItemReference> items;
  final List<ComboAddonGroup> addonGroups;

  const ComboModel({
    required this.id,
    required this.restaurantId,
    this.branchId,
    required this.branchIds,
    required this.name,
    required this.description,
    required this.price,
    this.discountPrice,
    required this.image,
    required this.isAvailable,
    required this.availabilitySlot,
    required this.items,
    required this.addonGroups,
  });

  factory ComboModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final priceVal = data['price'];
    final double price = (priceVal is num)
        ? priceVal.toDouble()
        : double.tryParse(priceVal?.toString() ?? '0.0') ?? 0.0;

    final discVal = data['discountPrice'];
    final double? discountPrice = (discVal is num)
        ? discVal.toDouble()
        : (discVal != null ? double.tryParse(discVal.toString()) : null);

    final itemsList = (data['items'] as List?)
            ?.map((item) => ComboItemReference.fromMap(Map<String, dynamic>.from(item)))
            .toList() ??
        [];

    final addonList = (data['addonGroups'] as List?)
            ?.map((grp) => ComboAddonGroup.fromMap(Map<String, dynamic>.from(grp)))
            .toList() ??
        [];

    final branchIdsList = (data['branchIds'] as List?)
            ?.map((b) => b.toString())
            .toList() ??
        [];

    return ComboModel(
      id: docId,
      restaurantId: (data['restaurantId'] ?? '').toString(),
      branchId: data['branchId']?.toString(),
      branchIds: branchIdsList,
      name: (data['name'] ?? 'Combo Meal').toString(),
      description: (data['description'] ?? '').toString(),
      price: price,
      discountPrice: discountPrice,
      image: (data['image'] ?? 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=500&auto=format&fit=crop').toString(),
      isAvailable: (data['isAvailable'] != false) && ((data['status'] ?? 'ACTIVE').toString().toUpperCase() != 'INACTIVE'),
      availabilitySlot: (data['availabilitySlot'] ?? 'FULL_DAY').toString(),
      items: itemsList,
      addonGroups: addonList,
    );
  }
}
