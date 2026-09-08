class CustomizationOptionModel {
  final String id;
  final String name;
  final double price;
  final double basePrice;
  final double extraPrice;
  final int minQuantity;
  final int maxQuantity;
  final int quantityStep;
  final bool allowQuantity;
  final bool isAvailable;

  const CustomizationOptionModel({
    required this.id,
    required this.name,
    required this.price,
    this.basePrice = 0.0,
    this.extraPrice = 0.0,
    this.minQuantity = 1,
    this.maxQuantity = 10,
    this.quantityStep = 1,
    this.allowQuantity = true,
    required this.isAvailable,
  });

  factory CustomizationOptionModel.fromMap(Map<String, dynamic> data) {
    final pVal = data['price'] ?? data['extraPrice'] ?? data['additionalPrice'] ?? 0;
    final double price = (pVal is num)
        ? pVal.toDouble()
        : double.tryParse(pVal?.toString() ?? '0.0') ?? 0.0;

    final bpVal = data['basePrice'] ?? 0;
    final double basePrice = (bpVal is num)
        ? bpVal.toDouble()
        : double.tryParse(bpVal?.toString() ?? '0.0') ?? 0.0;

    final epVal = data['extraPrice'] ?? data['additionalPrice'] ?? price;
    final double extraPrice = (epVal is num)
        ? epVal.toDouble()
        : double.tryParse(epVal?.toString() ?? '0.0') ?? price;

    final minQ = data['minQuantity'] ?? data['minQty'] ?? 1;
    final maxQ = data['maxQuantity'] ?? data['maxQty'] ?? 10;
    final stepQ = data['quantityStep'] ?? data['step'] ?? 1;

    return CustomizationOptionModel(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? 'Option').toString(),
      price: price,
      basePrice: basePrice,
      extraPrice: extraPrice,
      minQuantity: (minQ is num) ? minQ.toInt() : 1,
      maxQuantity: (maxQ is num) ? maxQ.toInt() : 10,
      quantityStep: (stepQ is num) ? stepQ.toInt() : 1,
      allowQuantity: data['allowQuantity'] != false,
      isAvailable: data['isAvailable'] != false && data['isActive'] != false,
    );
  }
}

class CustomizationGroupModel {
  final String id;
  final String title;
  final String selectionType; // 'single' or 'multi'
  final bool isRequired;
  final int minSelection;
  final int maxSelection;
  final List<CustomizationOptionModel> options;

  const CustomizationGroupModel({
    required this.id,
    required this.title,
    required this.selectionType,
    required this.isRequired,
    required this.minSelection,
    required this.maxSelection,
    required this.options,
  });

  factory CustomizationGroupModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final optionsList = (data['options'] as List?)
            ?.map((opt) => CustomizationOptionModel.fromMap(Map<String, dynamic>.from(opt)))
            .toList() ??
        [];

    final minVal = data['minSelection'];
    final maxVal = data['maxSelection'];

    return CustomizationGroupModel(
      id: docId,
      title: (data['title'] ?? 'Customization Group').toString(),
      selectionType: (data['selectionType'] ?? 'single').toString(),
      isRequired: data['isRequired'] == true,
      minSelection: (minVal is num) ? minVal.toInt() : (data['isRequired'] == true ? 1 : 0),
      maxSelection: (maxVal is num) ? maxVal.toInt() : 1,
      options: optionsList,
    );
  }
}
