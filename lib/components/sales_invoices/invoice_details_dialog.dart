// في invoice_details_dialog.dart - تحديث الكود
import 'package:flutter/material.dart';

import 'package:pos_desktop/dialogs/invoice_edit_dialog.dart';
import '../../models/sales_invoice.dart';

class InvoiceDetailsDialog extends StatefulWidget {
  final SaleInvoice invoice;
  final VoidCallback onClose;
  final VoidCallback onPrint;
  final String coustomerName;
  final VoidCallback? onInvoiceUpdated; // ⬅️ إضافة callback جديد

  const InvoiceDetailsDialog({
    super.key,
    required this.invoice,
    required this.onClose,
    required this.onPrint,
    required this.coustomerName,
    this.onInvoiceUpdated, // ⬅️ إضافة باراميتر اختياري
  });

  @override
  State<InvoiceDetailsDialog> createState() => _InvoiceDetailsDialogState();
}

class _InvoiceDetailsDialogState extends State<InvoiceDetailsDialog> {
  // ⬅️ دالة محدثة لفتح dialog التعديل
  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => InvoiceEditDialog(
            invoice: widget.invoice,
            onInvoiceUpdated: () {
              // استدعاء callback التحديث إذا كان موجوداً
              widget.onInvoiceUpdated?.call();

              // إغلاق dialog التفاصيل أيضاً
              Navigator.of(context).pop();
              widget.onClose();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.of(context).size.width * 0.6;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.blue),
            const SizedBox(width: 8),
            const Text("تفاصيل الفاتورة"),
            const Spacer(),
            Text(
              widget.invoice.invoiceNumber,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildInfoItem(
                        "رقم الفاتورة",
                        widget.invoice.invoiceNumber,
                      ),
                      _buildInfoItem("التاريخ", widget.invoice.date),
                      _buildInfoItem("الوقت", widget.invoice.time),
                      _buildInfoItem("البائع", widget.invoice.cashier),
                      _buildInfoItem("العميل", widget.coustomerName),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "تفاصيل المنتجات",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                DataTable(
                  columns: const [
                    DataColumn(label: Text("المنتج")),
                    DataColumn(label: Text("السعر")),
                    DataColumn(label: Text("الكمية")),
                    DataColumn(label: Text("الإجمالي")),
                  ],
                  rows:
                      widget.invoice.items.map((item) {
                        final itemTotal = item.price * item.quantity;
                        final unitName = item.unitName;

                        return DataRow(
                          cells: [
                            DataCell(Text(item.productName)),
                            DataCell(
                              Text("${item.price.toStringAsFixed(2)} شيكل"),
                            ),
                            DataCell(
                              Text(
                                "${item.quantity.toStringAsFixed(2)} $unitName",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                "${itemTotal.toStringAsFixed(2)} شيكل",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "المبلغ الإجمالي:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${widget.invoice.total.toStringAsFixed(2)} شيكل",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                // ⬅️ إضافة معلومات المدفوعات والمتبقي
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("المبلغ المدفوع:"),
                          Text(
                            "${widget.invoice.paidAmount.toStringAsFixed(2)} شيكل",
                            style: TextStyle(
                              color:
                                  widget.invoice.paidAmount > 0
                                      ? Colors.green
                                      : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("المبلغ المتبقي:"),
                          Text(
                            "${widget.invoice.remainingAmount.toStringAsFixed(2)} شيكل",
                            style: TextStyle(
                              color:
                                  widget.invoice.remainingAmount > 0
                                      ? Colors.orange
                                      : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("حالة السداد:"),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                widget.invoice.paymentStatus,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.invoice.paymentStatus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
          ),
        ),
        actions: [
          OutlinedButton(onPressed: widget.onClose, child: const Text("إغلاق")),
          if (!widget.invoice.isReturn &&
              widget.invoice.paymentStatus != 'تم الإرجاع')
            ElevatedButton.icon(
              onPressed: () {
                _showEditDialog(context);
              },
              icon: const Icon(Icons.edit),
              label: const Text("تعديل الفاتورة"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ElevatedButton.icon(
            onPressed: widget.onPrint,
            icon: const Icon(Icons.print_outlined),
            label: const Text("طباعة الفاتورة"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // دالة مساعدة للحصول على لون حالة السداد
  Color _getStatusColor(String status) {
    switch (status) {
      case 'مدفوع':
        return Colors.green;
      case 'جزئي':
        return Colors.orange;
      case 'غير مدفوع':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
