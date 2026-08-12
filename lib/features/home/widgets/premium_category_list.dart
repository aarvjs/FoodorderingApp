import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/config/app_colors.dart';
import '../providers/restaurant_providers.dart';

class CategoryData {
  final String name;
  final String imageUrl;
  final Color bgColor;
  final Color shadowColor;

  const CategoryData({
    required this.name,
    required this.imageUrl,
    required this.bgColor,
    required this.shadowColor,
  });
}

class PremiumCategoryList extends ConsumerStatefulWidget {
  final bool isDark;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  const PremiumCategoryList({
    super.key,
    required this.isDark,
    this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  ConsumerState<PremiumCategoryList> createState() => _PremiumCategoryListState();
}

class _PremiumCategoryListState extends ConsumerState<PremiumCategoryList> {
  static const List<CategoryData> _defaultCategories = [
    CategoryData(
      name: 'Pizza',
      imageUrl:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=200&q=85&auto=format&fit=crop',
      bgColor: Color(0xFFFFEEEB),
      shadowColor: Color(0xFFFF4D4F),
    ),
    CategoryData(
      name: 'Burger',
      imageUrl:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&q=85&auto=format&fit=crop',
      bgColor: Color(0xFFFFF4E8),
      shadowColor: Color(0xFFFF8A00),
    ),
    CategoryData(
      name: 'Biryani',
      imageUrl:
          'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=200&q=85&auto=format&fit=crop',
      bgColor: Color(0xFFFFF8E1),
      shadowColor: Color(0xFFD97706),
    ),
    CategoryData(
      name: 'Chinese',
      imageUrl:
          'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=200&q=85&auto=format&fit=crop',
      bgColor: Color(0xFFFFEBEE),
      shadowColor: Color(0xFFE53935),
    ),
    CategoryData(
      name: 'Roll',
      imageUrl:
          'https://images.unsplash.com/photo-1626700051175-6518c4793f4f?w=200&q=85&auto=format&fit=crop',
      bgColor: Color(0xFFE8F5E9),
      shadowColor: Color(0xFF43A047),
    ),
    CategoryData(
      name: 'Cake',
      imageUrl:
          'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=200&q=85&auto=format&fit=crop',
      bgColor: Color(0xFFF8E8FF),
      shadowColor: Color(0xFF9C27B0),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    List<CategoryData> categoriesList = _defaultCategories;
    categoriesAsync.whenData((models) {
      if (models.isNotEmpty) {
        final dynamicCats = models
            .where((m) => m.imageUrl.isNotEmpty && !m.imageUrl.contains('unsplash.com'))
            .map((m) => CategoryData(
                  name: m.name,
                  imageUrl: m.imageUrl,
                  bgColor: m.bgColor,
                  shadowColor: m.shadowColor,
                ))
            .toList();
        if (dynamicCats.isNotEmpty) {
          categoriesList = dynamicCats;
        }
      }
    });

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: categoriesList.length,
        itemBuilder: (context, index) {
          final cat = categoriesList[index];
          final isSelected = widget.selectedCategory == cat.name;
          return _CategoryItem(
            category: cat,
            isSelected: isSelected,
            isDark: widget.isDark,
            animationDelay: index * 50,
            onTap: () {
              widget.onCategorySelected(
                isSelected ? null : cat.name,
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryItem extends StatefulWidget {
  final CategoryData category;
  final bool isSelected;
  final bool isDark;
  final int animationDelay;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category,
    required this.isSelected,
    required this.isDark,
    required this.animationDelay,
    required this.onTap,
  });

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final isSelected = widget.isSelected;
    final isDark = widget.isDark;

    return GestureDetector(
      onTapDown: (_) => _scaleController.reverse(),
      onTapUp: (_) {
        _scaleController.forward();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.forward(),
      child: AnimatedBuilder(
        animation: _scaleController,
        builder: (context, child) => Transform.scale(
          scale: _scaleController.value,
          child: child,
        ),
        child: Container(
          width: 64,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Circular icon with glass selection effect
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? (isSelected
                          ? cat.shadowColor.withOpacity(0.18)
                          : const Color(0xFF232323))
                      : (isSelected ? cat.bgColor : Colors.white),
                  border: Border.all(
                    color: isSelected
                        ? cat.shadowColor
                        : (isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.grey.shade100),
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? cat.shadowColor.withOpacity(0.32)
                          : Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                      blurRadius: isSelected ? 14 : 6,
                      spreadRadius: isSelected ? 1 : 0,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: cat.imageUrl,
                        fit: BoxFit.cover,
                        width: 54,
                        height: 54,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          highlightColor: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade100,
                          child: Container(color: Colors.grey.shade200),
                        ),
                        errorWidget: (context, url, err) => Container(
                          color: cat.bgColor,
                          child: Icon(
                            Icons.fastfood_rounded,
                            color: cat.shadowColor,
                            size: 22,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned.fill(
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      cat.shadowColor.withOpacity(0.15),
                                      Colors.transparent,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 5),

              // Premium active indicator dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: isSelected ? 16 : 0,
                height: isSelected ? 3 : 0,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [cat.shadowColor, cat.shadowColor.withOpacity(0.6)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              SizedBox(height: isSelected ? 1 : 4),

              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? cat.shadowColor
                      : (isDark ? Colors.white60 : AppColors.textLight),
                ),
                child: Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.animationDelay))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.25, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }
}
