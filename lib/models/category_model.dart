import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String imageUrl;
  final Color bgColor;
  final Color shadowColor;
  final String? description;
  final bool isActive;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.bgColor = const Color(0xFFFFEEEB),
    this.shadowColor = const Color(0xFFFF4D4F),
    this.description,
    this.isActive = true,
  });

  factory CategoryModel.fromFirestore(Map<String, dynamic> data, String id) {
    final name = (data['name'] ?? data['categoryName'] ?? 'Category').toString();
    final img = (data['image'] ?? data['imageUrl'] ?? '').toString();
    final status = (data['status'] ?? 'ACTIVE').toString();

    // Generate custom vibrant fallback color accents based on category name hash
    final hash = name.hashCode.abs();
    final accentColors = [
      const Color(0xFFFF4D4F),
      const Color(0xFFFF8A00),
      const Color(0xFFD97706),
      const Color(0xFFE53935),
      const Color(0xFF43A047),
      const Color(0xFF9C27B0),
      const Color(0xFF795548),
      const Color(0xFF1E88E5),
      const Color(0xFFE91E63),
    ];
    final shadowColor = accentColors[hash % accentColors.length];

    return CategoryModel(
      id: id,
      name: name,
      imageUrl: img.isNotEmpty
          ? img
          : 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=200&q=85&auto=format&fit=crop',
      bgColor: shadowColor.withOpacity(0.12),
      shadowColor: shadowColor,
      description: data['description']?.toString(),
      isActive: status == 'ACTIVE',
    );
  }
}
