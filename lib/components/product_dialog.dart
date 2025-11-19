// components/product_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_desktop/models/category.dart';
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/models/product_package.dart';

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
  int? _selectedCategoryId;
  String? _selectedCategoryName;

  //   ***** 1. متغير جديد لإدارة قائمة الحزم *****
  late List<ProductPackage> _packages;

  @override
  void initState() {
    super.initState();
    final isEditing = widget.product != null;

    _nameController = TextEditingController(
      text: isEditing ? widget.product!.name : '',
    );
    _priceController = TextEditingController(
      text: isEditing ? widget.product!.price.toString() : '',
    );
    _stockController = TextEditingController(
      text: isEditing ? widget.product!.stock.toString() : '0.0',
    );
    _barcodeController = TextEditingController(
      text: isEditing ? widget.product!.barcode : '',
    );

    if (isEditing && widget.product!.categoryId != null) {
      final category = widget.categories.firstWhere(
        (c) => c.id == widget.product!.categoryId,
      );
      _selectedCategoryId = category.id;
      _selectedCategoryName = category.name;
    }

    // نسخ قائمة الحزم إلى متغير محلي لتمكين التعديل عليها
    _packages =
        isEditing
            ? List<ProductPackage>.from(
              widget.product!.packages.map(
                (p) => ProductPackage.fromMap(p.toMap()),
              ),
            )
            : [];
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

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  // ... (dispose, _generateBarcode, _hexToColor - تبقى كما هي)

  //   ***** 2. دوال جديدة لإدارة الحزم *****
  void _addNewPackage() {
    setState(() {
      _packages.add(
        ProductPackage(name: '', containedQuantity: 0.0, price: 0.0),
      );
    });
  }

  void _removePackage(int index) {
    setState(() {
      _packages.removeAt(index);
    });
  }

  //   ***** 3. تحديث دالة الحفظ *****
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final product = Product(
        id: widget.product?.id,
        name: _nameController.text,
        price: double.tryParse(_priceController.text) ?? 0.0,
        stock: double.tryParse(_stockController.text) ?? 0.0, // <-- يدعم double
        barcode:
            _barcodeController.text.isEmpty ? null : _barcodeController.text,
        categoryId: _selectedCategoryId!,
        category: _selectedCategoryName,
        packages: _packages, // <-- إضافة الحزم
      );
      widget.onSave(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width:
            MediaQuery.of(context).size.width *
            0.6, // زيادة العرض لاستيعاب الحزم
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              widget.product?.id == null ? "إضافة منتج جديد" : "تعديل المنتج",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // --- الجزء العلوي (بيانات المنتج الأساسية) ---
                      _buildBasicInfoSection(),
                      const Divider(height: 30, thickness: 1),
                      //   ***** 4. قسم جديد لإدارة الحزم *****
                      _buildPackagesSection(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ودجت لبيانات المنتج الأساسية (لتنظيم الكود)
  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "المعلومات الأساسية",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const Text(
          "هنا يتم تعريف أصغر وحدة للمنتج (مثل: حبة واحدة، 1 كجم، 1 لتر).",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
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
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: "سعر الوحدة الأساسية *",
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                  suffixText: "شيكل",
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
                ],
                validator:
                    (v) =>
                        (v == null || v.isEmpty || double.tryParse(v) == null)
                            ? "أدخل سعر صحيح"
                            : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: "الكمية بالمخزون (بالوحدة الأساسية)",
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _barcodeController,
          decoration: InputDecoration(
            labelText: "باركود الوحدة الأساسية",
            prefixIcon: const Icon(Icons.qr_code_2_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _generateBarcode,
            ),
          ),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<int>(
          value: _selectedCategoryId,
          decoration: const InputDecoration(
            labelText: "الفئة *",
            prefixIcon: Icon(Icons.category_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (value) => value == null ? "يرجى اختيار فئة" : null,
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
                    widget.categories.firstWhere((c) => c.id == value).name;
              });
            }
          },
        ),
      ],
    );
  }

  //   ***** 5. ودجت جديد ومستقل لإدارة الحزم *****
  Widget _buildPackagesSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "وحدات البيع الإضافية (الحزم)",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  "عرّف الوحدات الأكبر (مثل: كيس، كرتونة) وسعرها.",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _addNewPackage,
              icon: const Icon(Icons.add),
              label: const Text("إضافة وحدة"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_packages.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("لا توجد حزم إضافية لهذا المنتج."),
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _packages.length,
          itemBuilder: (context, index) {
            return _buildPackageRow(_packages[index], index);
          },
        ),
      ],
    );
  }

  // ودجت لعرض حقول الحزمة الواحدة
  Widget _buildPackageRow(ProductPackage package, int index) {
    return Card(
      color: Colors.blue.shade50,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: package.name,
                decoration: const InputDecoration(
                  labelText: 'اسم الوحدة *',
                  hintText: 'كرتونة',
                ),
                onChanged: (v) => package.name = v,
                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue:
                    package.containedQuantity > 0
                        ? package.containedQuantity.toString()
                        : '',
                decoration: const InputDecoration(
                  labelText: 'تحتوي على *',
                  hintText: '12',
                  suffixText: "وحدة أساسية",
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
                ],
                onChanged:
                    (v) => package.containedQuantity = double.tryParse(v) ?? 0,
                validator:
                    (v) =>
                        (v == null ||
                                v.isEmpty ||
                                (double.tryParse(v) ?? 0) <= 0)
                            ? 'غير صحيح'
                            : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: package.price > 0 ? package.price.toString() : '',
                decoration: const InputDecoration(
                  labelText: 'سعر بيعها *',
                  hintText: '25.0',
                  suffixText: "شيكل",
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
                ],
                onChanged: (v) => package.price = double.tryParse(v) ?? 0,
                validator:
                    (v) =>
                        (v == null ||
                                v.isEmpty ||
                                (double.tryParse(v) ?? 0) <= 0)
                            ? 'غير صحيح'
                            : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _removePackage(index),
              tooltip: "حذف الوحدة",
            ),
          ],
        ),
      ),
    );
  }

  // ودجت لأزرار الحفظ والإلغاء (لتنظيم الكود)
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: widget.onCancel, child: const Text("إلغاء")),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _submitForm,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          ),
          child: Text(
            widget.product?.id == null ? "إضافة المنتج" : "حفظ التعديلات",
          ),
        ),
      ],
    );
  }
}
