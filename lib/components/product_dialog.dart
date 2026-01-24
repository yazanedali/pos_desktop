import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_desktop/database/category_queries.dart';
import 'package:pos_desktop/dialogs/quick_add_category_dialog.dart';
import 'package:pos_desktop/models/category.dart';
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/models/product_package.dart';
import 'package:pos_desktop/widgets/top_alert.dart';

class ProductDialog extends StatefulWidget {
  final Product? product;
  final List<Category> categories;
  final Function(Product) onSave;
  final Function() onCancel;
  final Function(List<Category>)? onCategoriesUpdate;

  const ProductDialog({
    super.key,
    this.product,
    required this.categories,
    required this.onSave,
    required this.onCancel,
    this.onCategoriesUpdate,
  });

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController; // <-- New controller
  late TextEditingController _barcodeController;
  late List<TextEditingController> _additionalBarcodeControllers;
  int? _selectedCategoryId;
  String? _selectedCategoryName;

  late List<ProductPackage> _packages;
  List<Category> _localCategories = [];

  @override
  void initState() {
    super.initState();
    final isEditing = widget.product != null;

    _nameController = TextEditingController(
      text: isEditing ? widget.product!.name : '',
    );
    _purchasePriceController = TextEditingController(
      text: isEditing ? widget.product!.purchasePrice.toString() : '',
    );
    _priceController = TextEditingController(
      text: isEditing ? widget.product!.price.toString() : '',
    );
    _stockController = TextEditingController(
      text: isEditing ? widget.product!.stock.toString() : '0.0',
    );
    final minStockValue =
        (isEditing && widget.product!.minStock > 0)
            ? widget.product!.minStock
            : 9.0;

    _minStockController = TextEditingController(text: minStockValue.toString());
    _barcodeController = TextEditingController(
      text: isEditing ? widget.product!.barcode : '',
    );

    _additionalBarcodeControllers = [];
    if (isEditing && widget.product!.additionalBarcodes.isNotEmpty) {
      for (var code in widget.product!.additionalBarcodes) {
        _additionalBarcodeControllers.add(TextEditingController(text: code));
      }
    }

    _localCategories = List<Category>.from(widget.categories);

    if (isEditing && widget.product!.categoryId != null) {
      final category = _localCategories.firstWhere(
        (c) => c.id == widget.product!.categoryId,
        orElse: () => Category(id: 0, name: 'غير معروف', color: '#000000'),
      );
      _selectedCategoryId = category.id;
      _selectedCategoryName = category.name;
    }

    _packages =
        isEditing
            ? List<ProductPackage>.from(
              widget.product!.packages.map(
                (p) => ProductPackage.fromMap(p.toMap()),
              ),
            )
            : [];

    // إضافة مستمعين لحساب الربح تلقائياً
    _purchasePriceController.addListener(_updateProfitDisplay);
    _priceController.addListener(_updateProfitDisplay);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _barcodeController.dispose();
    for (var c in _additionalBarcodeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateProfitDisplay() {
    setState(() {}); // تحديث الواجهة لعرض الربح
  }

  void _generateBarcode() {
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

  void _openQuickAddCategory() async {
    final newCategory = await showDialog<Category>(
      context: context,
      builder:
          (context) => QuickAddCategoryDialog(
            existingCategories: _localCategories,
            addToDatabase: true,
          ),
    );

    if (newCategory != null) {
      // 1. تحديث القائمة المحلية
      setState(() {
        _localCategories.add(newCategory);
      });

      // 2. اختيار الفئة الجديدة تلقائياً
      setState(() {
        _selectedCategoryId = newCategory.id;
        _selectedCategoryName = newCategory.name;
      });

      // 3. إعادة تحميل القائمة من قاعدة البيانات للتأكد
      await _refreshCategoriesFromDatabase();

      // 4. إعلام الوالد بالتحديث
      if (widget.onCategoriesUpdate != null) {
        widget.onCategoriesUpdate!(_localCategories);
      }

      TopAlert.showSuccess(
        context: context,
        message: "تمت إضافة الفئة '${newCategory.name}' بنجاح",
      );
    }
  }

  Future<void> _refreshCategoriesFromDatabase() async {
    try {
      final categoryQueries = CategoryQueries();
      final updatedCategories = await categoryQueries.getAllCategories();

      setState(() {
        _localCategories = updatedCategories;
      });
    } catch (e) {
      print('خطأ في تحديث قائمة الفئات: $e');
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategoryId == null) {
        TopAlert.showError(context: context, message: "يرجى اختيار فئة للمنتج");
        return;
      }

      final additionalBarcodes =
          _additionalBarcodeControllers
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();

      final product = Product(
        id: widget.product?.id,
        name: _nameController.text,
        purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0.0,
        price: double.tryParse(_priceController.text) ?? 0.0,
        stock: double.tryParse(_stockController.text) ?? 0.0,
        minStock: double.tryParse(_minStockController.text) ?? 0.0,
        barcode:
            _barcodeController.text.isEmpty ? null : _barcodeController.text,
        categoryId: _selectedCategoryId!,
        category: _selectedCategoryName,
        packages: _packages,
        additionalBarcodes: additionalBarcodes,
      );
      widget.onSave(product);
    }
  }

  // حساب الربح
  String _calculateProfit() {
    try {
      final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0;
      final salePrice = double.tryParse(_priceController.text) ?? 0;
      final profit = salePrice - purchasePrice;
      final percentage = purchasePrice > 0 ? (profit / purchasePrice) * 100 : 0;

      return '${profit.toStringAsFixed(2)} ش (${percentage.toStringAsFixed(1)}%)';
    } catch (e) {
      return '0.00 ش (0%)';
    }
  }

  // تحديد لون الربح
  Color _getProfitColor() {
    try {
      final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0;
      final salePrice = double.tryParse(_priceController.text) ?? 0;
      final profit = salePrice - purchasePrice;

      if (profit < 0) return Colors.red;
      if (profit == 0) return Colors.grey;
      if (profit < purchasePrice * 0.1) return Colors.orange;
      return Colors.green;
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
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
                      _buildBasicInfoSection(),
                      const Divider(height: 30, thickness: 1),
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

        // اسم المنتج
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

        // صف الأسعار (سعر الشراء - سعر البيع - الربح)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _purchasePriceController,
                decoration: const InputDecoration(
                  labelText: "سعر الشراء *",
                  prefixIcon: Icon(Icons.price_check),
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
                            ? "أدخل سعر شراء صحيح"
                            : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: "سعر البيع *",
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
                            ? "أدخل سعر بيع صحيح"
                            : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الربح',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _calculateProfit(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getProfitColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // الكمية بالمخزون
        TextFormField(
          controller: _stockController,
          decoration: const InputDecoration(
            labelText: "الكمية بالمخزون",
            prefixIcon: Icon(Icons.inventory_2_outlined),
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
          ],
        ),
        const SizedBox(height: 20),

        // الحد الأدنى للمخزون
        TextFormField(
          controller: _minStockController,
          decoration: const InputDecoration(
            labelText: "الحد الأدنى للمخزون (للتنبيهات)",
            prefixIcon: Icon(Icons.notifications_active_outlined),
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
          ],
        ),
        const SizedBox(height: 20),

        // باركود الوحدة الأساسية
        TextFormField(
          controller: _barcodeController,
          decoration: InputDecoration(
            labelText: "باركود الوحدة الأساسية (الرئيسي)",
            prefixIcon: const Icon(Icons.qr_code_2_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _generateBarcode,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // باركودات إضافية
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "باركودات إضافية (للنكهات المتعددة أو الألوان)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _additionalBarcodeControllers.add(
                          TextEditingController(),
                        );
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("إضافة باركود"),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_additionalBarcodeControllers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'لا توجد باركودات بديلة، اضغط "إضافة باركود" لإضافة واحد.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _additionalBarcodeControllers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _additionalBarcodeControllers[index],
                              decoration: InputDecoration(
                                labelText: 'باركود بديل ${index + 1}',
                                prefixIcon: const Icon(Icons.qr_code, size: 20),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                final controller = _additionalBarcodeControllers
                                    .removeAt(index);
                                controller.dispose();
                              });
                            },
                            tooltip: "حذف هذا الباركود",
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // اختيار الفئة
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "اختر فئة المنتج *",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _openQuickAddCategory,
                      icon: const Icon(Icons.add_circle_outline, size: 14),
                      label: const Text("فئة جديدة"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_localCategories.isNotEmpty)
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: "الفئة *",
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) => value == null ? "يرجى اختيار فئة" : null,
                items:
                    _localCategories
                        .where((category) => category.id != null)
                        .toSet()
                        .toList()
                        .map((category) {
                          return DropdownMenuItem<int>(
                            value: category.id,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
                                  Flexible(
                                    child: Text(
                                      category.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    final selectedCategory = _localCategories.firstWhere(
                      (c) => c.id == value,
                    );
                    setState(() {
                      _selectedCategoryId = value;
                      _selectedCategoryName = selectedCategory.name;
                    });
                  }
                },
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: const Text(
                  "لا توجد فئات متاحة. يرجى إضافة فئة جديدة.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ],
    );
  }

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
