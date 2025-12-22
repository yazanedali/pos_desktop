// في invoice_edit_dialog.dart - أعد كتابة الكود كاملاً
import 'package:flutter/material.dart';
import 'package:pos_desktop/models/sales_invoice.dart';
import 'package:pos_desktop/services/sales_invoice_service.dart';
import 'package:pos_desktop/widgets/top_alert.dart';

class InvoiceEditDialog extends StatefulWidget {
  final SaleInvoice invoice;
  final VoidCallback onInvoiceUpdated;

  const InvoiceEditDialog({
    super.key,
    required this.invoice,
    required this.onInvoiceUpdated,
  });

  @override
  State<InvoiceEditDialog> createState() => _InvoiceEditDialogState();
}

class _InvoiceEditDialogState extends State<InvoiceEditDialog> {
  final SalesInvoiceService _invoiceService = SalesInvoiceService();
  final TextEditingController _paidAmountController = TextEditingController();
  List<SaleInvoiceItem> _modifiedItems = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _modifiedItems = List.from(widget.invoice.items);
    _paidAmountController.text = widget.invoice.paidAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _updateItemQuantity(int index, double newQuantity) async {
    if (newQuantity < 0) return;

    final item = _modifiedItems[index];

    // التحقق من المخزون إذا كانت الكمية تزيد
    if (newQuantity > item.quantity) {
      final difference = newQuantity - item.quantity;
      final totalPiecesNeeded = difference * item.unitQuantity;

      try {
        // جلب المخزون الحالي للمنتج
        final product = await _getProductById(item.id!);
        if (product != null && product.stock < totalPiecesNeeded) {
          TopAlert.showError(
            context: context,
            message:
                'المخزون غير كافي للمنتج ${item.productName}. المتاح: ${product.stock.toStringAsFixed(0)} قطعة, المطلوب: ${totalPiecesNeeded.toStringAsFixed(0)} قطعة',
          );
          return;
        }
      } catch (e) {
        TopAlert.showError(
          context: context,
          message: 'خطأ في التحقق من المخزون: $e',
        );
        return;
      }
    }

    setState(() {
      _modifiedItems[index] = _modifiedItems[index].copyWith(
        quantity: newQuantity,
        total: _modifiedItems[index].price * newQuantity,
      );
    });
  }

