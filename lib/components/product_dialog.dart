import 'package:flutter/material.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';

class ProductDialog extends StatefulWidget {
  final Product? product;
  final List<Category> categories;
  final Function(Product) onSave;
  final Function() onCancel;

  const ProductDialog({
    super.key,
    this.product,
    required this.categories,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _barcodeController;

  // سنقوم بتخزين ID واسم الفئة لضمان الدقة
  int? _selectedCategoryId;
  String? _selectedCategoryName;

  @override
  void initState() {
    super.initState();
    // تهيئة الـ Controllers بالبيانات الحالية في حالة التعديل
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
    _stockController = TextEditingController(
      text: widget.product?.stock.toString() ?? '0',
    );
    _barcodeController = TextEditingController(
      text: widget.product?.barcode ?? '',
    );

    // ربط الفئة بالـ ID لضمان عدم حدوث أخطاء عند وجود أسماء مكررة
    if (widget.product?.categoryId != null &&
        widget.categories.any((c) => c.id == widget.product!.categoryId)) {
      final category = widget.categories.firstWhere(
        (c) => c.id == widget.product!.categoryId,
      );
      _selectedCategoryId = category.id;
      _selectedCategoryName = category.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _generateBarcode() {
    // استخدام باركود كامل لضمان عدم التكرار
    final barcode = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _barcodeController.text = barcode;
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final product = Product(
        id: widget.product?.id,
        name: _nameController.text,
        price: double.tryParse(_priceController.text) ?? 0.0,
        stock: int.tryParse(_stockController.text) ?? 0,
        barcode:
            _barcodeController.text.isEmpty ? null : _barcodeController.text,
        categoryId: _selectedCategoryId!, // الفئة مطلوبة
        category: _selectedCategoryName, // الاسم لتسهيل العرض
      );
      widget.onSave(product);
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: const EdgeInsets.all(20), // هامش خارجي
      child: Container(
        width: screenWidth * 0.4, // 40% من عرض الشاشة
        height: screenHeight * 0.6, // 60% من ارتفاع الشاشة
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ---- العنوان ----
            Text(
              widget.product == null ? "إضافة منتج جديد" : "تعديل المنتج",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // ---- المحتوى ----
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // --- حقل اسم المنتج ---
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: "اسم المنتج *",
                          prefixIcon: Icon(Icons.label_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (value) =>
                                (value == null || value.isEmpty)
                                    ? "يرجى إدخال اسم المنتج"
                                    : null,
                      ),
                      const SizedBox(height: 20),

                      // --- السعر والمخزون ---
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: "السعر *",
                                prefixIcon: Icon(Icons.attach_money),
                                border: OutlineInputBorder(),
                                suffixText: "شيكل",
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "أدخل السعر";
                                }
                                if (double.tryParse(value) == null) {
                                  return "رقم غير صحيح";
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              decoration: const InputDecoration(
                                labelText: "المخزون",
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // --- الباركود ---
                      TextFormField(
                        controller: _barcodeController,
                        decoration: InputDecoration(
                          labelText: "الباركود",
                          prefixIcon: const Icon(Icons.qr_code_2_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.sync),
                            tooltip: "إنشاء باركود عشوائي",
                            onPressed: _generateBarcode,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- الفئة ---
                      DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: "الفئة *",
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (value) => value == null ? "يرجى اختيار فئة" : null,
                        items:
                            widget.categories.map((category) {
                              return DropdownMenuItem(
                                value: category.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: _hexToColor(category.color),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(category.name),
                                  ],
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategoryId = value;
                              _selectedCategoryName =
                                  widget.categories
                                      .firstWhere((c) => c.id == value)
                                      .name;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ---- الأزرار ----
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text("إلغاء"),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  child: Text(
                    widget.product == null ? "إضافة المنتج" : "حفظ التعديلات",
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
