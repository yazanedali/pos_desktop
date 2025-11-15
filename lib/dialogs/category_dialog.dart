import 'package:flutter/material.dart';
import '../../../models/category.dart';

class CategoryDialog extends StatefulWidget {
  final Category? category; // لتمرير الفئة في حالة التعديل
  final Function(String name, String color) onSave;

  const CategoryDialog({super.key, this.category, required this.onSave});

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedColor;

  final List<String> _availableColors = [
    '#3B82F6',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#8B5CF6',
    '#EC4899',
    '#6B7280',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.color ?? _availableColors.first;
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'إضافة فئة جديدة' : 'تعديل الفئة'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الفئة',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال اسم الفئة';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'اختر لونًا للفئة:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  _availableColors.map((color) {
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _hexToColor(color),
                          shape: BoxShape.circle,
                          border:
                              _selectedColor == color
                                  ? Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 3,
                                  )
                                  : null,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave(_nameController.text, _selectedColor);
              Navigator.of(context).pop();
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
