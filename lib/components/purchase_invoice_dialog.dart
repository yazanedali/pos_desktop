import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/product_queries.dart';
import '../models/category.dart';
import '../models/purchase_invoice.dart';
import '../models/product.dart';
import '../widgets/top_alert.dart';
import './product_dialog.dart'; // ← استيراد نافذة المنتج

class PurchaseInvoiceDialog extends StatefulWidget {
  final List<Category> categories;
  final Function(PurchaseInvoice) onSave;
  final Function() onCancel;
  final PurchaseInvoice? invoiceToEdit;
  final Function()? onProductAdded; // ← دالة استدعاء عند إضافة منتج جديد

  const PurchaseInvoiceDialog({
    Key? key,
    required this.categories,
    required this.onSave,
    required this.onCancel,
    this.invoiceToEdit,
    this.onProductAdded,
  }) : super(key: key);

  @override
  State<PurchaseInvoiceDialog> createState() => _PurchaseInvoiceDialogState();
}

class _PurchaseInvoiceDialogState extends State<PurchaseInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _supplierController;
  late TextEditingController _dateController;
  List<PurchaseInvoiceItem> _invoiceItems = [];
  bool get _isEditMode => widget.invoiceToEdit != null;
  late String _generatedInvoiceNumber;

  final List<TextEditingController> _productNameControllers = [];
  final List<TextEditingController> _barcodeControllers = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _purchasePriceControllers = [];
  final List<TextEditingController> _salePriceControllers = [];

  late TextEditingController _searchController;
  List<Product> _products = [];
  bool _isLoadingProducts = false;
  String _searchFilter = 'الكل'; // 'الكل'، 'الاسم'، 'الباركود'، 'الفئة'
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _supplierController = TextEditingController();
    _dateController = TextEditingController();
    _searchController = TextEditingController();

    if (_isEditMode) {
      final invoice = widget.invoiceToEdit!;
      _generatedInvoiceNumber = invoice.invoiceNumber;
      _supplierController.text = invoice.supplier;
      _dateController.text = invoice.date;
      _invoiceItems = List<PurchaseInvoiceItem>.from(invoice.items);
    } else {
      _generatedInvoiceNumber =
          'INV-${const Uuid().v4().substring(0, 8).toUpperCase()}';
      _dateController.text = _getTodayDate();
    }
    _initializeControllers();

    _loadProducts();
  }

  Future<void> _loadProducts({String searchTerm = ''}) async {
    setState(() => _isLoadingProducts = true);

    try {
      final products = await ProductQueries().getProductsForPurchase(
        searchTerm: searchTerm.isEmpty ? null : searchTerm,
      );
      setState(() => _products = products);
    } catch (e) {
      TopAlert.showError(context: context, message: 'خطأ في جلب المنتجات: $e');
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  void _searchProducts() {
    if (_searchTerm.isEmpty) {
      _loadProducts();
      return;
    }

    setState(() => _isLoadingProducts = true);

    switch (_searchFilter) {
      case 'الكل':
        _loadProducts(searchTerm: _searchTerm);
        break;
      case 'الاسم':
        _searchProductsByName();
        break;
      case 'الباركود':
        _searchProductsByBarcode();
        break;
      case 'الفئة':
        _searchProductsByCategory();
        break;
    }
  }

  Future<void> _searchProductsByName() async {
    try {
      final allProducts = await ProductQueries().getAllProducts();
      final filteredProducts =
          allProducts
              .where(
                (product) => product.name.toLowerCase().contains(
                  _searchTerm.toLowerCase(),
                ),
              )
              .toList();
      setState(() => _products = filteredProducts);
    } catch (e) {
      TopAlert.showError(context: context, message: 'خطأ في البحث: $e');
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _searchProductsByBarcode() async {
    try {
      final product = await ProductQueries().getProductByBarcode(_searchTerm);
      setState(() => _products = product != null ? [product] : []);
    } catch (e) {
      TopAlert.showError(context: context, message: 'خطأ في البحث: $e');
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _searchProductsByCategory() async {
    try {
      final allProducts = await ProductQueries().getAllProducts();
      final filteredProducts =
          allProducts
              .where(
                (product) => widget.categories
                    .firstWhere(
                      (c) => c.id == product.categoryId,
                      orElse: () => Category(id: 0, name: '', color: ''),
                    )
                    .name
                    .toLowerCase()
                    .contains(_searchTerm.toLowerCase()),
              )
              .toList();
      setState(() => _products = filteredProducts);
    } catch (e) {
      TopAlert.showError(context: context, message: 'خطأ في البحث: $e');
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  void _initializeControllers() {
    _disposeItemControllers();
    for (final item in _invoiceItems) {
      _productNameControllers.add(
        TextEditingController(text: item.productName),
      );
      _barcodeControllers.add(TextEditingController(text: item.barcode));
      _quantityControllers.add(
        TextEditingController(text: item.quantity.toString()),
      );
      _purchasePriceControllers.add(
        TextEditingController(text: item.purchasePrice.toString()),
      );
      _salePriceControllers.add(
        TextEditingController(text: item.salePrice.toString()),
      );
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _dateController.dispose();
    _searchController.dispose();
    _disposeItemControllers();
    super.dispose();
  }

  void _disposeItemControllers() {
    for (var c in _productNameControllers) c.dispose();
    for (var c in _barcodeControllers) c.dispose();
    for (var c in _quantityControllers) c.dispose();
    for (var c in _purchasePriceControllers) c.dispose();
    for (var c in _salePriceControllers) c.dispose();
    _productNameControllers.clear();
    _barcodeControllers.clear();
    _quantityControllers.clear();
    _purchasePriceControllers.clear();
    _salePriceControllers.clear();
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _addProductToInvoice(Product product) {
    final existingIndex = _invoiceItems.indexWhere(
      (item) =>
          item.productName == product.name ||
          (item.barcode.isNotEmpty && item.barcode == product.barcode),
    );

    if (existingIndex != -1) {
      setState(() {
        final existingItem = _invoiceItems[existingIndex];
        _invoiceItems[existingIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + 1,
        );
        _quantityControllers[existingIndex].text =
            _invoiceItems[existingIndex].quantity.toString();
      });
      TopAlert.showSuccess(
        context: context,
        message: 'تم زيادة كمية المنتج ${product.name}',
      );
    } else {
      final category = widget.categories.firstWhere(
        (c) => c.id == product.categoryId,
        orElse: () => Category(id: 0, name: 'غير معروف', color: '#000000'),
      );

      setState(() {
        _invoiceItems.add(
          PurchaseInvoiceItem(
            productName: product.name,
            barcode: product.barcode ?? '',
            quantity: 1.0,
            purchasePrice: product.price,
            salePrice: product.price,
            category: category.name,
            total: product.price,
          ),
        );
        _productNameControllers.add(TextEditingController(text: product.name));
        _barcodeControllers.add(
          TextEditingController(text: product.barcode ?? ''),
        );
        _quantityControllers.add(TextEditingController(text: '1'));
        _purchasePriceControllers.add(
          TextEditingController(text: product.price.toString()),
        );
        _salePriceControllers.add(
          TextEditingController(text: product.price.toString()),
        );
      });
    }
  }

  void _removeInvoiceItem(int index) {
    setState(() {
      _productNameControllers[index].dispose();
      _barcodeControllers[index].dispose();
      _quantityControllers[index].dispose();
      _purchasePriceControllers[index].dispose();
      _salePriceControllers[index].dispose();

      _invoiceItems.removeAt(index);
      _productNameControllers.removeAt(index);
      _barcodeControllers.removeAt(index);
      _quantityControllers.removeAt(index);
      _purchasePriceControllers.removeAt(index);
      _salePriceControllers.removeAt(index);
    });
  }

  void _updateInvoiceItem(int index, String field, dynamic value) {
    setState(() {
      final item = _invoiceItems[index];
      final updatedItem = item.copyWith(
        productName: field == 'productName' ? value : item.productName,
        barcode: field == 'barcode' ? value : item.barcode,
        quantity: field == 'quantity' ? value : item.quantity,
        purchasePrice: field == 'purchasePrice' ? value : item.purchasePrice,
        salePrice: field == 'salePrice' ? value : item.salePrice,
        category: field == 'category' ? value : item.category,
      );
      _invoiceItems[index] = updatedItem.copyWith(
        total: updatedItem.quantity * updatedItem.purchasePrice,
      );
    });
  }

  // دالة لفتح نافذة إضافة منتج جديد
  void _openAddProductDialog() async {
    final newProduct = await showDialog<Product>(
      context: context,
      builder:
          (context) => ProductDialog(
            categories: widget.categories,
            onSave: (product) {
              Navigator.of(context).pop(product); // إرجاع المنتج الجديد
            },
            onCancel: () {
              Navigator.of(context).pop(); // إغلاق بدون إرجاع
            },
          ),
    );

    if (newProduct != null) {
      // إضافة المنتج الجديد إلى الفاتورة تلقائياً
      _addProductToInvoice(newProduct);

      // إعادة تحميل قائمة المنتجات لتظهر المنتج الجديد
      await _loadProducts();

      // إظهار رسالة نجاح
      TopAlert.showSuccess(
        context: context,
        message: 'تم إضافة المنتج "${newProduct.name}" بنجاح وإضافته للفاتورة',
      );
    }
  }

  double _calculateTotal() =>
      _invoiceItems.fold(0, (total, item) => total + item.total);

  void _submitForm() {
    if (_supplierController.text.isEmpty) {
      TopAlert.showError(context: context, message: 'يرجى إدخال اسم المورد');
      return;
    }

    if (_invoiceItems.isEmpty) {
      TopAlert.showError(
        context: context,
        message: 'يرجى إضافة منتجات إلى الفاتورة',
      );
      return;
    }

    final validItems =
        _invoiceItems.where((item) {
          final hasName = item.productName.trim().isNotEmpty;
          final hasQuantity = item.quantity > 0;
          final hasPrice = item.purchasePrice > 0;
          return hasName && hasQuantity && hasPrice;
        }).toList();

    if (validItems.isEmpty) {
      TopAlert.showError(
        context: context,
        message:
            'يرجى التأكد من:\n- اسم المنتج\n- كمية أكبر من صفر\n- سعر شراء أكبر من صفر',
      );
      return;
    }

    final invoice = PurchaseInvoice(
      id: widget.invoiceToEdit?.id,
      invoiceNumber: _generatedInvoiceNumber,
      supplier: _supplierController.text,
      date: _dateController.text,
      time: _isEditMode ? widget.invoiceToEdit!.time : _getCurrentTime(),
      items: validItems,
      total: _calculateTotal(),
    );

    widget.onSave(invoice);
  }

  Widget _buildProductsList() {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          // شريط البحث والفلترة
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // حقل البحث
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'بحث عن منتج',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _searchTerm.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchTerm = '');
                                      _loadProducts();
                                    },
                                  )
                                  : null,
                        ),
                        onChanged: (value) {
                          setState(() => _searchTerm = value);
                          if (value.length >= 2 || value.isEmpty) {
                            _searchProducts();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // فلاتر البحث وزر إضافة منتج
                Row(
                  children: [
                    const Text('بحث في: ', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    _buildFilterChip('الكل', _searchFilter == 'الكل'),
                    _buildFilterChip('الاسم', _searchFilter == 'الاسم'),
                    _buildFilterChip('الباركود', _searchFilter == 'الباركود'),
                    _buildFilterChip('الفئة', _searchFilter == 'الفئة'),
                    const Spacer(),
                    // زر إضافة منتج جديد
                    ElevatedButton.icon(
                      onPressed: _openAddProductDialog,
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('إضافة منتج جديد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // قائمة المنتجات
          Expanded(
            child:
                _isLoadingProducts
                    ? const Center(child: CircularProgressIndicator())
                    : _products.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text('لا توجد منتجات مسجلة'),
                          SizedBox(height: 4),
                          Text(
                            'اضغط على زر "إضافة منتج جديد" لإنشاء منتجات',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final category = widget.categories.firstWhere(
                          (c) => c.id == product.categoryId,
                          orElse:
                              () => Category(
                                id: 0,
                                name: 'غير معروف',
                                color: '#000000',
                              ),
                        );

                        return ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(product.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('السعر: ${product.price} ش'),
                              Text('الكمية: ${product.stock}'),
                              Text('الفئة: ${category.name}'),
                              if (product.barcode != null &&
                                  product.barcode!.isNotEmpty)
                                Text('الباركود: ${product.barcode}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => _addProductToInvoice(product),
                            color: Colors.blue,
                          ),
                          onTap: () => _addProductToInvoice(product),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
        selected: selected,
        onSelected: (bool value) {
          setState(() => _searchFilter = label);
          if (_searchTerm.isNotEmpty) {
            _searchProducts();
          }
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.blue,
        checkmarkColor: Colors.white,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildInvoiceItemsSection() {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "منتجات الفاتورة (${_invoiceItems.length})",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${_calculateTotal().toStringAsFixed(2)} شيكل",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                _invoiceItems.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text('لا توجد منتجات في الفاتورة'),
                          SizedBox(height: 4),
                          Text(
                            'اختر منتجات من القائمة اليسرى',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _invoiceItems.length,
                      itemBuilder:
                          (context, index) => _buildInvoiceItemCard(index),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItemCard(int index) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _invoiceItems[index].productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => _removeInvoiceItem(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'إزالة المنتج',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الباركود: ${_invoiceItems[index].barcode.isNotEmpty ? _invoiceItems[index].barcode : "غير متوفر"}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Text(
                      'الفئة: ${_invoiceItems[index].category}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityControllers[index],
                        decoration: const InputDecoration(
                          labelText: "الكمية",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged:
                            (v) => _updateInvoiceItem(
                              index,
                              'quantity',
                              double.tryParse(v) ?? 1.0,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceControllers[index],
                        decoration: const InputDecoration(
                          labelText: "سعر الشراء",
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixText: 'ش ',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged:
                            (v) => _updateInvoiceItem(
                              index,
                              'purchasePrice',
                              double.tryParse(v) ?? 0.0,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _salePriceControllers[index],
                        decoration: const InputDecoration(
                          labelText: "سعر البيع",
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixText: 'ش ',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged:
                            (v) => _updateInvoiceItem(
                              index,
                              'salePrice',
                              double.tryParse(v) ?? 0.0,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "المجموع: ",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      "${_invoiceItems[index].total.toStringAsFixed(2)} شيكل",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.of(context).size.width * 0.9;
    final dialogHeight = MediaQuery.of(context).size.height * 0.9;

    return AlertDialog(
      title: Text(
        _isEditMode ? "تعديل فاتورة شراء" : "إضافة فاتورة شراء جديدة",
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "رقم الفاتورة",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt_long),
                      ),
                      child: Text(
                        _generatedInvoiceNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _supplierController,
                      decoration: const InputDecoration(
                        labelText: "المورد *",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business_center_outlined),
                      ),
                      validator:
                          (v) =>
                              (v == null || v.isEmpty)
                                  ? "يرجى إدخال اسم المورد"
                                  : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: "تاريخ الفاتورة *",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          _dateController.text =
                              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildProductsList()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInvoiceItemsSection()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text("إلغاء")),
        ElevatedButton(
          onPressed: _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text(_isEditMode ? "حفظ التعديلات" : "حفظ الفاتورة"),
        ),
      ],
    );
  }
}
