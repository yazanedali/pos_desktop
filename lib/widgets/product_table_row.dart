import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/category.dart';

class ProductTableRow extends StatelessWidget {
  final Product product;
  final List<Category> categories;
  final Function(Product) onEdit;
  final Function(int) onDelete;
  final int index;

  const ProductTableRow({
    super.key,
    required this.product,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
    required this.index,
  });

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  // دالة لتحديد لون الكمية بناءً على المخزون
  Color _getStockColor() {
    if (product.stock <= 0) {
      return Colors.red;
    } else if (product.stock < 10) {
      return Colors.orange;
    }
    return Colors.green;
  }

  // دالة لتحديد خلفية وخلفية نص الكمية
  Color _getStockBackgroundColor() {
    if (product.stock <= 0) {
      return Colors.red.withOpacity(0.1);
    } else if (product.stock < 10) {
      return Colors.orange.withOpacity(0.1);
    }
    return Colors.green.withOpacity(0.1);
  }

  // دالة لتحديد نص التحذير للمخزون المنخفض
  String? _getStockWarning() {
    if (product.stock <= 0) {
      return 'نفذ من المخزون';
    } else if (product.stock < 5) {
      return 'مخزون منخفض جداً';
    } else if (product.stock < 10) {
      return 'مخزون منخفض';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final category =
        categories.isNotEmpty
            ? categories.firstWhere(
              (c) => c.id == product.categoryId,
              orElse: () => Category(name: 'غير مصنف', color: 'CCCCCC'),
            )
            : Category(name: 'غير مصنف', color: 'CCCCCC');

    final categoryColor = _hexToColor(category.color);
    final stockColor = _getStockColor();
    final stockBgColor = _getStockBackgroundColor();
    final stockWarning = _getStockWarning();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // يمكنك إضافة دالة للنقر على الصف هنا
          },
          hoverColor: Colors.blue[50],
          splashColor: Colors.blue[100],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // الرقم التسلسلي
                SizedBox(
                  width: 40,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // المنتج
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.barcode != null &&
                          product.barcode!.isNotEmpty)
                        const SizedBox(height: 4),
                      if (product.barcode != null &&
                          product.barcode!.isNotEmpty)
                        Text(
                          product.barcode!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // الكمية مع التنبيهات
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: stockBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: stockColor.withOpacity(0.3),
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getStockIcon(),
                                size: 14,
                                color: stockColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                product.stock.toStringAsFixed(1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: stockColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (stockWarning != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            stockWarning,
                            style: TextStyle(
                              fontSize: 10,
                              color: stockColor,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // سعر الشراء
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Center(
                      child: Text(
                        '${product.purchasePrice.toStringAsFixed(2)} ش',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // السعر (البيع)
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Center(
                      child: Text(
                        '${product.price.toStringAsFixed(2)} ش',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // الفئة
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: categoryColor.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // إجراءات
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // زر التعديل
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: Colors.blue,
                          onPressed: () => onEdit(product),
                          tooltip: 'تعديل',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          splashRadius: 20,
                        ),
                      ),

                      const SizedBox(width: 8),

                      // زر الحذف
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red,
                          onPressed: () => onDelete(product.id!),
                          tooltip: 'حذف',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          splashRadius: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // دالة لإرجاع الأيقونة المناسبة بناءً على المخزون
  IconData _getStockIcon() {
    if (product.stock <= 0) {
      return Icons.error_outline;
    } else if (product.stock < 10) {
      return Icons.warning_amber_outlined;
    }
    return Icons.check_circle_outline;
  }
}
