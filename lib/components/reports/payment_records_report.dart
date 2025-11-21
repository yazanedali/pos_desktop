import 'package:flutter/material.dart';
import '../../models/report_models.dart';

class PaymentRecordsReport extends StatelessWidget {
  final List<PaymentRecordData> data;

  const PaymentRecordsReport({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final totalAmount = data.fold(0.0, (sum, item) => sum + item.amount);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  "سجلات السداد",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // الإحصائيات الإجمالية
            Card(
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          "إجمالي السداد",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${totalAmount.toStringAsFixed(2)} شيكل",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          "عدد السجلات",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.length.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            DataTable(
              columns: const [
                DataColumn(label: Text("التاريخ")),
                DataColumn(label: Text("الوقت")),
                DataColumn(label: Text("رقم الفاتورة")),
                DataColumn(label: Text("اسم العميل")),
                DataColumn(label: Text("طريقة الدفع")),
                DataColumn(label: Text("المبلغ")),
              ],
              rows:
                  data.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(item.paymentDate)),
                        DataCell(Text(item.paymentTime)),
                        DataCell(
                          Text(
                            item.invoiceNumber ?? "-",
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.customerName ?? "عميل نقدي",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue),
                            ),
                            child: Text(
                              item.paymentMethod,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            "${item.amount.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
