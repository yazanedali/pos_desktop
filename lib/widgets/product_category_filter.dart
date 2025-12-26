import 'package:flutter/material.dart';
import '../../models/category.dart';

class ProductCategoryFilter extends StatelessWidget {
  final List<Category> categories;
  final int? selectedCategoryId;
  final Function(int?) onCategorySelected;

  const ProductCategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // زر عرض الكل
          InkWell(
            onTap: () => onCategorySelected(null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:
                    selectedCategoryId == null
                        ? Colors.blue[100]
                        : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
                border:
                    selectedCategoryId == null
                        ? Border.all(color: Colors.blue[300]!)
                        : null,
              ),
              child: Text(
                'الكل',
                style: TextStyle(
                  color:
                      selectedCategoryId == null
                          ? Colors.blue[800]
                          : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // قائمة الفئات
          ...categories.map((category) {
            final isSelected = selectedCategoryId == category.id;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: InkWell(
                onTap: () => onCategorySelected(category.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? _hexToColor(category.color)
                            : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                    border:
                        isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: _hexToColor(
                                  category.color,
                                ).withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                            : null,
                  ),
                  child: Text(
                    category.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
