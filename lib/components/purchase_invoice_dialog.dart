import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/product_queries.dart';
import '../models/category.dart';
import '../models/purchase_invoice.dart';
import '../models/product.dart';
import '../models/supplier.dart'; // <-- Added
import '../database/supplier_queries.dart'; // <-- Added
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
  late TextEditingController _dateController;
  List<PurchaseInvoiceItem> _invoiceItems = [];
  bool get _isEditMode => widget.invoiceToEdit != null;
  late String _generatedInvoiceNumber;

  final ProductQueries _productQueries = ProductQueries();
  // Supplier & Payment Logic
  final SupplierQueries _supplierQueries = SupplierQueries();
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  String _paymentStatus = 'مدفوع'; // مدفوع، جزئي، غير مدفوع
  double _paidAmount = 0.0;
  final TextEditingController _paidAmountController = TextEditingController();

  final List<TextEditingController> _productNameControllers = [];
  final List<TextEditingController> _barcodeControllers = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _purchasePriceControllers = [];
  final List<TextEditingController> _salePriceControllers = [];

  late TextEditingController _searchController;
  List<Product> _products = [];
  bool _isLoadingProducts = false;
  String _searchFilter = 'الكل';
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController();
    _searchController = TextEditingController();
    _loadSuppliers();

    if (_isEditMode) {
      final invoice = widget.invoiceToEdit!;
      _generatedInvoiceNumber = invoice.invoiceNumber;
      _dateController.text = invoice.date;
      _invoiceItems = List<PurchaseInvoiceItem>.from(invoice.items);
      _paymentStatus = invoice.paymentStatus;
      _paidAmount = invoice.paidAmount;
      _paidAmountController.text = _paidAmount.toString();
      // Note: Supplier selection logic will run after `_loadSuppliers`
    } else {
      _generatedInvoiceNumber =
          'INV-${const Uuid().v4().substring(0, 8).toUpperCase()}';
      _dateController.text = _getTodayDate();
      _paidAmountController.text = '0';
    }
    _initializeControllers();
    _loadProducts();
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await _supplierQueries.getAllSuppliers();
    setState(() {
      _suppliers = suppliers;
      if (_isEditMode && widget.invoiceToEdit?.supplierId != null) {
        try {
          _selectedSupplier = _suppliers.firstWhere(
            (s) => s.id == widget.invoiceToEdit!.supplierId,
          );
        } catch (_) {}
      }
    });
  }

  final _formKey = GlobalKey<FormState>();

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    final products = await ProductQueries().getAllProducts();
    setState(() {
      _products = products;
      _isLoadingProducts = false;
    });
  }

  void _searchProducts() {
    if (_searchTerm.isEmpty) {
      _loadProducts();
      return;
    }

    setState(() {
      _products =
          _products.where((product) {
            final term = _searchTerm.toLowerCase();
            final nameMatch = product.name.toLowerCase().contains(term);
            final barcodeMatch =
                product.barcode?.toLowerCase().contains(term) ?? false;

            if (_searchFilter == 'الاسم') return nameMatch;
            if (_searchFilter == 'الباركود') return barcodeMatch;
            if (_searchFilter == 'الفئة') {
              final categoryName =
                  widget.categories
                      .firstWhere(
                        (c) => c.id == product.categoryId,
                        orElse: () => Category(id: 0, name: '', color: ''),
                      )
                      .name
                      .toLowerCase();
              return categoryName.contains(term);
            }
            return nameMatch || barcodeMatch;
          }).toList();
    });
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
  }

  void _initializeControllers() {
    // Initialize controllers for existing items when editing
    for (var item in _invoiceItems) {
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
    _dateController.dispose();
    _searchController.dispose();
    _paidAmountController.dispose();
    for (var controller in _quantityControllers) controller.dispose();
    for (var controller in _purchasePriceControllers) controller.dispose();
    for (var controller in _salePriceControllers) controller.dispose();
    super.dispose();
  }

  void _addProductToInvoice(Product product) {
    if (_invoiceItems.any((item) => item.productName == product.name)) {
      TopAlert.showError(
        context: context,
        message: 'المنتج موجود بالفعل في الفاتورة',
      );
      return;
    }

    setState(() {
      final newItem = PurchaseInvoiceItem(
        id: null,
        // invoiceId parameter removed
        productName: product.name,
        barcode: product.barcode ?? '',
        quantity: 1,
        purchasePrice: product.purchasePrice,
        salePrice: product.price,
        total: product.purchasePrice,
        category:
            widget.categories
                .firstWhere(
                  (c) => c.id == product.categoryId,
                  orElse: () => Category(id: 0, name: '', color: ''),
                )
                .name,
      );
      _invoiceItems.add(newItem);

      _quantityControllers.add(TextEditingController(text: "1"));
      _purchasePriceControllers.add(
        TextEditingController(text: product.purchasePrice.toString()),
      );
      _salePriceControllers.add(
        TextEditingController(text: product.price.toString()),
      );
    });
  }

  void _removeInvoiceItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
      _quantityControllers[index].dispose();
      _purchasePriceControllers[index].dispose();
      _salePriceControllers[index].dispose();

      _quantityControllers.removeAt(index);
      _purchasePriceControllers.removeAt(index);
      _salePriceControllers.removeAt(index);
    });
  }

  void _updateInvoiceItem(int index, String field, double value) {
    setState(() {
      final item = _invoiceItems[index];
      PurchaseInvoiceItem newItem;

      switch (field) {
        case 'quantity':
          newItem = item.copyWith(
            quantity: value,
            total: value * item.purchasePrice,
          );
          break;
        case 'purchasePrice':
          newItem = item.copyWith(
            purchasePrice: value,
            total: item.quantity * value,
          );
          break;
        case 'salePrice':
          newItem = item.copyWith(salePrice: value);
          break;
        default:
          return;
      }
      _invoiceItems[index] = newItem;
    });
  }

  Future<void> _openAddProductDialog() async {
    await showDialog(
      context: context,
      builder:
          (context) => ProductDialog(
            categories: widget.categories,
            onSave: (product) async {
              // 1️⃣ حفظ المنتج في جدول المنتجات
              final savedProduct = await _productQueries.createProduct(product);

              // 2️⃣ إعادة تحميل المنتجات
              await _loadProducts();

              // 3️⃣ إضافة المنتج للفاتورة
              _addProductToInvoice(savedProduct);

              // 4️⃣ إغلاق نافذة المنتج
              Navigator.pop(context);

              if (widget.onProductAdded != null) {
                widget.onProductAdded!();
              }
            },

            onCancel: () => Navigator.pop(context),
          ),
    );
  }

  double _calculateTotal() =>
      _invoiceItems.fold(0, (total, item) => total + item.total);

  void _submitForm() {
    if (_selectedSupplier == null) {
      TopAlert.showError(context: context, message: 'يرجى اختيار المورد');
      return;
    }

    if (_invoiceItems.isEmpty) {
      TopAlert.showError(
        context: context,
        message: 'يرجى إضافة منتجات إلى الفاتورة',
      );
      return;
    }

    final total = _calculateTotal();
    double paid = 0.0;
    double remaining = 0.0;

    if (_paymentStatus == 'مدفوع') {
      paid = total;
      remaining = 0;
    } else if (_paymentStatus == 'غير مدفوع') {
      paid = 0;
      remaining = total;
    } else {
      // جزئي
      paid = double.tryParse(_paidAmountController.text) ?? 0.0;
      if (paid > total) {
        TopAlert.showError(
          context: context,
          message: 'المبلغ المدفوع أكبر من الإجمالي',
        );
        return;
      }
      remaining = total - paid;
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
      supplier: _selectedSupplier!.name,
      supplierId: _selectedSupplier!.id,
      date: _dateController.text,
      time: _isEditMode ? widget.invoiceToEdit!.time : _getCurrentTime(),
      items: validItems,
      total: total,
      paymentStatus: _paymentStatus,
      paymentType: _paymentStatus == 'غير مدفوع' ? 'آجل' : 'نقدي', // تبسيط
      paidAmount: paid,
      remainingAmount: remaining,
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
                    child: DropdownButtonFormField<Supplier>(
                      value: _selectedSupplier,
                      decoration: const InputDecoration(
                        labelText: "المورد *",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business_center_outlined),
                      ),
                      items:
                          _suppliers.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s.name),
                            );
                          }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedSupplier = val);
                      },
                      validator: (val) => val == null ? "مطلوب" : null,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _paymentStatus,
                      decoration: const InputDecoration(
                        labelText: "حالة الدفع",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'مدفوع',
                          child: Text("مدفوع كامل"),
                        ),
                        DropdownMenuItem(
                          value: 'جزئي',
                          child: Text("مدفوع جزئي"),
                        ),
                        DropdownMenuItem(
                          value: 'غير مدفوع',
                          child: Text("آجل (دين)"),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _paymentStatus = val!;
                        });
                      },
                    ),
                  ),
                  if (_paymentStatus == 'جزئي') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _paidAmountController,
                        decoration: const InputDecoration(
                          labelText: "المبلغ المدفوع",
                          border: OutlineInputBorder(),
                          suffixText: "شيكل",
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
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
