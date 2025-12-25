// lib/widgets/quick_add_category_dialog.dart
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../database/category_queries.dart';
import '../widgets/top_alert.dart';

class QuickAddCategoryDialog extends StatefulWidget {
  final Function(Category)? onCategoryAdded;
  final List<Category> existingCategories;
  final bool addToDatabase; // إضافة معلمة جديدة

  const QuickAddCategoryDialog({
    super.key,
    this.onCategoryAdded,
    required this.existingCategories,
    this.addToDatabase = true, // القيمة الافتراضية: نعم
  });

  @override
  State<QuickAddCategoryDialog> createState() => _QuickAddCategoryDialogState();
}

class _QuickAddCategoryDialogState extends State<QuickAddCategoryDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final CategoryQueries _categoryQueries = CategoryQueries();
  String _selectedColor = "#3B82F6";
  bool _isSaving = false;

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
    _nameController.clear();
    _descriptionController.clear();
    _selectedColor = "#3B82F6";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
    return Color(int.parse(hex, radix: 16));
  }

  Future<void> _submitForm() async {
    final categoryName = _nameController.text.trim();
    if (categoryName.isEmpty) {
      TopAlert.showError(context: context, message: "يرجى إدخال اسم الفئة");
      return;
    }

    // التحقق من عدم تكرار اسم الفئة
    final isDuplicate = widget.existingCategories.any(
      (category) => category.name.toLowerCase() == categoryName.toLowerCase(),
    );

    if (isDuplicate) {
      TopAlert.showError(context: context, message: "اسم الفئة موجود مسبقاً");
      return;
    }

    if (widget.addToDatabase) {
      // ✅ إضافة الفئة إلى قاعدة البيانات
      await _addToDatabase(categoryName);
    } else {
      // ❌ الطريقة القديمة (إضافة في الذاكرة فقط)
      _addToMemory(categoryName);
    }
  }

  Future<void> _addToDatabase(String categoryName) async {
    setState(() => _isSaving = true);

    try {
      // 1. التحقق من عدم وجود الفئة في قاعدة البيانات
      final isNameExists = await _categoryQueries.isCategoryNameExists(
        categoryName,
      );

      if (isNameExists) {
        TopAlert.showError(
          context: context,
          message: "فئة '$categoryName' موجودة مسبقاً في قاعدة البيانات",
        );
        setState(() => _isSaving = false);
        return;
      }

      // 2. إنشاء كائن الفئة
      final newCategory = Category(
        name: categoryName,
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        color: _selectedColor,
      );

      // 3. إضافة الفئة إلى قاعدة البيانات
      final insertedId = await _categoryQueries.insertCategory(newCategory);

      // 4. إنشاء الفئة مع ID الحقيقي
      final savedCategory = newCategory.copyWith(id: insertedId);

      // 5. إعلام الوالد بالتحديث
      if (widget.onCategoryAdded != null) {
        widget.onCategoryAdded!(savedCategory);
      }

      // 6. إغلاق الديالوغ وإرجاع الفئة
      if (context.mounted) {
        Navigator.of(context).pop(savedCategory);
      }

      TopAlert.showSuccess(
        context: context,
        message: "تم إضافة فئة '$categoryName' إلى قاعدة البيانات",
      );
    } catch (e) {
      if (context.mounted) {
        TopAlert.showError(
          context: context,
          message: 'خطأ في إضافة الفئة إلى قاعدة البيانات: $e',
        );
      }
      setState(() => _isSaving = false);
    }
  }

  void _addToMemory(String categoryName) {
    // الطريقة القديمة - إضافة في الذاكرة فقط
    final newCategory = Category(
      name: categoryName,
      description:
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
      color: _selectedColor,
    );

    if (widget.onCategoryAdded != null) {
      widget.onCategoryAdded!(newCategory);
    }

    Navigator.of(context).pop(newCategory);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, minWidth: 300),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان
              Center(
                child: Text(
                  "إضافة فئة جديدة",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // حقل الاسم
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "اسم الفئة *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  isDense: true,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // اختيار اللون
              const Text(
                "اختر لوناً للفئة:",
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              const SizedBox(height: 8),

              // عرض اللون المختار حالياً
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _hexToColor(_selectedColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _hexToColor(_selectedColor),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26, width: 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedColor,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // شبكة الألوان
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children:
                    _colors.map((color) {
                      return GestureDetector(
                        onTap: () {
                          if (!_isSaving) {
                            setState(() {
                              _selectedColor = color;
                            });
                          }
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _hexToColor(color),
                            shape: BoxShape.circle,
                            border:
                                _selectedColor == color
                                    ? Border.all(color: Colors.white, width: 3)
                                    : Border.all(color: Colors.grey[300]!),
                            boxShadow:
                                _selectedColor == color
                                    ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                    : [],
                          ),
                          child:
                              _selectedColor == color
                                  ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  )
                                  : null,
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 20),

              // إشعار حفظ قاعدة البيانات
              if (widget.addToDatabase)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.storage, size: 16, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "سيتم حفظ الفئة في قاعدة البيانات",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // أزرار التحكم
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isSaving ? Colors.grey[400] : Colors.green[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                        ),
                        child:
                            _isSaving
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  "إضافة",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed:
                            _isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(color: Colors.grey[400]!),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          "إلغاء",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
