import 'package:flutter/material.dart';
import '../models/category.dart';
import '../database/category_queries.dart';
import '../widgets/top_alert.dart'; // تأكد من المسار الصحيح

class CategoryManagement extends StatefulWidget {
  final List<Category>? categories; // جعله اختياري للتوافق
  final Function(List<Category>)? onCategoriesUpdate; // للتوافق مع الكود القديم
  final Function()? onCategoriesUpdated; // الكود الجديد

  const CategoryManagement({
    super.key,
    this.categories,
    this.onCategoriesUpdate,
    this.onCategoriesUpdated,
  });

  @override
  State<CategoryManagement> createState() => _CategoryManagementState();
}

class _CategoryManagementState extends State<CategoryManagement> {
  final CategoryQueries _categoryQueries = CategoryQueries();
  List<Category> _categories = [];
  bool _isLoading = true;
  bool _isDialogOpen = false;
  Category? _editingCategory;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedColor = "#3B82F6";

  final List<String> _colors = [
    "#3B82F6",
    "#10B981",
    "#F59E0B",
    "#EF4444",
    "#8B5CF6",
    "#06B6D4",
    "#84CC16",
    "#F97316",
  ];

  @override
  void initState() {
    super.initState();
    _initializeCategories();
  }

  void _initializeCategories() async {
    // إذا تم تمرير categories كمعامل، استخدمها مباشرة (للتوافق)
    if (widget.categories != null && widget.categories!.isNotEmpty) {
      setState(() {
        _categories = widget.categories!;
        _isLoading = false;
      });
    } else {
      // وإلا قم بتحميل الفئات من قاعدة البيانات
      await _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final categories = await _categoryQueries.getAllCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // ignore: use_build_context_synchronously
      TopAlert.showError(context: context, message: 'خطأ في تحميل الفئات: $e');
    }
  }

  void _openDialog({Category? category}) {
    setState(() {
      _editingCategory = category;
      _isDialogOpen = true;

      if (category != null) {
        _nameController.text = category.name;
        _descriptionController.text = category.description ?? '';
        _selectedColor = category.color;
      } else {
        _nameController.clear();
        _descriptionController.clear();
        _selectedColor = "#3B82F6";
      }
    });
  }

  void _closeDialog() {
    setState(() {
      _isDialogOpen = false;
      _editingCategory = null;
      _nameController.clear();
      _descriptionController.clear();
    });
  }

  Future<void> _submitForm() async {
    if (_nameController.text.isEmpty) {
      TopAlert.showError(context: context, message: "يرجى إدخال اسم الفئة");
      return;
    }

    try {
      // التحقق من عدم تكرار اسم الفئة
      final isNameExists = await _categoryQueries.isCategoryNameExists(
        _nameController.text,
        excludeId: _editingCategory?.id,
      );

      if (isNameExists) {
        // ignore: use_build_context_synchronously
        TopAlert.showError(context: context, message: "اسم الفئة موجود مسبقاً");
        return;
      }

      final newCategory = Category(
        id: _editingCategory?.id,
        name: _nameController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        color: _selectedColor,
      );

      if (_editingCategory != null) {
        // تحديث الفئة
        await _categoryQueries.updateCategory(newCategory);
        TopAlert.showSuccess(
          // ignore: use_build_context_synchronously
          context: context,
          message: "تم تحديث فئة ${newCategory.name} بنجاح",
        );
      } else {
        // إضافة فئة جديدة
        await _categoryQueries.insertCategory(newCategory);
        TopAlert.showSuccess(
          // ignore: use_build_context_synchronously
          context: context,
          message: "تم إضافة فئة ${newCategory.name} بنجاح",
        );
      }

      await _loadCategories();

      _notifyParent();

      _closeDialog();
    } catch (e) {
      // ignore: use_build_context_synchronously
      TopAlert.showError(context: context, message: 'خطأ في حفظ الفئة: $e');
    }
  }

  void _notifyParent() {
    // إخطار الوالدة بالتحديث باستخدام الطريقة المناسبة
    if (widget.onCategoriesUpdated != null) {
      widget.onCategoriesUpdated!();
    }
    if (widget.onCategoriesUpdate != null) {
      widget.onCategoriesUpdate!(_categories);
    }
  }

  Future<void> _deleteCategory(int id) async {
    try {
      final category = _categories.firstWhere((c) => c.id == id);

      // التحقق من عدد المنتجات في الفئة
      final productsCount = await _categoryQueries.getProductsCountInCategory(
        id,
      );

      if (productsCount > 0) {
        TopAlert.showError(
          // ignore: use_build_context_synchronously
          context: context,
          message:
              'لا يمكن حذف فئة "${category.name}" لأنها تحتوي على $productsCount منتج',
        );
        return;
      }

      // تأكيد الحذف
      final confirmed = await showDialog<bool>(
        // ignore: use_build_context_synchronously
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("تأكيد الحذف"),
              content: Text("هل أنت متأكد من حذف فئة '${category.name}'؟"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("حذف"),
                ),
              ],
            ),
      );

      if (confirmed == true) {
        await _categoryQueries.deleteCategory(id);
        // ignore: use_build_context_synchronously
        TopAlert.showSuccess(context: context, message: "تم حذف الفئة بنجاح");

        // إعادة تحميل الفئات من قاعدة البيانات
        await _loadCategories();

        // إخطار الواجهة الرئيسية بالتحديث
        _notifyParent();
      }
    } catch (e) {
      // عرض رسالة الخطأ المناسبة
      if (e.toString().contains('منتجات')) {
        // ignore: use_build_context_synchronously
        TopAlert.showError(context: context, message: e.toString());
      } else {
        // ignore: use_build_context_synchronously
        TopAlert.showError(context: context, message: 'خطأ في حذف الفئة: $e');
      }
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
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
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.category, size: 20, color: Colors.blue[800]),
                    const SizedBox(width: 8),
                    const Text(
                      "إدارة الفئات",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _openDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16),
                      SizedBox(width: 4),
                      Text("إضافة فئة"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Categories Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child:
                _isLoading
                    ? _buildLoadingState()
                    : _categories.isEmpty
                    ? _buildEmptyState()
                    : _buildCategoriesGrid(),
          ),

          // Dialog
          if (_isDialogOpen) _buildCategoryDialog(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("جاري تحميل الفئات..."),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        return _buildCategoryCard(_categories[index]);
      },
    );
  }

  Widget _buildCategoryCard(Category category) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue[50]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Color and Text
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _hexToColor(category.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (category.description != null &&
                            category.description!.isNotEmpty)
                          Text(
                            category.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _openDialog(category: category),
                  icon: const Icon(Icons.edit, size: 16),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  color: Colors.grey[600],
                ),
                IconButton(
                  onPressed: () => _deleteCategory(category.id!),
                  icon: const Icon(Icons.delete, size: 16),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "لا توجد فئات محددة",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            "قم بإضافة فئة جديدة لتنظيم المنتجات",
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editingCategory == null ? "إضافة فئة جديدة" : "تعديل الفئة",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Name Field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "اسم الفئة *",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description Field
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "وصف الفئة",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Color Selection
            const Text(
              "لون الفئة",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _colors.map((color) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _hexToColor(color),
                          shape: BoxShape.circle,
                          border:
                              _selectedColor == color
                                  ? Border.all(color: Colors.black, width: 3)
                                  : Border.all(color: Colors.grey[300]!),
                        ),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(_editingCategory == null ? "إضافة" : "تحديث"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _closeDialog,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("إلغاء"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
