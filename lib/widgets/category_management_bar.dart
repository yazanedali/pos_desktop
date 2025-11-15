import 'package:flutter/material.dart';
import '../../../models/category.dart';
import '../dialogs/category_dialog.dart'; // استيراد النافذة الجديدة
import '../../../database/category_queries.dart'; // لتنفيذ عمليات الحذف

class CategoryManagementBar extends StatelessWidget {
  final List<Category> categories;
  final Function onCategoriesUpdate; // لتحديث القائمة بعد أي تغيير

  const CategoryManagementBar({
    super.key,
    required this.categories,
    required this.onCategoriesUpdate,
  });

  void _showCategoryDialog(BuildContext context, {Category? category}) {
    showDialog(
      context: context,
      builder:
          (ctx) => CategoryDialog(
            category: category,
            onSave: (name, color) async {
              final newCategory = Category(
                id: category?.id,
                name: name,
                color: color,
              );
              if (category == null) {
                await CategoryQueries().insertCategory(newCategory);
              } else {
                await CategoryQueries().updateCategory(newCategory);
              }
              onCategoriesUpdate();
            },
          ),
    );
  }

  Future<void> _handleDeleteCategory(
    BuildContext context,
    Category category,
  ) async {
    // 1. التحقق من وجود منتجات مرتبطة بالفئة
    final productCount = await CategoryQueries().countProductsInCategory(
      category.id!,
    );

    if (productCount > 0) {
      // 2. إذا كانت هناك منتجات، اعرض رسالة خطأ
      showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text("لا يمكن الحذف"),
              content: Text(
                "هذه الفئة مرتبطة بـ $productCount منتج. لا يمكن حذفها إلا بعد تغيير فئة هذه المنتجات.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("حسنًا"),
                ),
              ],
            ),
      );
    } else {
      // 3. إذا لم تكن هناك منتجات، اعرض نافذة تأكيد الحذف
      showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text("تأكيد الحذف"),
              content: Text(
                "هل أنت متأكد من رغبتك في حذف الفئة '${category.name}'؟",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop(); // أغلق نافذة التأكيد
                    await CategoryQueries().deleteCategory(category.id!);
                    onCategoriesUpdate(); // حدث الواجهة
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("حذف"),
                ),
              ],
            ),
      );
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "الفئات",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCategoryDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("إضافة فئة"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[800],
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            categories.isEmpty
                ? const Text(
                  "لا توجد فئات. قم بإضافة فئة جديدة للبدء.",
                  style: TextStyle(color: Colors.grey),
                )
                : Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children:
                      categories.map((cat) {
                        // --- === تعديل: جعل الشريحة قابلة للنقر للتعديل === ---
                        return InkWell(
                          onTap:
                              () => _showCategoryDialog(context, category: cat),
                          borderRadius: BorderRadius.circular(20),
                          child: Chip(
                            label: Text(cat.name),
                            avatar: CircleAvatar(
                              // ignore: deprecated_member_use
                              backgroundColor: Colors.white.withOpacity(0.5),
                              child: Icon(
                                Icons.edit,
                                size: 14,
                                color: _hexToColor(cat.color),
                              ),
                            ),
                            backgroundColor: _hexToColor(
                              cat.color,
                              // ignore: deprecated_member_use
                            ).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: _hexToColor(cat.color),
                              fontWeight: FontWeight.bold,
                            ),
                            // --- تعديل: ربط الحذف بالدالة الجديدة ---
                            onDeleted:
                                () => _handleDeleteCategory(context, cat),
                            deleteIconColor: _hexToColor(cat.color),
                            side: BorderSide(color: _hexToColor(cat.color)),
                          ),
                        );
                      }).toList(),
                ),
          ],
        ),
      ),
    );
  }
}
