// lib/widgets/quick_add_category_dialog.dart
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../widgets/top_alert.dart';

class QuickAddCategoryDialog extends StatefulWidget {
  final Function(Category)? onCategoryAdded;
  final List<Category> existingCategories;

  const QuickAddCategoryDialog({
    super.key,
    this.onCategoryAdded,
    required this.existingCategories,
  });

  @override
  State<QuickAddCategoryDialog> createState() => _QuickAddCategoryDialogState();
}

class _QuickAddCategoryDialogState extends State<QuickAddCategoryDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
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

  void _submitForm() {
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // أصغر قليلاً
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20), // هوامش جانبية
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400, // عرض ثابت
          minWidth: 300, // عرض أدنى
        ),
        child: Padding(
          padding: const EdgeInsets.all(20), // تباعد داخلي أقل
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان
              Center(
                child: Text(
                  "إضافة فئة جديدة",
                  style: TextStyle(
                    fontSize: 16, // حجم خط أصغر
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
                spacing: 10, // تباعد أقل
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children:
                    _colors.map((color) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 30, // أصغر قليلاً
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

              // أزرار التحكم
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44, // ارتفاع ثابت للأزرار
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
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
                        onPressed: () => Navigator.of(context).pop(),
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
