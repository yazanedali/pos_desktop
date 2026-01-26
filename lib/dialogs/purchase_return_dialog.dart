import 'package:flutter/material.dart';
import 'package:pos_desktop/widgets/top_alert.dart';
import '../models/purchase_invoice.dart';
import '../database/purchase_queries.dart';

class PurchaseReturnDialog extends StatefulWidget {
  final PurchaseInvoice originalInvoice;
  final Function() onReturnCompleted;

  const PurchaseReturnDialog({
    super.key,
    required this.originalInvoice,
    required this.onReturnCompleted,
  });

  @override
  State<PurchaseReturnDialog> createState() => _PurchaseReturnDialogState();
}

class _PurchaseReturnDialogState extends State<PurchaseReturnDialog> {
  final PurchaseQueries _purchaseQueries = PurchaseQueries();

  // حالة الكميات: {product_name: return_quantity}
  final Map<String, double> _returnQuantities = {};

  // الكميات المرجعة سابقاً: {product_name: returned_qty}
  Map<String, double> _previouslyReturned = {};

  bool _isLoading = true;
  String? _errorMessage;

  // حفظ المتحكمات النصية لكل منتج
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadPreviousReturns();
    // تهيئة المتحكمات
    for (var item in widget.originalInvoice.items) {
      _controllers[item.productName] = TextEditingController(text: "0");
    }
  }

  @override
  void dispose() {
    // تنظيف المتحكمات
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPreviousReturns() async {
    try {
      if (widget.originalInvoice.id != null) {
        _previouslyReturned = await _purchaseQueries.getReturnedQuantities(
          widget.originalInvoice.id!,
        );
      }
    } catch (e) {
      _errorMessage = "فشل تحميل البيانات السابقة: $e";
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double _getMaxReturnable(PurchaseInvoiceItem item) {
    double previous = _previouslyReturned[item.productName] ?? 0.0;
    // الكمية الأصلية - ما تم إرجاعه سابقاً
    double max = item.quantity - previous;
    // تقريب لأقرب منزلتين عشريتين لتجنب مشاكل الفواصل العائمة
    return double.parse(max.toStringAsFixed(2)) < 0
        ? 0
        : double.parse(max.toStringAsFixed(2));
  }

  // تحديث الكمية (سواء من النص أو الأزرار)
  void _updateQuantity(PurchaseInvoiceItem item, double newQty) {
    double max = _getMaxReturnable(item);

    // التحقق من الحد الأقصى
    if (newQty > max) {
      TopAlert.showError(
        context: context,
        message: "عذراً، أقصى كمية يمكن إرجاعها هي $max",
      );
      newQty = max; // تصحيح القيمة للحد الأقصى
    } else if (newQty < 0) {
      newQty = 0;
    }

    setState(() {
      _returnQuantities[item.productName] = newQty;

      // تحديث النص في المتحكم إذا كان مختلفاً (فقط لتزامن الأزرار مع النص)
      // نستخدم تنسيق يزيل الأصفار العشرية غير الضرورية
      String text =
          newQty == newQty.toInt()
              ? newQty.toInt().toString()
              : newQty.toString();
      if (_controllers[item.productName]!.text != text) {
        // إذا كنا نكتب، لا نريد تغيير النص وتخريب موقع المؤشر إلا إذا تم التصحيح
        _controllers[item.productName]!.text = text;
        // نقل المؤشر للنهاية
        _controllers[item.productName]!.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
      }
    });
  }

  // حساب إجمالي قيمة المرتجع الحالي
  double get _totalReturnValue {
    double total = 0.0;
    for (var item in widget.originalInvoice.items) {
      double qty = _returnQuantities[item.productName] ?? 0.0;
      if (qty > 0) {
        // نستخدم سعر الشراء الأصلي كما هو في الفاتورة
        total += qty * item.purchasePrice;
      }
    }
    return total;
  }

  // حساب الاسترداد النقدي المقترح
  double get _cashRefundAmount {
    double totalReturn = _totalReturnValue;
    double originalPaid = widget.originalInvoice.paidAmount;

    if (totalReturn <= originalPaid) {
      return totalReturn;
    } else {
      return originalPaid;
    }
  }

  double get _debtReductionAmount {
    return _totalReturnValue - _cashRefundAmount;
  }

  Future<void> _submitReturn() async {
    if (_totalReturnValue <= 0) {
      TopAlert.showError(
        context: context,
        message: "يرجى اختيار عناصر للإرجاع",
      );
      return;
    }

    // التحقق من المخزون قبل التأكيد
    List<String> negativeStockWarnings = [];

    // إظهار loading بسيط أثناء التحقق
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (var item in widget.originalInvoice.items) {
        double returnQty = _returnQuantities[item.productName] ?? 0.0;
        if (returnQty > 0) {
          final product = await _purchaseQueries.productQueries
              .getProductByName(item.productName);
          if (product != null) {
            double currentStock = product.stock;
            if (currentStock < returnQty) {
              negativeStockWarnings.add(
                "- ${item.productName}: المخزون الحالي ($currentStock) - المراد إرجاعه ($returnQty) = الرصيد الجديد (${(currentStock - returnQty).toStringAsFixed(1)})",
              );
            }
          }
        }
      }
    } catch (e) {
      // تجاهل الأخطاء هنا للاستمرار، سيتم التعامل معها لاحقاً
      print("Error checking stock: $e");
    } finally {
      // إغلاق ديالوج التحميل
      if (mounted) Navigator.pop(context);
    }

    if (negativeStockWarnings.isNotEmpty) {
      // إظهار تحذير قوي
      final proceed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: Colors.red[50],
              title: Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 30,
                  ),
                  SizedBox(width: 10),
                  Text(
                    "تحذير: مخزون بالسالب",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "إتمام هذا المرتجع سيجعل مخزون بعض المنتجات بالسالب لأن الكمية المتوفرة حالياً أقل من الكمية المرجعة:",
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          negativeStockWarnings
                              .map(
                                (w) => Text(
                                  w,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text("هل أنت متأكد أنك تريد المتابعة؟"),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("نعم، متابعة على مسؤوليتي"),
                ),
              ],
            ),
      );

      if (proceed != true) return;
    }

    // تأكيد (العادي - إذا لم يكن هناك تحذير أو تم قبول التحذير)
    if (negativeStockWarnings.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text("تأكيد المرتجع"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "إجمالي قيمة المرتجع: ${_totalReturnValue.toStringAsFixed(2)}",
                  ),
                  const Divider(),
                  Text(
                    "سيتم استرداد نقدي (للصندوق): ${_cashRefundAmount.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.green),
                  ),
                  Text(
                    "سيتم خصم من رصيد المورد (دين): ${_debtReductionAmount.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.orange),
                  ),
                  const SizedBox(height: 10),
                  const Text("هل أنت متأكد؟ لا يمكن التراجع عن هذه العملية."),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("تأكيد وإرجاع"),
                ),
              ],
            ),
      );
      if (confirm != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final date =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final time =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      // بناء قائمة العناصر المرجعة
      List<PurchaseInvoiceItem> returnItems = [];
      for (var item in widget.originalInvoice.items) {
        double qty = _returnQuantities[item.productName] ?? 0.0;
        if (qty > 0) {
          returnItems.add(
            PurchaseInvoiceItem(
              productName: item.productName,
              barcode: item.barcode,
              quantity:
                  qty, // this goes into the object positive, but handled as negative in query
              purchasePrice: item.purchasePrice,
              salePrice: item.salePrice, // Keep consistent
              category: item.category,
              discount: 0, // No discount logic on return handling for now
              total: qty * item.purchasePrice,
            ),
          );
        }
      }

      final returnInvoice = PurchaseInvoice(
        invoiceNumber:
            "R-${widget.originalInvoice.invoiceNumber}-${now.millisecondsSinceEpoch.toString().substring(10)}", // Generate unique return number
        supplier: widget.originalInvoice.supplier,
        supplierId: widget.originalInvoice.supplierId,
        date: date,
        time: time,
        items: returnItems,
        total: _totalReturnValue, // recalculated in Query anyway
        discount: 0,
        paidAmount: _cashRefundAmount, // المبلغ المسترد كاش
        remainingAmount: _debtReductionAmount, // المبلغ المخصوم من الدين
        paymentType: 'مرتجع',
        paymentStatus: 'مرتجع',
        isReturn: true,
        parentInvoiceId: widget.originalInvoice.id,
      );

      await _purchaseQueries.createPurchaseReturn(
        returnInvoice,
        originalInvoiceId: widget.originalInvoice.id,
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        widget.onReturnCompleted(); // Refresh parent
        TopAlert.showSuccess(
          context: context,
          message: "تم إنشاء المرتجع بنجاح",
        );
      }
    } catch (e) {
      if (mounted) {
        TopAlert.showError(context: context, message: "خطأ: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.assignment_return,
                    color: Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "إنشاء مرتجع شراء",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "تابع للفاتورة: ${widget.originalInvoice.invoiceNumber}",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 30),

              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              else ...[
                // جدول العناصر
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.originalInvoice.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.originalInvoice.items[index];
                      final maxReturn = _getMaxReturnable(item);
                      final currentReturn =
                          _returnQuantities[item.productName] ?? 0.0;

                      // إذا لم يبق شيء للإرجاع، نخفيه أو نعطله
                      final bool isDisabled = maxReturn <= 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: isDisabled ? Colors.grey[100] : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "تم شراءة: ${item.quantity} | تم إرجاعه: ${_previouslyReturned[item.productName] ?? 0}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text("السعر: ${item.purchasePrice}"),
                              ),
                              // حقل الإدخال
                              if (!isDisabled)
                                SizedBox(
                                  width: 140, // زيادة العرض قليلاً
                                  child: Row(
                                    children: [
                                      // زر التقليل
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed:
                                            currentReturn > 0
                                                ? () => _updateQuantity(
                                                  item,
                                                  currentReturn - 1,
                                                )
                                                : null,
                                      ),

                                      const SizedBox(width: 8),

                                      // حقل النص
                                      Expanded(
                                        child: SizedBox(
                                          height: 40,
                                          child: TextFormField(
                                            controller:
                                                _controllers[item.productName],
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              isDense: true,
                                            ),
                                            onChanged: (val) {
                                              if (val.isEmpty) {
                                                // لا نقوم بالتحديث للصفرحالاً، ننتظر
                                                return;
                                              }
                                              double? valDouble =
                                                  double.tryParse(val);
                                              if (valDouble != null) {
                                                _updateQuantity(
                                                  item,
                                                  valDouble,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // زر الزيادة
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed:
                                            currentReturn < maxReturn
                                                ? () => _updateQuantity(
                                                  item,
                                                  currentReturn + 1,
                                                )
                                                : null,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const Text(
                                  "تم الإرجاع بالكامل",
                                  style: TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(),

                // ملخص الإرجاع
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "إجمالي قيمة المرتجع:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${_totalReturnValue.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "استرداد نقدي (للصندوق)",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "+ ${_cashRefundAmount.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "خصم من الدين (رصيد مورد)",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ), // Red usually denotes negative/debt, but here it's good contextually
                                Text(
                                  "- ${_debtReductionAmount.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text(
                          "حفظ المرتجع",
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _submitReturn,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("إلغاء"),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
