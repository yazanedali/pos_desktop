import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final List<Category> categories;
  final Function(Product) onEdit;
  final Function(int) onDelete;

  const ProductCard({
    super.key,
    required this.product,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getCategoryColor(String categoryName) {
    final category = categories.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => Category(id: 0, name: "", color: "#6B7280"),
    );
    return _hexToColor(category.color);
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  // دالة جديدة لتنسيق الكمية
  String _formatStock(double stock) {
    // إذا كان الرقم صحيحاً، عرضه بدون فواصل عشرية
    if (stock % 1 == 0) {
      return stock.toInt().toString();
    }
    // إذا كان عشرياً، عرضه بحد أقصى منزلتين عشريتين
    return stock.toStringAsFixed(2).replaceAll(RegExp(r'\.?0*$'), '');
  }

  // دالة جديدة لتحديد حجم النص بناءً على طول الرقم
  double _getStockFontSize(String stockText) {
    if (stockText.length <= 2) return 12;
    if (stockText.length == 3) return 11;
    if (stockText.length == 4) return 10;
    return 9;
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor =
        product.category != null
            ? _getCategoryColor(product.category!)
            : Colors.grey;

    // تنسيق الكمية
    final formattedStock = _formatStock(product.stock);
    final stockFontSize = _getStockFontSize(formattedStock);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // =============== بطاقة المنتج الأساسية ==================
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SizedBox(
            height: 210,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20), // مكان لفئة المنتج فوق

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // اسم المنتج
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const Spacer(),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${product.price.toStringAsFixed(1)} شيكل",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),

                            // دائرة المخزون - معدلة لتكون متجاوبة
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formattedStock,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: stockFontSize,
                                    height: 1.0,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Text(
                          "الباركود:",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          product.barcode ?? "",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => onEdit(product),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text("تعديل"),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          onPressed: () => onDelete(product.id!),
                          icon: const Icon(
                            Icons.delete,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ===================== وسم الفئة =======================
        Positioned(
          top: -10,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              product.category ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
