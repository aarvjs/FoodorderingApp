class ComboModel {
  final String id;
  final String name;
  final String image;
  final String description;
  final bool isActive;
  final String restaurantId;
  final String? branchId;
  final List<String> branchIds;
  final DateTime? createdAt;

  const ComboModel({
    required this.id,
    required this.name,
    required this.image,
    this.description = '',
    this.isActive = true,
    required this.restaurantId,
    this.branchId,
    required this.branchIds,
    this.createdAt,
  });

  factory ComboModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final branchIdsList = (data['branchIds'] as List?)
            ?.map((b) => b.toString().trim())
            .toList() ??
        [];

    final String name = (data['name'] ?? data['title'] ?? 'Combo').toString();
    final String image = (data['image'] ?? data['imageUrl'] ?? data['bannerUrl'] ?? 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop').toString();
    final String description = (data['description'] ?? '').toString();
    final bool isActive = (data['isActive'] != false) && (data['isAvailable'] != false);
    final String restaurantId = (data['restaurantId'] ?? '').toString();
    final String? branchId = data['branchId']?.toString();

    DateTime? createdAt;
    if (data['createdAt'] is String) {
      createdAt = DateTime.tryParse(data['createdAt']);
    }

    return ComboModel(
      id: docId,
      name: name,
      image: image,
      description: description,
      isActive: isActive,
      restaurantId: restaurantId,
      branchId: branchId,
      branchIds: branchIdsList,
      createdAt: createdAt,
    );
  }
}
