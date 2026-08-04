class CustomizationOptionModel {
  final String id;
  final String name;
  final double price;
  final bool isAvailable;

  const CustomizationOptionModel({
    required this.id,
    required this.name,
    required this.price,
    required this.isAvailable,
  });

  factory CustomizationOptionModel.fromMap(Map<String, dynamic> data) {
    final pVal = data['price'];
    final double price = (pVal is num)
        ? pVal.toDouble()
        : double.tryParse(pVal?.toString() ?? '0.0') ?? 0.0;

    return CustomizationOptionModel(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? 'Option').toString(),
      price: price,
      isAvailable: data['isAvailable'] != false,
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
