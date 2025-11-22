import 'package:flutter/material.dart';
import '../../models/sales_invoice.dart';

class InvoiceDetailsDialog extends StatelessWidget {
  final SaleInvoice invoice;
  final VoidCallback onClose;
  final VoidCallback onPrint;
  final String coustomerName;

  const InvoiceDetailsDialog({
    super.key,
    required this.invoice,
    required this.onClose,
    required this.onPrint,
    required this.coustomerName,
  });

  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.of(context).size.width * 0.6;

    return Directionality(
      textDirection: TextDirection.rtl, // <<< الاتجاه من اليمين لليسار
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.blue),
            const SizedBox(width: 8),
            const Text("تفاصيل الفاتورة"),
            const Spacer(),
            Text(
              invoice.invoiceNumber,
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
                      _buildInfoItem("رقم الفاتورة", invoice.invoiceNumber),
                      _buildInfoItem("التاريخ", invoice.date),
                      _buildInfoItem("الوقت", invoice.time),
                      _buildInfoItem("البائع", invoice.cashier),
                      _buildInfoItem("العميل", coustomerName),
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
                      invoice.items.map((item) {
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
                        "${invoice.total.toStringAsFixed(2)} شيكل",
                        style: const TextStyle(
                          fontSize: 20,
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
          OutlinedButton(onPressed: onClose, child: const Text("إغلاق")),
          ElevatedButton.icon(
            onPressed: onPrint,
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
}
