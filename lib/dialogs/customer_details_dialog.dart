// dialogs/customer_details_dialog.dart
import 'package:flutter/material.dart';
import 'package:pos_desktop/database/sales_invoice_queries.dart';
import 'package:pos_desktop/dialogs/customer_statement_dialog.dart';
import 'package:pos_desktop/models/customer.dart'; // أضف هذا الاستيراد إذا كان لديك نموذج Customer

class CustomerDetailsDialog extends StatefulWidget {
  final int customerId;
  final String customerName;
  final double totalDebt;

  const CustomerDetailsDialog({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.totalDebt,
  });

  @override
  State<CustomerDetailsDialog> createState() => _CustomerDetailsDialogState();
}

class _CustomerDetailsDialogState extends State<CustomerDetailsDialog> {
  final SalesInvoiceQueries _invoiceQueries = SalesInvoiceQueries();
  late Future<List<Map<String, dynamic>>> _invoicesFuture;

  @override
  void initState() {
    super.initState();
    _invoicesFuture = _invoiceQueries.getInvoicesForCustomer(widget.customerId);
  }

  void _showCustomerStatement(BuildContext context) {
    final customer = Customer(
      id: widget.customerId,
      name: widget.customerName,
      phone: '',
      address: '',
    );

    showDialog(
      context: context,
      builder: (context) => CustomerStatementDialog(customer: customer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // أضف Directionality للتحكم في الاتجاه
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.person, color: Colors.blue),
            const SizedBox(width: 8),
            Text("تفاصيل: ${widget.customerName}"),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          height: MediaQuery.of(context).size.height * 0.6, // أضفت ارتفاع ثابت
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "إجمالي الدين: ${widget.totalDebt.toStringAsFixed(2)} شيكل",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: widget.totalDebt > 0 ? Colors.red : Colors.green,
                ),
              ),
              const Divider(height: 24),
              const Text(
                "سجل الفواتير:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _invoicesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text("لا يوجد فواتير لهذا العميل."),
                      );
                    }
                    final invoices = snapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: invoices.length,
                      itemBuilder: (context, index) {
                        final invoice = invoices[index];
                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              "فاتورة رقم: ${invoice['invoice_number']}",
                            ),
                            subtitle: Text("التاريخ: ${invoice['date']}"),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "الإجمالي: ${(invoice['total'] as num).toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "المتبقي: ${(invoice['remaining_amount'] as num).toStringAsFixed(2)}",
                                  style: TextStyle(
                                    color:
                                        (invoice['remaining_amount'] as num) > 0
                                            ? Colors.orange.shade800
                                            : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إغلاق"),
          ),
          ElevatedButton.icon(
            onPressed: () => _showCustomerStatement(context),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('كشف حساب'),
          ),
        ],
      ),
    );
  }
}
