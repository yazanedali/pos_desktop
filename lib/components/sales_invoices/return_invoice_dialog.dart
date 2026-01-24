import 'package:flutter/material.dart';
import 'package:pos_desktop/models/sales_invoice.dart';
import 'package:pos_desktop/services/sales_invoice_service.dart';
import 'package:pos_desktop/widgets/top_alert.dart';

class ReturnInvoiceDialog extends StatefulWidget {
  final SaleInvoice invoice;
  final Function() onReturnCompleted;

  const ReturnInvoiceDialog({
    super.key,
    required this.invoice,
    required this.onReturnCompleted,
  });

  @override
  State<ReturnInvoiceDialog> createState() => _ReturnInvoiceDialogState();
}

class _ReturnInvoiceDialogState extends State<ReturnInvoiceDialog> {
  final SalesInvoiceService _service = SalesInvoiceService();
  late List<SaleInvoiceItem> _items;
  final Map<int, double> _returnQuantities = {};
  bool _returnToCash = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.invoice.items);
    // Initialize quantities to 0
    for (var item in _items) {
      _returnQuantities[item.id!] = 0.0;
    }
  }

  double get _totalReturnAmount {
    double total = 0.0;
    for (var item in _items) {
      final qty = _returnQuantities[item.id!] ?? 0.0;
      total += qty * item.price;
    }
    return total;
  }

  void _submitReturn() async {
    final double totalReturn = _totalReturnAmount;
    if (totalReturn <= 0) {
      TopAlert.showError(
        context: context,
        message: "الرجاء تحديد كميات للإرجاع",
      );
      return;
    }

    // Validation: Check if return amount exceeds paid amount (if returning to cash)
    if (_returnToCash && totalReturn > widget.invoice.paidAmount) {
      // if customer paid 50, but wants to return items worth 70, we can only give back 50 cash?
      // The user rule: "منع إرجاع مبلغ أكبر من المدفوع فعلياً"
      // But wait, if he bought for 100 (Unpaid), paid 0. Returns items worth 20.
      // We should NOT give him 20 Cash. We should reduce debt.
      // So if paidAmount < totalReturn, suggest "Account Credit" instead of Cash?
      // Or simply strictly forbid "Return To Cash" if totalReturn > paidAmount.

      if (widget.invoice.remainingAmount > 0 &&
          totalReturn > widget.invoice.paidAmount) {
        TopAlert.showError(
          context: context,
          message:
              "لا يمكن إرجاع كاش أكثر مما دفعه العميل. المبلغ المدفوع: ${widget.invoice.paidAmount}",
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final List<SaleInvoiceItem> itemsToReturn = [];
      for (var item in _items) {
        final qty = _returnQuantities[item.id!] ?? 0.0;
        if (qty > 0) {
          itemsToReturn.add(
            item.copyWith(quantity: qty, total: qty * item.price),
          );
        }
      }

      await _service.processReturn(
        parentInvoiceId: widget.invoice.id!,
        itemsToReturn: itemsToReturn,
        returnTotal: totalReturn,
        returnToCash: _returnToCash,
      );

      widget.onReturnCompleted();
      if (mounted) {
        Navigator.pop(context);
        TopAlert.showSuccess(
          context: context,
          message: "تم تسجيل المرتجع بنجاح",
        );
      }
    } catch (e) {
      if (mounted) {
        TopAlert.showError(context: context, message: "خطأ: $e");
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "إرجاع أصناف",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Row(
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
                            Text("${item.price} شيكل / ${item.unitName}"),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text("المباع: ${item.quantity}"),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            const Text("إرجاع: "),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: "0",
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) {
                                  final v = double.tryParse(val) ?? 0.0;
                                  if (v < 0) return;
                                  if (v > item.quantity) {
                                    // Reset or warn?
                                    // Just clamp logic or UI warning?
                                  }
                                  setState(() {
                                    _returnQuantities[item.id!] =
                                        v > item.quantity ? item.quantity : v;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "طريقة الإرجاع:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _returnToCash,
                          onChanged: (v) => setState(() => _returnToCash = v!),
                        ),
                        const Text("إرجاع كاش (من الصندوق)"),
                        const SizedBox(width: 16),
                        Radio<bool>(
                          value: false,
                          groupValue: _returnToCash,
                          onChanged: (v) => setState(() => _returnToCash = v!),
                        ),
                        const Text("إرجاع للدين (رصيد)"),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "إجمالي المرتجع: ${_totalReturnAmount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء"),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                          : const Text("تأكيد الإرجاع"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
