import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/product_queries.dart';
import '../models/category.dart';
import '../models/purchase_invoice.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../database/supplier_queries.dart';
import '../widgets/top_alert.dart';
import './product_dialog.dart';

class PurchaseInvoiceDialog extends StatefulWidget {
  final List<Category> categories;
  final Function(PurchaseInvoice, String, String) onSave;
  final Function() onCancel;
  final PurchaseInvoice? invoiceToEdit;
  final Function()? onProductAdded;

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
  // Controllers
  late TextEditingController _dateController;
  late TextEditingController _searchController;
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _globalDiscountController = TextEditingController(
    text: '0',
  );

  // Lists of Controllers for Items
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _purchasePriceControllers = [];
  final List<TextEditingController> _salePriceControllers = [];
  final List<TextEditingController> _itemDiscountControllers = [];

  // Data
  List<PurchaseInvoiceItem> _invoiceItems = [];
  List<Product> _products = [];
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;

  // State Variables
  bool get _isEditMode => widget.invoiceToEdit != null;
  late String _generatedInvoiceNumber;
  String _purchasePriceUpdateMethod = 'جديد';
  String _paymentStatus = 'مدفوع';
  String _selectedBox = 'الصندوق الرئيسي';
  bool _isLoadingProducts = false;
  String _searchFilter = 'الكل';
  String _searchTerm = '';

