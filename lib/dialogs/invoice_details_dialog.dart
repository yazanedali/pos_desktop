import 'package:flutter/material.dart';
import '../models/statement_item.dart';
import '../models/sales_invoice.dart';
import '../services/printing_service.dart';

class InvoiceDetailsDialog extends StatelessWidget {
  final StatementItem item;
  final PrintingService _printingService = PrintingService();

  InvoiceDetailsDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "تفاصيل الفاتورة #${item.invoiceNumber}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),

            // Products Table
            Expanded(
              child: SingleChildScrollView(
                child: Table(
                  border: TableBorder.all(color: Colors.grey[300]!),
                  columnWidths: const {
                    0: FlexColumnWidth(4), // Product Name
                    1: FlexColumnWidth(1), // Qty
                    2: FlexColumnWidth(1.5), // Price
                    3: FlexColumnWidth(1.5), // Total
                  },
                  children: [
                    // Header Row
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey[100]),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            "الصنف",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            "العدد",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            "السعر",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            "المجموع",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    // Data Rows
                    if (item.items != null)
                      ...item.items!.map((prod) {
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(prod.productName),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                prod.quantity.toStringAsFixed(1),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                prod.price.toStringAsFixed(1),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                prod.total.toStringAsFixed(1),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Footer / Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    // Create minimal SaleInvoice for printing
                    final minimalInvoice = SaleInvoice(
                      id: 0,
                      invoiceNumber: item.invoiceNumber ?? "",
                      date: item.date.split(' ')[0],
                      time:
                          item.date.split(' ').length > 1
                              ? item.date.split(' ')[1]
                              : "",
                      customerId: 0,
                      customerName: "",
                      total: item.amount,
                      paidAmount: 0,
                      remainingAmount: item.amount,
                      paymentStatus: "N/A",
                      paymentMethod: "N/A",
                      paymentType: "N/A",
                      originalTotal: item.amount,
                      cashier: "N/A",
                      items: item.items ?? [],
                    );

                    await _printingService.printInvoice(minimalInvoice);
                  },
                  icon: const Icon(Icons.print),
                  label: const Text("طباعة الفاتورة"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إغلاق"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
