import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final List<Category> categories;
  final Function(Product) onEdit;
  final Function(int) onDelete;
  final bool hasMore;
  final bool isLoadingMore;
  final Function(int?)? onCategorySelected;
  final int? selectedCategoryId;

  const ProductGrid({
    super.key,
    required this.products,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onCategorySelected,
    this.selectedCategoryId,
  });

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // إضافة هذا السطر
      children: [
        // شريط الفئات
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // زر عرض الكل
                InkWell(
                  onTap: () => onCategorySelected?.call(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selectedCategoryId == null
                              ? Colors.blue[100]
                              : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
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
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: InkWell(
                      onTap: () => onCategorySelected?.call(category.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              selectedCategoryId == category.id
                                  ? _hexToColor(category.color)
                                  : Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          category.name,
                          style: TextStyle(
                            color:
                                selectedCategoryId == category.id
                                    ? Colors.white
                                    : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),

        // شبكة المنتجات - إزالة Expanded واستخدام SizedBox مع ارتفاع محدد
        SizedBox(
          height: 600, // أو أي ارتفاع مناسب لك
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 350,
              childAspectRatio: 3 / 2.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: products.length + (hasMore ? 1 : 0),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              if (index == products.length && hasMore) {
                return _buildLoadMoreIndicator();
              }

              final product = products[index];
              return ProductCard(
                product: product,
                categories: categories,
                onEdit: onEdit,
                onDelete: onDelete,
              );
            },
          ),
        ),

        // مؤشر تحميل إضافي
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.keyboard_arrow_down, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'تحميل المزيد',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