  // Helpers
  final ProductQueries _productQueries = ProductQueries();
  final SupplierQueries _supplierQueries = SupplierQueries();

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
      _paidAmountController.text = invoice.paidAmount.toString();
      _globalDiscountController.text = invoice.discount.toString();
    } else {
      _generatedInvoiceNumber =
          'INV-${const Uuid().v4().substring(0, 8).toUpperCase()}';
      _dateController.text = _getTodayDate();
      _paidAmountController.text = '0';
    }
    _initializeControllers();
    _loadProducts();
  }

  // --- Data Loading & Initialization ---

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

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    final products = await _productQueries.getAllProducts();
    setState(() {
      _products = products;
      _isLoadingProducts = false;
    });
  }

  void _initializeControllers() {
    for (var item in _invoiceItems) {
      _quantityControllers.add(
        TextEditingController(text: item.quantity.toString()),
      );
      _purchasePriceControllers.add(
        TextEditingController(text: item.purchasePrice.toString()),
      );
      _salePriceControllers.add(
        TextEditingController(text: item.salePrice.toString()),
      );
      _itemDiscountControllers.add(
        TextEditingController(text: item.discount.toString()),
      );
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _searchController.dispose();
    _paidAmountController.dispose();
    _globalDiscountController.dispose();
    for (var c in _quantityControllers) c.dispose();
    for (var c in _purchasePriceControllers) c.dispose();
    for (var c in _salePriceControllers) c.dispose();
    for (var c in _itemDiscountControllers) c.dispose();
    super.dispose();
  }

  // --- Logic Methods ---

  String _getTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _getCurrentTime() =>
      "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

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
            return nameMatch || barcodeMatch;
          }).toList();
    });
  }

  void _addProductToInvoice(Product product) {
    if (_invoiceItems.any((item) => item.productName == product.name)) {
      TopAlert.showError(context: context, message: 'المنتج موجود بالفعل');
      return;
    }

    setState(() {
      final newItem = PurchaseInvoiceItem(
        id: null,
        productName: product.name,
        barcode: product.barcode ?? '',
        quantity: 1,
        purchasePrice: product.purchasePrice,
        salePrice: product.price,
        category:
            widget.categories
                .firstWhere(
                  (c) => c.id == product.categoryId,
                  orElse: () => Category(id: 0, name: '', color: ''),
                )
                .name,
        discount: 0.0,
        total: product.purchasePrice,
      );
      _invoiceItems.add(newItem);

      _quantityControllers.add(TextEditingController(text: "1"));
      _purchasePriceControllers.add(
        TextEditingController(text: product.purchasePrice.toString()),
      );
      _salePriceControllers.add(
        TextEditingController(text: product.price.toString()),
      );
      _itemDiscountControllers.add(TextEditingController(text: "0"));
    });
  }

  void _removeInvoiceItem(int index) {
    setState(() {
      _quantityControllers[index].dispose();
      _purchasePriceControllers[index].dispose();
      _salePriceControllers[index].dispose();
      _itemDiscountControllers[index].dispose();

      _quantityControllers.removeAt(index);
      _purchasePriceControllers.removeAt(index);
      _salePriceControllers.removeAt(index);
      _itemDiscountControllers.removeAt(index);

      _invoiceItems.removeAt(index);
    });
  }

  void _updateInvoiceItem(int index, String field, double value) {
    setState(() {
      final item = _invoiceItems[index];

      double qty =
          double.tryParse(_quantityControllers[index].text) ?? item.quantity;
      double pPrice =
          double.tryParse(_purchasePriceControllers[index].text) ??
          item.purchasePrice;
      double sPrice =
          double.tryParse(_salePriceControllers[index].text) ?? item.salePrice;
      double disc =
          double.tryParse(_itemDiscountControllers[index].text) ??
          item.discount;

      if (field == 'quantity') qty = value;
      if (field == 'purchasePrice') pPrice = value;
      if (field == 'salePrice') sPrice = value;
      if (field == 'discount') disc = value;

      double total = (qty * pPrice) - disc;
      if (total < 0) total = 0;

      _invoiceItems[index] = item.copyWith(
        quantity: qty,
        purchasePrice: pPrice,
        salePrice: sPrice,
        discount: disc,
        total: total,
      );
    });
  }

  double _calculateSubtotal() =>
      _invoiceItems.fold(0, (sum, item) => sum + item.total);
  double _calculateNetTotal() =>
      _calculateSubtotal() -
      (double.tryParse(_globalDiscountController.text) ?? 0.0);

  void _submitForm() {
    if (_selectedSupplier == null) {
      TopAlert.showError(context: context, message: 'يرجى اختيار المورد');
      return;
    }
    if (_invoiceItems.isEmpty) {
      TopAlert.showError(context: context, message: 'الفاتورة فارغة!');
      return;
    }

    final netTotal = _calculateNetTotal();
    double paid = 0.0;
    double remaining = 0.0;

    if (_paymentStatus == 'مدفوع') {
      paid = netTotal;
    } else if (_paymentStatus == 'غير مدفوع') {
      remaining = netTotal;
    } else {
      paid = double.tryParse(_paidAmountController.text) ?? 0.0;
      if (paid > netTotal) {
        TopAlert.showError(
          context: context,
          message: 'المدفوع أكبر من الإجمالي',
        );
        return;
      }
      remaining = netTotal - paid;
    }

    final invoice = PurchaseInvoice(
      id: widget.invoiceToEdit?.id,
      invoiceNumber: _generatedInvoiceNumber,
      supplier: _selectedSupplier!.name,
      supplierId: _selectedSupplier!.id,
      date: _dateController.text,
      time: _isEditMode ? widget.invoiceToEdit!.time : _getCurrentTime(),
      items: _invoiceItems,
      total: netTotal,
      discount: double.tryParse(_globalDiscountController.text) ?? 0.0,
      paymentStatus: _paymentStatus,
      paymentType: _paymentStatus == 'غير مدفوع' ? 'آجل' : 'نقدي',
      paidAmount: paid,
      remainingAmount: remaining,
    );

    widget.onSave(invoice, _purchasePriceUpdateMethod, _selectedBox);
  }

  // --- UI Building Blocks ---

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildHeaderSection(),

                Expanded(
                  child: Row(
                    children: [
                      // القائمة الجانبية (المنتجات) - 30%
                      SizedBox(
                        width: constraints.maxWidth * 0.3,
                        child: _buildProductSelectionPanel(),
                      ),
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Colors.grey,
                      ),

                      // جدول الفاتورة - 70%
                      Expanded(child: _buildInvoiceTablePanel()),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1),
                _buildFooterSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 1. Header Section ---
  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_long, color: Colors.blue, size: 28),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "فاتورة شراء جديدة",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                _generatedInvoiceNumber,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(width: 30),

          // المورد
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<Supplier>(
              value: _selectedSupplier,
              decoration: const InputDecoration(
                labelText: "المورد",
                prefixIcon: Icon(Icons.store),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
              items:
                  _suppliers
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
              onChanged: (val) => setState(() => _selectedSupplier = val),
            ),
          ),
          const SizedBox(width: 16),

          // التاريخ
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: "التاريخ",
                prefixIcon: Icon(Icons.calendar_month),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
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
                      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Left Panel: Product Selection ---
  Widget _buildProductSelectionPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'بحث عن منتج...',
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: (val) {
              setState(() => _searchTerm = val);
              _searchProducts();
            },
          ),
        ),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _buildFilterChip('الكل'),
              _buildFilterChip('الاسم'),
              _buildFilterChip('الباركود'),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder:
                        (context) => ProductDialog(
                          categories: widget.categories,
                          onSave: (product) async {
                            final saved = await _productQueries.createProduct(
                              product,
                            );
                            await _loadProducts();
                            _addProductToInvoice(saved);
                            Navigator.pop(context);
                          },
                          onCancel: () => Navigator.pop(context),
                        ),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text("منتج جديد"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        const Divider(),

        // Product List
        Expanded(
          child:
              _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                    itemCount: _products.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return InkWell(
                        onTap: () => _addProductToInvoice(product),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      "باركود: ${product.barcode ?? '-'} | مخزون: ${product.stock}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${product.purchasePrice} ش",
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.add_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _searchFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() => _searchFilter = label);
          if (_searchTerm.isNotEmpty) _searchProducts();
        },
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 12,
        ),
        selectedColor: Colors.blue,
        backgroundColor: Colors.grey.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  // --- 3. Right Panel: Invoice Table ---
  Widget _buildInvoiceTablePanel() {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          color: Colors.grey.shade200,
          child: Row(
            children: const [
              Expanded(
                flex: 3,
                child: Text(
                  "  اسم المنتج",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  "الكمية",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "سعر الشراء",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "سعر البيع",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "الخصم",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "الإجمالي",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              SizedBox(width: 40), // For delete button
            ],
          ),
        ),

        // Items List
        Expanded(
          child:
              _invoiceItems.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "السلة فارغة",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        Text(
                          "اختر منتجات من القائمة لإضافتها",
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    itemCount: _invoiceItems.length,
                    itemBuilder: (context, index) {
                      final item = _invoiceItems[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              index % 2 == 0
                                  ? Colors.white
                                  : Colors.blue.shade50.withOpacity(0.2),
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Tooltip(
                                message: item.productName,
                                child: Text(
                                  "  ${item.productName}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildTableInput(
                                _quantityControllers[index],
                                (v) => _updateInvoiceItem(
                                  index,
                                  'quantity',
                                  double.tryParse(v) ?? 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: _buildTableInput(
                                _purchasePriceControllers[index],
                                (v) => _updateInvoiceItem(
                                  index,
                                  'purchasePrice',
                                  double.tryParse(v) ?? 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: _buildTableInput(
                                _salePriceControllers[index],
                                (v) => _updateInvoiceItem(
                                  index,
                                  'salePrice',
                                  double.tryParse(v) ?? 0,
                                ),
                                textColor: Colors.green.shade800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: _buildTableInput(
                                _itemDiscountControllers[index],
                                (v) => _updateInvoiceItem(
                                  index,
                                  'discount',
                                  double.tryParse(v) ?? 0,
                                ),
                                textColor: Colors.red.shade800,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "${item.total.toStringAsFixed(2)}",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeInvoiceItem(index),
                                splashRadius: 20,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildTableInput(
    TextEditingController controller,
    Function(String) onChanged, {
    Color? textColor,
  }) {
    return SizedBox(
      height: 35, // ارتفاع أكبر قليلاً لسهولة الكتابة
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: textColor ?? Colors.black87,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.blue, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
      ),
    );
  }

  // --- 4. Footer Section ---
  Widget _buildFooterSection() {
    final subTotal = _calculateSubtotal();
    final netTotal = _calculateNetTotal();

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Payment Details & Settings
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _paymentStatus,
                        decoration: const InputDecoration(
                          labelText: "حالة الدفع",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items:
                            ['مدفوع', 'جزئي', 'غير مدفوع', 'مرتجع']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _paymentStatus = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_paymentStatus == 'جزئي')
                      Expanded(
                        child: TextFormField(
                          controller: _paidAmountController,
                          decoration: const InputDecoration(
                            labelText: "المبلغ المدفوع",
                            suffixText: "ش",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBox,
                        decoration: const InputDecoration(
                          labelText: "الصندوق",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items:
                            ['الصندوق الرئيسي', 'الصندوق اليومي']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _selectedBox = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _purchasePriceUpdateMethod,
                        decoration: const InputDecoration(
                          labelText: "طريقة تحديث التكلفة",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'جديد',
                            child: Text('اعتماد السعر الجديد'),
                          ),
                          DropdownMenuItem(
                            value: 'متوسط',
                            child: Text('المتوسط المرجح'),
                          ),
                        ],
                        onChanged:
                            (v) =>
                                setState(() => _purchasePriceUpdateMethod = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 30),

          // Right Side: Totals & Actions
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Totals
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "المجموع الفرعي:",
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            "${subTotal.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "خصم الفاتورة:",
                            style: TextStyle(fontSize: 14, color: Colors.red),
                          ),
                          SizedBox(
                            width: 80,
                            height: 30,
                            child: TextField(
                              controller: _globalDiscountController,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) => setState(() {}),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "الإجمالي النهائي:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${netTotal.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("إلغاء"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.save),
                        label: Text(
                          _isEditMode ? "حفظ التعديلات" : "حفظ الفاتورة",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
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
}
