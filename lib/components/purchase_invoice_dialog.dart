import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/product_queries.dart';
import '../models/category.dart';
import '../models/purchase_invoice.dart';
import '../widgets/top_alert.dart';

class PurchaseInvoiceDialog extends StatefulWidget {
  final List<Category> categories;
  final Function(PurchaseInvoice) onSave;
  final Function() onCancel;
  final PurchaseInvoice? invoiceToEdit;

  const PurchaseInvoiceDialog({
    Key? key,
    required this.categories,
    required this.onSave,
    required this.onCancel,
    this.invoiceToEdit,
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

  @override
  void initState() {
    super.initState();
    _supplierController = TextEditingController();
    _dateController = TextEditingController();

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
      _addInvoiceItem();
    }
    _initializeControllers();
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
    _disposeItemControllers();
    super.dispose();
  }

  void _disposeItemControllers() {
    // ignore: curly_braces_in_flow_control_structures
    for (var c in _productNameControllers) c.dispose();
    // ignore: curly_braces_in_flow_control_structures
    for (var c in _barcodeControllers) c.dispose();
    // ignore: curly_braces_in_flow_control_structures
    for (var c in _quantityControllers) c.dispose();
    // ignore: curly_braces_in_flow_control_structures
    for (var c in _purchasePriceControllers) c.dispose();
    // ignore: curly_braces_in_flow_control_structures
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

  void _addInvoiceItem() {
    setState(() {
      _invoiceItems.add(
        PurchaseInvoiceItem(
          productName: '',
          barcode: '',
          quantity: 0.0, // تأكد أنه double
          purchasePrice: 0.0,
          salePrice: 0.0,
          category: '',
          total: 0.0,
        ),
      );
      _productNameControllers.add(TextEditingController());
      _barcodeControllers.add(TextEditingController());
      _quantityControllers.add(TextEditingController(text: '1'));
      _purchasePriceControllers.add(TextEditingController(text: '0'));
      _salePriceControllers.add(TextEditingController(text: '0'));
    });
  }

  void _removeInvoiceItem(int index) {
    if (_invoiceItems.length > 1) {
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

  Future<void> _findProductByBarcode(String barcode, int index) async {
    if (barcode.isEmpty) return;
    final product = await ProductQueries().getProductByBarcode(barcode);
    if (product != null) {
      final category = widget.categories.firstWhere(
        (c) => c.id == product.categoryId,
        orElse: () => Category(id: 0, name: 'غير معروف', color: '#000000'),
      );
      setState(() {
        _invoiceItems[index] = _invoiceItems[index].copyWith(
          productName: product.name,
          barcode: product.barcode,
          salePrice: product.price,
          category: category.name,
        );
        _productNameControllers[index].text = product.name;
        _salePriceControllers[index].text = product.price.toString();
      });
    } else {
      TopAlert.showWarning(
        context: context,
        message: 'لم يتم العثور على منتج بهذا الباركود',
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
            'يرجى إضافة منتج واحد على الأقل مع:\n- اسم المنتج\n- كمية أكبر من صفر\n- سعر شراء أكبر من صفر',
      );
      return;
    }

    // إذا كانت جميع الشروط متوفرة، إنشاء الفاتورة
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

  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.of(context).size.width * 0.8;
    final dialogHeight = MediaQuery.of(context).size.height * 0.85;

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
              // معلومات الفاتورة الأساسية
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

              // بنود الفاتورة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "بنود الفاتورة",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addInvoiceItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("إضافة بند"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // قائمة البنود
              Expanded(
                child: ListView.builder(
                  itemCount: _invoiceItems.length,
                  itemBuilder: (context, index) => _buildInvoiceItemCard(index),
                ),
              ),

              // الإجمالي
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      "إجمالي الفاتورة:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "${_calculateTotal().toStringAsFixed(2)} شيكل",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
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

  Widget _buildInvoiceItemCard(int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _productNameControllers[index],
                  decoration: const InputDecoration(
                    labelText: "اسم المنتج *",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => _updateInvoiceItem(index, 'productName', v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _barcodeControllers[index],
                  decoration: const InputDecoration(
                    labelText: "الباركود",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => _updateInvoiceItem(index, 'barcode', v),
                  onFieldSubmitted: (v) => _findProductByBarcode(v, index),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value:
                      _invoiceItems[index].category.isEmpty
                          ? null
                          : _invoiceItems[index].category,
                  decoration: const InputDecoration(
                    labelText: "الفئة",
                    border: OutlineInputBorder(),
                  ),
                  items:
                      widget.categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.name,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (v) => _updateInvoiceItem(index, 'category', v ?? ''),
                ),
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
                    labelText: "الكمية *",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged:
                      (v) => _updateInvoiceItem(
                        index,
                        'quantity',
                        double.tryParse(v) ?? 0.0,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _purchasePriceControllers[index],
                  decoration: const InputDecoration(
                    labelText: "سعر الشراء *",
                    border: OutlineInputBorder(),
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
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeInvoiceItem(index),
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