  Future<dynamic> _getProductById(int productId) async {
    final db = await _invoiceService.getDatabase();
    final products = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );
    return products.isNotEmpty ? products.first : null;
  }

  void _removeItem(int index) {
    setState(() {
      _modifiedItems.removeAt(index);
    });
  }

  double _calculateNewTotal() {
    return _modifiedItems.fold(0.0, (sum, item) => sum + item.total);
  }

  double get _paidAmount {
    return double.tryParse(_paidAmountController.text) ??
        widget.invoice.paidAmount;
  }

  double get _remainingAmount {
    final newTotal = _calculateNewTotal();
    return newTotal - _paidAmount;
  }

  bool _hasChanges() {
    if (_modifiedItems.length != widget.invoice.items.length) return true;

    for (int i = 0; i < _modifiedItems.length; i++) {
      if (_modifiedItems[i].quantity != widget.invoice.items[i].quantity) {
        return true;
      }
    }

    // التحقق من تغيير المبلغ المدفوع
    if (_paidAmount != widget.invoice.paidAmount) {
      return true;
    }

    return false;
  }

  Future<void> _updateInvoice() async {
    if (!_hasChanges()) {
      TopAlert.showWarning(context: context, message: 'لا توجد تغييرات لحفظها');
      return;
    }

    // التحقق من أن جميع الكميات صالحة
    for (final item in _modifiedItems) {
      if (item.quantity <= 0) {
        TopAlert.showError(
          context: context,
          message: 'كمية المنتج ${item.productName} يجب أن تكون أكبر من الصفر',
        );
        return;
      }
    }

    final newTotal = _calculateNewTotal();
    final paidAmount = _paidAmount;

    // التحقق من أن المبلغ المدفوع لا يتجاوز الإجمالي
    if (paidAmount > newTotal) {
      TopAlert.showError(
        context: context,
        message:
            'المبلغ المدفوع ($paidAmount) لا يمكن أن يكون أكبر من الإجمالي ($newTotal)',
      );
      return;
    }

    // التحقق من أن المبلغ المدفوع غير سالب
    if (paidAmount < 0) {
      TopAlert.showError(
        context: context,
        message: 'المبلغ المدفوع لا يمكن أن يكون سالباً',
      );
      return;
    }

    try {
      setState(() => _isProcessing = true);

      await _invoiceService.updateInvoiceWithPayment(
        invoiceId: widget.invoice.id!,
        updatedItems: _modifiedItems,
        newPaidAmount: paidAmount,
      );

      if (mounted) {
        TopAlert.showSuccess(
          context: context,
          message: 'تم تعديل الفاتورة بنجاح',
        );

        // استدعاء callback التحديث أولاً
        widget.onInvoiceUpdated();

        // ثم إغلاق الـ dialog بعد فترة قصيرة
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'خطأ في تعديل الفاتورة';
        if (e.toString().contains('المخزون غير كافي')) {
          errorMessage = e.toString();
        }
        TopAlert.showError(context: context, message: errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _returnPartialItem(int itemIndex) async {
    final item = _modifiedItems[itemIndex];

    if (item.id == null) {
      TopAlert.showError(context: context, message: 'لا يمكن إرجاع هذا المنتج');
      return;
    }

    final returnedQuantity = await showDialog<double>(
      context: context,
      builder:
          (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: PartialReturnDialog(item: item),
          ),
    );

    if (returnedQuantity == null || returnedQuantity <= 0) return;

    try {
      setState(() => _isProcessing = true);

      await _invoiceService.returnPartialItem(
        invoiceId: widget.invoice.id!,
        itemId: item.id!,
        returnedQuantity: returnedQuantity,
      );

      if (mounted) {
        TopAlert.showSuccess(
          context: context,
          message: 'تم إرجاع الكمية بنجاح',
        );
        widget.onInvoiceUpdated();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        TopAlert.showError(
          context: context,
          message: 'خطأ في إرجاع المنتج: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final newTotal = _calculateNewTotal();
    final remainingAmount = _remainingAmount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildPaymentSection(newTotal, remainingAmount),
              const SizedBox(height: 16),
              Expanded(child: _buildInvoiceItems()),
              const SizedBox(height: 16),
              _buildFooter(newTotal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_hasChanges())
          ElevatedButton(
            onPressed: _isProcessing ? null : _updateInvoice,
            child:
                _isProcessing
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('حفظ التغييرات'),
          ),
        Column(
          children: [
            Text(
              'تعديل فاتورة #${widget.invoice.invoiceNumber}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.invoice.date} - ${widget.invoice.time}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildPaymentSection(double newTotal, double remainingAmount) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'المبالغ المالية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المبلغ المدفوع:'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _paidAmountController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'أدخل المبلغ المدفوع',
                          suffixText: 'شيكل',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المبلغ المتبقي:'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${remainingAmount.toStringAsFixed(2)} شيكل',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                remainingAmount > 0
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (remainingAmount < 0)
              Text(
                '⚠️ المبلغ المدفوع أكبر من الإجمالي',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItems() {
    return Column(
      children: [
        const Text(
          'منتجات الفاتورة',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _modifiedItems.length,
            itemBuilder: (context, index) {
              return _buildInvoiceItem(_modifiedItems[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceItem(SaleInvoiceItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: PopupMenuButton(
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'return_partial',
                        child: Row(
                          children: [
                            Icon(Icons.reply, size: 16),
                            SizedBox(width: 8),
                            Text('إرجاع جزئي'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('حذف'),
                          ],
                        ),
                      ),
                    ],
                onSelected: (value) {
                  if (value == 'return_partial') {
                    _returnPartialItem(index);
                  } else if (value == 'remove') {
                    _removeItem(index);
                  }
                },
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${item.unitQuantity} ${item.unitName}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${item.price.toStringAsFixed(2)} شيكل',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${item.total.toStringAsFixed(2)} شيكل',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  IconButton(
                    onPressed:
                        () => _updateItemQuantity(index, item.quantity - 1),
                    icon: const Icon(Icons.remove, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextFormField(
                      textAlign: TextAlign.center,
                      controller: TextEditingController(
                        text: item.quantity.toStringAsFixed(
                          item.quantity % 1 == 0 ? 0 : 2,
                        ),
                      ),
                      onChanged: (value) {
                        final newQty = double.tryParse(value) ?? item.quantity;
                        if (newQty != item.quantity) {
                          _updateItemQuantity(index, newQty);
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed:
                        () => _updateItemQuantity(index, item.quantity + 1),
                    icon: const Icon(Icons.add, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(double newTotal) {
    final difference = newTotal - widget.invoice.total;
    final remainingAmount = _remainingAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي الأصلي:'),
              Text('${widget.invoice.total.toStringAsFixed(2)} شيكل'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي الجديد:'),
              Text(
                '${newTotal.toStringAsFixed(2)} شيكل',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المبلغ المدفوع:'),
              Text(
                '${_paidAmount.toStringAsFixed(2)} شيكل',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المبلغ المتبقي:'),
              Text(
                '${remainingAmount.toStringAsFixed(2)} شيكل',
                style: TextStyle(
                  color: remainingAmount > 0 ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (difference != 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الفرق في الإجمالي:'),
                Text(
                  '${difference.toStringAsFixed(2)} شيكل',
                  style: TextStyle(
                    color: difference > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// باقي الكود بدون تغيير...
class PartialReturnDialog extends StatefulWidget {
  final SaleInvoiceItem item;

  const PartialReturnDialog({super.key, required this.item});

  @override
  State<PartialReturnDialog> createState() => _PartialReturnDialogState();
}

class _PartialReturnDialogState extends State<PartialReturnDialog> {
  final TextEditingController _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _quantityController.text = widget.item.quantity.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إرجاع جزئي للمنتج'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.item.productName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'الكمية المراد إرجاعها',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Text('الكمية المتاحة للإرجاع: ${widget.item.quantity}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final returnedQty = double.tryParse(_quantityController.text);
              if (returnedQty != null &&
                  returnedQty > 0 &&
                  returnedQty <= widget.item.quantity) {
                Navigator.pop(context, returnedQty);
              } else {
                TopAlert.showError(
                  context: context,
                  message: 'الكمية غير صالحة',
                );
              }
            },
            child: const Text('إرجاع'),
          ),
        ],
      ),
    );
  }
}
